import { ForbiddenException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { RedisService } from '../../../common/redis/redis.service';
import { generateOtp, hashString } from '../../../common/utils/helpers.util';

/**
 * Redis key patterns:
 *   otp:{email}           → hashed OTP value     (TTL: 300s)
 *   otp_attempts:{email}  → attempt counter       (TTL: 300s)
 *   otp_cooldown:{email}  → resend cooldown flag  (TTL: 60s)
 */
const OTP_PREFIX = 'otp:';
const OTP_ATTEMPTS_PREFIX = 'otp_attempts:';
const OTP_COOLDOWN_PREFIX = 'otp_cooldown:';
const OTP_LOCKOUT_PREFIX = 'otp_lockout:';

@Injectable()
export class OtpService {
  private readonly otpExpiration: number;
  private readonly otpLength: number;
  private readonly maxAttempts: number;
  private readonly cooldownSeconds: number;

  constructor(
    private readonly configService: ConfigService,
    private readonly redisService: RedisService,
  ) {
    this.otpExpiration = this.configService.get<number>('otp.expirationSeconds', 300);
    this.otpLength = this.configService.get<number>('otp.length', 6);
    this.maxAttempts = 5;
    this.cooldownSeconds = 60;
  }

  private isSimulationMode(): boolean {
    const environment = this.configService.get<string>('nodeEnv');
    return (
      (environment === 'development' || environment === 'test') &&
      !this.configService.get<string>('RESEND_API_KEY')
    );
  }

  /**
   * Generate and store a new OTP for the given email number.
   *
   * Security measures:
   * 1. OTP is hashed before storing in Redis (SHA-256)
   * 2. Resend cooldown prevents spam (60s)
   * 3. Attempt counter is reset on new OTP
   *
   * @returns The plaintext OTP (for email delivery)
   * @throws if cooldown period has not elapsed
   */
  async generateAndStore(email: string): Promise<{
    otp: string;
    expiresInSeconds: number;
    isResend: boolean;
  }> {
    const otp = generateOtp(this.otpLength);
    const result = await this.redisService.getClient().eval(
      `local lockout = redis.call('TTL', KEYS[1])
       if lockout > 0 then return -lockout end

       local cooldown = redis.call('TTL', KEYS[2])
       if cooldown > 0 and redis.call('EXISTS', KEYS[3]) == 1 then return cooldown end

       redis.call('SET', KEYS[3], ARGV[1], 'EX', ARGV[2])
       redis.call('DEL', KEYS[4])
       redis.call('SET', KEYS[2], '1', 'EX', ARGV[3])
       if ARGV[4] ~= '' then
         redis.call('SET', KEYS[5], ARGV[4], 'EX', ARGV[2])
       else
         redis.call('DEL', KEYS[5])
       end
       return 0`,
      5,
      `${OTP_LOCKOUT_PREFIX}${email}`,
      `${OTP_COOLDOWN_PREFIX}${email}`,
      `${OTP_PREFIX}${email}`,
      `${OTP_ATTEMPTS_PREFIX}${email}`,
      `dev_otp:${email}`,
      hashString(otp),
      this.otpExpiration,
      this.cooldownSeconds,
      this.isSimulationMode() ? otp : '',
    );

    if (typeof result !== 'number') throw new Error('Invalid OTP reservation result');
    if (result < 0) {
      throw new ForbiddenException(
        `Too many attempts. Please try again after ${Math.ceil(-result / 60)} minutes.`,
      );
    }
    if (result > 0) {
      return { otp: '', expiresInSeconds: result, isResend: false };
    }

    return {
      otp,
      expiresInSeconds: this.otpExpiration,
      isResend: false,
    };
  }

  /**
   * Get the dev OTP during local development or testing without a configured email provider
   */
  async getDevOtp(email: string): Promise<string | null> {
    if (!this.isSimulationMode()) {
      return null;
    }
    return this.redisService.get(`dev_otp:${email}`);
  }

  /**
   * Verify an OTP for the given email number.
   *
   * Security measures:
   * 1. Compare hashed values only
   * 2. Track and limit verification attempts (max 5)
   * 3. Delete OTP and counters on success
   *
   * @returns { valid: true } on success
   * @returns { valid: false, reason: string } on failure
   */
  async verify(
    email: string,
    otp: string,
  ): Promise<{
    valid: boolean;
    reason?: 'EXPIRED' | 'INVALID' | 'MAX_ATTEMPTS';
    remainingAttempts?: number;
  }> {
    const otpKey = `${OTP_PREFIX}${email}`;
    const attemptsKey = `${OTP_ATTEMPTS_PREFIX}${email}`;

    // Atomic increment and set expiry in a pipeline
    const client = this.redisService.getClient();
    const pipeline = client.pipeline();
    pipeline.incr(attemptsKey);
    pipeline.expire(attemptsKey, this.otpExpiration);
    const results = await pipeline.exec();

    const attempts = (results?.[0]?.[1] as number) || 1;

    if (attempts > this.maxAttempts) {
      // Set lockout (e.g. 30 minutes)
      const lockoutKey = `${OTP_LOCKOUT_PREFIX}${email}`;
      await this.redisService.set(lockoutKey, '1', 30 * 60);

      // Wipe the OTP to force re-request
      await this.cleanup(email);
      return { valid: false, reason: 'MAX_ATTEMPTS', remainingAttempts: 0 };
    }

    // Get stored hashed OTP
    const storedHashedOtp = await this.redisService.get(otpKey);

    if (!storedHashedOtp) {
      return {
        valid: false,
        reason: 'EXPIRED',
        remainingAttempts: Math.max(0, this.maxAttempts - attempts),
      };
    }

    // Compare hashes
    const inputHash = hashString(otp);

    if (inputHash !== storedHashedOtp) {
      return {
        valid: false,
        reason: 'INVALID',
        remainingAttempts: Math.max(0, this.maxAttempts - attempts),
      };
    }

    // Consume the matching code atomically so concurrent verification cannot reuse it.
    const consumed = await client.eval(
      `if redis.call('GET', KEYS[1]) == ARGV[1] then
         return redis.call('DEL', KEYS[1], KEYS[2], KEYS[3], KEYS[4])
       end
       return 0`,
      4,
      otpKey,
      attemptsKey,
      `${OTP_COOLDOWN_PREFIX}${email}`,
      `dev_otp:${email}`,
      inputHash,
    );
    return consumed ? { valid: true } : { valid: false, reason: 'EXPIRED' };
  }

  /**
   * Remove all OTP-related keys for a email number.
   */
  async cleanup(email: string): Promise<void> {
    await Promise.all([
      this.redisService.del(`${OTP_PREFIX}${email}`),
      this.redisService.del(`${OTP_ATTEMPTS_PREFIX}${email}`),
      this.redisService.del(`${OTP_COOLDOWN_PREFIX}${email}`),
      this.redisService.del(`dev_otp:${email}`),
    ]);
  }

  /**
   * Check remaining resend cooldown time.
   * Returns 0 if no cooldown.
   */
  async getCooldownRemaining(email: string): Promise<number> {
    const ttl = await this.redisService.getClient().ttl(`${OTP_COOLDOWN_PREFIX}${email}`);
    return ttl > 0 ? ttl : 0;
  }
}
