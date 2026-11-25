import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { Request } from 'express';
import { ExtractJwt, Strategy } from 'passport-jwt';

import type { AppConfigValues } from '../../../common/config/app.config';
import { AuthenticatedUser, JwtPayload } from '../../../common/interfaces/auth.interface';
import { AuthRepository } from '../repositories/auth.repository';
import { TokenService } from '../services/token.service';

const cookieExtractor = (req: Request) => {
  let token = null;
  if (req && req.cookies) {
    token = req.cookies['accessToken'];
  }
  return token;
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    configService: ConfigService<AppConfigValues>,
    private readonly tokenService: TokenService,
    private readonly authRepository: AuthRepository,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        cookieExtractor,
        ExtractJwt.fromAuthHeaderAsBearerToken(),
      ]),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow('jwt.accessSecret', { infer: true }),
      passReqToCallback: true,
    });
  }

  /**
   * Validate the JWT payload AND check if the token is blacklisted.
   * Also verifies user still exists and is active in database (handles DB resets).
   * Called on every authenticated request.
   */
  async validate(req: Request, payload: JwtPayload): Promise<AuthenticatedUser> {
    if (!payload.sub) {
      throw new UnauthorizedException('Invalid token payload');
    }

    // Verify user exists and is active in database (handles post-db-reset stale tokens)
    const user = await this.authRepository.findUserById(payload.sub);
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User account no longer exists or is inactive');
    }

    // Check if access token has been blacklisted (post-logout)
    let token = cookieExtractor(req);
    if (!token) {
      token = ExtractJwt.fromAuthHeaderAsBearerToken()(req);
    }

    if (token) {
      const isBlacklisted = await this.tokenService.isAccessTokenBlacklisted(token);
      if (isBlacklisted) {
        throw new UnauthorizedException('Token has been revoked');
      }
    }

    return {
      userId: user.id,
      phone: user.phone,
      role: user.role,
    };
  }
}
