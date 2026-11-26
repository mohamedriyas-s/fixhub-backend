import { ErrorCodes } from '@fixhub/shared';
import { ConfigService } from '@nestjs/config';
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

import { AdminLoginDto, SendOtpDto, VerifyOtpDto } from '../dto';
import { AuthRepository } from '../repositories/auth.repository';
import { OtpService } from './otp.service';
import { TokenService } from './token.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly otpService: OtpService,
    private readonly tokenService: TokenService,
    private readonly authRepository: AuthRepository,
    private readonly config: ConfigService,
  ) {}

  // ── Send OTP ──────────────────────────────────────────────

  async sendOtp(dto: SendOtpDto) {
    const { otp, expiresInSeconds } = await this.otpService.generateAndStore(dto.email);

    if (!otp) {
      // Still on cooldown — tell user to wait
      const remaining = await this.otpService.getCooldownRemaining(dto.email);
      const devOtp = await this.otpService.getDevOtp(dto.email);
      return {
        message: `OTP already sent. Please wait ${remaining}s before requesting again.`,
        cooldownSeconds: remaining,
        expiresInSeconds,
        devOtp: devOtp ?? undefined,
      };
    }

    const apiKey = this.config.get<string>('RESEND_API_KEY');
    const from = this.config.get<string>('OTP_EMAIL_FROM');
    if (apiKey && from) {
      try {
        const response = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            from,
            to: [dto.email],
            subject: 'Your HelpTap sign-in code',
            text: `Your HelpTap sign-in code is ${otp}. It expires in ${Math.ceil(expiresInSeconds / 60)} minutes.`,
          }),
          signal: AbortSignal.timeout(5000),
        });
        if (!response.ok) throw new Error('Email provider rejected the request');
      } catch {
        await this.otpService.cleanup(dto.email);
        throw new ServiceUnavailableException(
          'Unable to send the sign-in email. Please try again.',
        );
      }
    } else if (!(await this.otpService.getDevOtp(dto.email))) {
      await this.otpService.cleanup(dto.email);
      throw new ServiceUnavailableException('Sign-in email is unavailable');
    }

    const devOtp = await this.otpService.getDevOtp(dto.email);

    return {
      message: 'OTP sent successfully',
      expiresInSeconds,
      cooldownSeconds: 60,
      devOtp: devOtp ?? undefined,
    };
  }

  // ── Verify OTP ────────────────────────────────────────────

  async verifyOtp(dto: VerifyOtpDto) {
    // Admin cannot use OTP login
    if (dto.role === Role.ADMIN) {
      throw new ForbiddenException({
        message: 'Admin users must use email/password login',
        errorCode: ErrorCodes.AUTH_FORBIDDEN,
      });
    }

    // Verify OTP
    const result = await this.otpService.verify(dto.email, dto.otp);

    if (!result.valid) {
      switch (result.reason) {
        case 'EXPIRED':
          throw new UnauthorizedException({
            message: 'OTP has expired. Please request a new one.',
            errorCode: ErrorCodes.AUTH_OTP_EXPIRED,
          });
        case 'MAX_ATTEMPTS':
          throw new BadRequestException({
            message: 'Too many failed attempts. Please request a new OTP.',
            errorCode: ErrorCodes.AUTH_OTP_MAX_ATTEMPTS,
          });
        case 'INVALID':
        default:
          throw new UnauthorizedException({
            message: `Invalid OTP. ${result.remainingAttempts} attempts remaining.`,
            errorCode: ErrorCodes.AUTH_OTP_INVALID,
          });
      }
    }

    // Find or create user + profile
    const { user, isNewUser } = await this.authRepository.findOrCreateUser(dto.email, dto.role);

    // Check if user is active
    if (!user.isActive || user.deletedAt) {
      throw new ForbiddenException({
        message: 'Your account has been deactivated. Contact support.',
        errorCode: ErrorCodes.AUTH_ACCOUNT_DEACTIVATED,
      });
    }

    // Generate token pair
    const tokens = await this.tokenService.generateTokenPair(user);

    // Fetch full user with profile details
    const fullUser = await this.authRepository.findUserById(user.id);
    const profile = fullUser?.customer
      ? {
          id: fullUser.customer.id,
          profilePictureUrl: fullUser.customer.profilePictureUrl,
        }
      : fullUser?.technician
        ? {
            id: fullUser.technician.id,
            profilePictureUrl: fullUser.technician.profilePictureUrl,
            isAvailable: fullUser.technician.isAvailable,
            verificationStatus: fullUser.technician.verificationStatus,
            rating: fullUser.technician.rating,
            totalJobs: fullUser.technician.totalJobs,
          }
        : undefined;

    this.logger.log(
      `User ${user.id} (${user.role}) authenticated via OTP${isNewUser ? ' [NEW]' : ''}`,
    );

    return {
      ...tokens,
      isNewUser,
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        email: user.email,
        role: user.role,
        isActive: user.isActive,
        createdAt: user.createdAt,
        profile,
        // Backward-compatible customer / technician key
        ...(fullUser?.customer && { customer: profile }),
        ...(fullUser?.technician && { technician: profile }),
      },
    };
  }

  // ── Admin Login ───────────────────────────────────────────

  async adminLogin(dto: AdminLoginDto) {
    const user = await this.authRepository.findUserByEmail(dto.email);

    if (!user || user.role !== Role.ADMIN) {
      throw new UnauthorizedException({
        message: 'Invalid credentials',
        errorCode: ErrorCodes.AUTH_UNAUTHORIZED,
      });
    }

    if (!user.password || !(await bcrypt.compare(dto.password, user.password))) {
      throw new UnauthorizedException({
        message: 'Invalid credentials',
        errorCode: ErrorCodes.AUTH_UNAUTHORIZED,
      });
    }

    if (!user.isActive) {
      throw new ForbiddenException({
        message: 'Admin account has been deactivated.',
        errorCode: ErrorCodes.AUTH_ACCOUNT_DEACTIVATED,
      });
    }

    const tokens = await this.tokenService.generateTokenPair(user);

    this.logger.log(`Admin ${user.id} logged in successfully`);

    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
    };
  }

  // ── Refresh Token ─────────────────────────────────────────

  async refreshTokens(refreshToken: string) {
    return this.tokenService.refreshTokens(refreshToken);
  }

  // ── Logout ────────────────────────────────────────────────

  async logout(userId: string, accessToken?: string) {
    // Revoke all refresh tokens
    await this.tokenService.revokeAllTokens(userId);

    // Blacklist current access token
    if (accessToken) {
      await this.tokenService.blacklistAccessToken(accessToken);
    }

    // Deactivate device tokens
    await this.authRepository.deactivateUserDeviceTokens(userId);

    this.logger.log(`User ${userId} logged out`);
    return { message: 'Logged out successfully' };
  }

  // ── Get Current User ──────────────────────────────────────

  async getMe(userId: string) {
    const user = await this.authRepository.findUserById(userId);

    if (!user) {
      throw new UnauthorizedException({
        message: 'User not found',
        errorCode: ErrorCodes.USER_NOT_FOUND,
      });
    }

    if (!user.isActive) {
      throw new ForbiddenException({
        message: 'Account is deactivated',
        errorCode: ErrorCodes.AUTH_ACCOUNT_DEACTIVATED,
      });
    }

    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      email: user.email,
      role: user.role,
      isActive: user.isActive,
      createdAt: user.createdAt,
      // Role-specific profile
      ...(user.customer && {
        profile: {
          id: user.customer.id,
          profilePictureUrl: user.customer.profilePictureUrl,
        },
      }),
      ...(user.technician && {
        profile: {
          id: user.technician.id,
          profilePictureUrl: user.technician.profilePictureUrl,
          isAvailable: user.technician.isAvailable,
          verificationStatus: user.technician.verificationStatus,
          rating: user.technician.rating,
          totalJobs: user.technician.totalJobs,
        },
      }),
    };
  }

  // ── Device Registration ───────────────────────────────────

  async registerDevice(
    userId: string,
    deviceToken: string,
    platform: import('@prisma/client').DevicePlatform,
  ) {
    await this.authRepository.upsertDeviceToken(userId, deviceToken, platform);
    return { message: 'Device registered successfully' };
  }
}
