import { plainToInstance, Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min, validateSync } from 'class-validator';

export class AppConfig {
  @IsString()
  NODE_ENV: string;

  @IsInt()
  @Min(1)
  @Max(65535)
  @Type(() => Number)
  APP_PORT: number;

  @IsString()
  DATABASE_URL: string;

  @IsString()
  REDIS_HOST: string;

  @IsInt()
  @Type(() => Number)
  REDIS_PORT: number;

  @IsOptional()
  @IsString()
  REDIS_PASSWORD?: string;

  @IsString()
  JWT_ACCESS_SECRET: string;

  @IsString()
  JWT_ACCESS_EXPIRATION: string;

  @IsString()
  JWT_REFRESH_SECRET: string;

  @IsString()
  JWT_REFRESH_EXPIRATION: string;

  @IsString()
  AWS_REGION: string;

  @IsOptional()
  @IsString()
  AWS_ACCESS_KEY_ID?: string;

  @IsOptional()
  @IsString()
  AWS_SECRET_ACCESS_KEY?: string;

  @IsString()
  AWS_S3_BUCKET: string;

  @IsOptional()
  @IsString()
  RAZORPAY_KEY_ID?: string;

  @IsOptional()
  @IsString()
  RAZORPAY_KEY_SECRET?: string;

  @IsOptional()
  @IsString()
  RAZORPAY_WEBHOOK_SECRET?: string;

  @IsOptional()
  @IsString()
  FIREBASE_PROJECT_ID?: string;

  @IsOptional()
  @IsString()
  FIREBASE_PRIVATE_KEY?: string;

  @IsOptional()
  @IsString()
  FIREBASE_CLIENT_EMAIL?: string;

  @IsOptional()
  @IsString()
  SMS_PROVIDER?: string;

  @IsOptional()
  @IsString()
  SMS_API_KEY?: string;

  @IsOptional()
  @IsString()
  SMS_SENDER_ID?: string;

  @IsOptional()
  @IsString()
  CORS_ORIGINS?: string;

  @IsInt()
  @Type(() => Number)
  THROTTLE_TTL: number;

  @IsInt()
  @Type(() => Number)
  THROTTLE_LIMIT: number;
}

function cleanEnvString(val?: string): string | undefined {
  if (!val) return undefined;
  let str = val.trim();
  if ((str.startsWith('"') && str.endsWith('"')) || (str.startsWith("'") && str.endsWith("'"))) {
    str = str.slice(1, -1);
  }
  return str;
}

function cleanPrivateKey(val?: string): string | undefined {
  const str = cleanEnvString(val);
  if (!str) return undefined;
  return str.replace(/\\n/g, '\n');
}

function parseRedisConfig(
  rawHost?: string,
  rawPort?: string | number,
  rawPassword?: string,
  rawUrl?: string,
) {
  let host = (rawHost as string) || 'localhost';
  let port = typeof rawPort === 'number' ? rawPort : parseInt((rawPort as string) || '6379', 10);
  let password = (rawPassword as string) || undefined;

  const candidateUrl = rawUrl || process.env.REDIS_URL || (host.includes('://') ? host : undefined);
  if (candidateUrl) {
    try {
      const u = new URL(candidateUrl);
      if (u.hostname) host = u.hostname;
      if (u.port) port = parseInt(u.port, 10);
      if (u.password) password = decodeURIComponent(u.password);
    } catch {
      // Invalid URL format — fallback to host/port as provided
    }
  }

  // Guard against any leftover protocol or :port in host
  if (host.includes('://')) {
    host = host.split('://')[1];
  }
  if (host.includes(':')) {
    const parts = host.split(':');
    host = parts[0];
    if (!isNaN(parseInt(parts[1], 10))) {
      port = parseInt(parts[1], 10);
    }
  }
  if (host.includes('/')) {
    host = host.split('/')[0];
  }

  return { host, port, password };
}

export const appConfig = () => {
  const redis = parseRedisConfig(
    process.env.REDIS_HOST,
    process.env.REDIS_PORT,
    process.env.REDIS_PASSWORD,
    process.env.REDIS_URL,
  );

  return {
    port: parseInt(process.env.PORT || process.env.APP_PORT || '3000', 10),
    nodeEnv: process.env.NODE_ENV || 'development',
    apiPrefix: process.env.API_PREFIX || 'api',
    apiVersion: process.env.API_VERSION || 'v1',

    database: {
      url: process.env.DATABASE_URL,
    },

    redis,

    jwt: {
      accessSecret: process.env.JWT_ACCESS_SECRET,
      accessExpiration: process.env.JWT_ACCESS_EXPIRATION || '15m',
      refreshSecret: process.env.JWT_REFRESH_SECRET,
      refreshExpiration: process.env.JWT_REFRESH_EXPIRATION || '7d',
    },

    otp: {
      expirationSeconds: parseInt(process.env.OTP_EXPIRATION_SECONDS || '300', 10),
      length: parseInt(process.env.OTP_LENGTH || '6', 10),
    },

    aws: {
      region: process.env.AWS_REGION || 'ap-south-1',
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      s3Bucket: process.env.AWS_S3_BUCKET || 'fixhub-uploads',
      signedUrlExpiry: parseInt(process.env.AWS_S3_SIGNED_URL_EXPIRY || '3600', 10),
    },

    razorpay: {
      keyId: process.env.RAZORPAY_KEY_ID,
      keySecret: process.env.RAZORPAY_KEY_SECRET,
      webhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET,
    },

    firebase: {
      projectId: cleanEnvString(process.env.FIREBASE_PROJECT_ID),
      privateKey: cleanPrivateKey(process.env.FIREBASE_PRIVATE_KEY),
      clientEmail: cleanEnvString(process.env.FIREBASE_CLIENT_EMAIL),
    },

    sms: {
      provider: cleanEnvString(process.env.SMS_PROVIDER) || 'DEV',
      apiKey: cleanEnvString(process.env.SMS_API_KEY),
      senderId: cleanEnvString(process.env.SMS_SENDER_ID) || 'FIXHUB',
    },

    cors: {
      origins: (
        process.env.CORS_ORIGINS || 'http://localhost:3001,https://fixhub-admin-neon.vercel.app'
      )
        .split(',')
        .map((origin) => origin.trim())
        .filter(Boolean),
    },

    throttle: {
      ttl: parseInt(process.env.THROTTLE_TTL || '60', 10),
      limit: parseInt(process.env.THROTTLE_LIMIT || '100', 10),
    },
  };
};

export type AppConfigValues = ReturnType<typeof appConfig>;

export function validateConfig(config: Record<string, unknown>): AppConfig {
  const redis = parseRedisConfig(
    config.REDIS_HOST as string,
    config.REDIS_PORT as string | number,
    config.REDIS_PASSWORD as string,
    (config.REDIS_URL as string) || (process.env.REDIS_URL as string),
  );

  const validatedConfig = plainToInstance(AppConfig, {
    NODE_ENV: config.NODE_ENV || 'development',
    APP_PORT: config.PORT ? parseInt(config.PORT as string, 10) : config.APP_PORT || 3000,
    DATABASE_URL: config.DATABASE_URL,
    REDIS_HOST: redis.host,
    REDIS_PORT: redis.port,
    REDIS_PASSWORD: redis.password,
    JWT_ACCESS_SECRET: config.JWT_ACCESS_SECRET,
    JWT_ACCESS_EXPIRATION: config.JWT_ACCESS_EXPIRATION || '15m',
    JWT_REFRESH_SECRET: config.JWT_REFRESH_SECRET,
    JWT_REFRESH_EXPIRATION: config.JWT_REFRESH_EXPIRATION || '7d',
    AWS_REGION: config.AWS_REGION || 'ap-south-1',
    AWS_ACCESS_KEY_ID: config.AWS_ACCESS_KEY_ID,
    AWS_SECRET_ACCESS_KEY: config.AWS_SECRET_ACCESS_KEY,
    AWS_S3_BUCKET: config.AWS_S3_BUCKET || 'fixhub-uploads',
    RAZORPAY_KEY_ID: config.RAZORPAY_KEY_ID,
    RAZORPAY_KEY_SECRET: config.RAZORPAY_KEY_SECRET,
    RAZORPAY_WEBHOOK_SECRET: config.RAZORPAY_WEBHOOK_SECRET,
    FIREBASE_PROJECT_ID: cleanEnvString(config.FIREBASE_PROJECT_ID as string),
    FIREBASE_PRIVATE_KEY: cleanPrivateKey(config.FIREBASE_PRIVATE_KEY as string),
    FIREBASE_CLIENT_EMAIL: cleanEnvString(config.FIREBASE_CLIENT_EMAIL as string),
    SMS_PROVIDER: cleanEnvString(config.SMS_PROVIDER as string),
    SMS_API_KEY: cleanEnvString(config.SMS_API_KEY as string),
    SMS_SENDER_ID: cleanEnvString(config.SMS_SENDER_ID as string),
    CORS_ORIGINS: config.CORS_ORIGINS,
    THROTTLE_TTL: config.THROTTLE_TTL || 60,
    THROTTLE_LIMIT: config.THROTTLE_LIMIT || 100,
  });

  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });

  if (errors.length > 0) {
    const messages = errors
      .flatMap((error) =>
        Object.values(error.constraints ?? {}).map((message) => `${error.property}: ${message}`),
      )
      .join('; ');

    throw new Error(`Invalid environment configuration: ${messages}`);
  }

  if (
    validatedConfig.NODE_ENV === 'production' &&
    (!cleanEnvString(config.RESEND_API_KEY as string) ||
      !cleanEnvString(config.OTP_EMAIL_FROM as string))
  ) {
    throw new Error(
      'Invalid environment configuration: production requires RESEND_API_KEY and OTP_EMAIL_FROM',
    );
  }

  return validatedConfig;
}
