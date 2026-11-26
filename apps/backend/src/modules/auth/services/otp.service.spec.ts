import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import * as crypto from 'crypto';

import { RedisService } from '../../../common/redis/redis.service';
import { OtpService } from './otp.service';

describe('OtpService', () => {
  let otpService: OtpService;
  let redisService: jest.Mocked<RedisService>;
  let config: Record<string, unknown>;

  const mockPipeline = {
    set: jest.fn().mockReturnThis(),
    del: jest.fn().mockReturnThis(),
    incr: jest.fn().mockReturnThis(),
    expire: jest.fn().mockReturnThis(),
    exec: jest.fn().mockResolvedValue([
      [null, 1],
      [null, 1],
    ]),
  };

  const mockRedisClient = {
    eval: jest.fn().mockResolvedValue(1),
    ttl: jest.fn(),
    pipeline: jest.fn(() => mockPipeline),
  };

  beforeEach(async () => {
    mockPipeline.set.mockClear();
    mockRedisClient.ttl.mockResolvedValue(-2);
    config = {
      'otp.expirationSeconds': 300,
      'otp.length': 6,
      nodeEnv: 'test',
    };
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OtpService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string, defaultValue?: unknown) => config[key] ?? defaultValue),
          },
        },
        {
          provide: RedisService,
          useValue: {
            get: jest.fn(),
            set: jest.fn(),
            del: jest.fn(),
            exists: jest.fn(),
            incr: jest.fn(),
            expire: jest.fn(),
            getClient: jest.fn(() => mockRedisClient),
          },
        },
      ],
    }).compile();

    otpService = module.get<OtpService>(OtpService);
    redisService = module.get(RedisService);
  });

  it('should be defined', () => {
    expect(otpService).toBeDefined();
  });

  describe('dev OTP exposure', () => {
    it.each(['configured-key', undefined])(
      'keeps production OTPs private with Resend key %s',
      async (apiKey) => {
        config.nodeEnv = 'production';
        config.RESEND_API_KEY = apiKey;
        const phone = 'customer@example.com';

        await otpService.generateAndStore(phone);
        await expect(otpService.getDevOtp(phone)).resolves.toBeNull();

        expect(mockPipeline.set.mock.calls.map(([key]) => key)).not.toContain(`dev_otp:${phone}`);
        expect(redisService.get).not.toHaveBeenCalled();
      },
    );

    it('preserves dev OTP access in test mode without an email provider', async () => {
      const phone = 'customer@example.com';
      const { otp } = await otpService.generateAndStore(phone);
      expect(mockPipeline.set).toHaveBeenCalledWith(`dev_otp:${phone}`, otp, 'EX', 300);

      redisService.get.mockResolvedValue(otp);
      await expect(otpService.getDevOtp(phone)).resolves.toBe(otp);
    });
  });

  // ── generateAndStore ──────────────────────────────────

  describe('generateAndStore', () => {
    it('should generate and store OTP when no cooldown', async () => {
      redisService.exists.mockResolvedValue(false);
      redisService.set.mockResolvedValue(undefined);
      redisService.del.mockResolvedValue(undefined);

      const result = await otpService.generateAndStore('customer@example.com');

      expect(result.otp).toHaveLength(6);
      expect(result.otp).toMatch(/^\d{6}$/);
      expect(result.expiresInSeconds).toBe(300);
      expect(mockPipeline.set).toHaveBeenCalledWith(
        'otp:customer@example.com',
        expect.any(String),
        'EX',
        300,
      );
      expect(mockPipeline.del).toHaveBeenCalledWith('otp_attempts:customer@example.com');
      expect(mockPipeline.set).toHaveBeenCalledWith(
        'otp_cooldown:customer@example.com',
        '1',
        'EX',
        60,
      );
    });

    it('should return empty OTP when on cooldown', async () => {
      redisService.exists.mockResolvedValue(true);
      mockRedisClient.ttl.mockImplementation(async (key: string) => {
        if (key.includes('lockout')) return -2;
        return 45;
      });

      const result = await otpService.generateAndStore('customer@example.com');

      expect(result.otp).toBe('');
      expect(result.expiresInSeconds).toBe(45);
    });
  });

  // ── verify ────────────────────────────────────────────

  describe('verify', () => {
    it('should return valid for correct OTP', async () => {
      redisService.incr.mockResolvedValue(1);
      redisService.expire.mockResolvedValue(undefined);
      // generateAndStore stores hash of the OTP
      const hash = crypto.createHash('sha256').update('123456').digest('hex');
      redisService.get.mockResolvedValue(hash);
      redisService.del.mockResolvedValue(undefined);

      const result = await otpService.verify('customer@example.com', '123456');

      expect(result.valid).toBe(true);
      expect(mockRedisClient.eval).toHaveBeenCalledWith(
        expect.any(String),
        4,
        'otp:customer@example.com',
        'otp_attempts:customer@example.com',
        'otp_cooldown:customer@example.com',
        'dev_otp:customer@example.com',
        hash,
      );
    });

    it('should return INVALID for wrong OTP', async () => {
      redisService.incr.mockResolvedValue(1);
      redisService.expire.mockResolvedValue(undefined);
      const hash = crypto.createHash('sha256').update('123456').digest('hex');
      redisService.get.mockResolvedValue(hash);

      const result = await otpService.verify('customer@example.com', '999999');

      expect(result.valid).toBe(false);
      expect(result.reason).toBe('INVALID');
      expect(result.remainingAttempts).toBe(4);
    });

    it('should return EXPIRED when no OTP in Redis', async () => {
      redisService.incr.mockResolvedValue(1);
      redisService.expire.mockResolvedValue(undefined);
      redisService.get.mockResolvedValue(null);

      const result = await otpService.verify('customer@example.com', '123456');

      expect(result.valid).toBe(false);
      expect(result.reason).toBe('EXPIRED');
    });

    it('should return MAX_ATTEMPTS when attempts exceeded', async () => {
      mockPipeline.exec.mockResolvedValueOnce([
        [null, 6],
        [null, 1],
      ]);
      redisService.set.mockResolvedValue(undefined);
      redisService.del.mockResolvedValue(undefined);

      const result = await otpService.verify('customer@example.com', '123456');

      expect(result.valid).toBe(false);
      expect(result.reason).toBe('MAX_ATTEMPTS');
      expect(result.remainingAttempts).toBe(0);
    });

    it('should track attempts correctly across multiple calls', async () => {
      const hash = crypto.createHash('sha256').update('123456').digest('hex');

      // First attempt — wrong OTP
      mockPipeline.exec.mockResolvedValueOnce([
        [null, 1],
        [null, 1],
      ]);
      redisService.get.mockResolvedValue(hash);

      const r1 = await otpService.verify('customer@example.com', '111111');
      expect(r1.valid).toBe(false);
      expect(r1.remainingAttempts).toBe(4);

      // Third attempt — correct OTP
      mockPipeline.exec.mockResolvedValueOnce([
        [null, 3],
        [null, 1],
      ]);
      redisService.del.mockResolvedValue(undefined);

      const r2 = await otpService.verify('customer@example.com', '123456');
      expect(r2.valid).toBe(true);
    });
  });

  // ── cleanup ───────────────────────────────────────────

  describe('cleanup', () => {
    it('should delete all OTP-related keys', async () => {
      redisService.del.mockResolvedValue(undefined);

      await otpService.cleanup('customer@example.com');

      expect(redisService.del).toHaveBeenCalledTimes(4);
      expect(redisService.del).toHaveBeenCalledWith('otp:customer@example.com');
      expect(redisService.del).toHaveBeenCalledWith('otp_attempts:customer@example.com');
      expect(redisService.del).toHaveBeenCalledWith('otp_cooldown:customer@example.com');
      expect(redisService.del).toHaveBeenCalledWith('dev_otp:customer@example.com');
    });
  });
});
