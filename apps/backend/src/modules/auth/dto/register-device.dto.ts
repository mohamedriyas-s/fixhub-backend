import { ApiPropertyOptional } from '@nestjs/swagger';
import { DevicePlatform } from '@prisma/client';
import { Transform } from 'class-transformer';
import { IsEnum, IsOptional, IsString } from 'class-validator';

export class RegisterDeviceDto {
  @ApiPropertyOptional({
    description: 'FCM/APNS push notification token',
    example: 'fCm_token_abc123...',
  })
  @Transform(({ value, obj }) => value || obj.fcmToken)
  @IsOptional()
  @IsString()
  deviceToken?: string;

  @ApiPropertyOptional({
    enum: DevicePlatform,
    example: DevicePlatform.ANDROID,
    description: 'Device platform',
  })
  @Transform(({ value, obj }) => {
    const raw = value || obj.deviceType;
    if (typeof raw === 'string') {
      const upper = raw.toUpperCase();
      if (upper in DevicePlatform) return upper;
    }
    return raw;
  })
  @IsOptional()
  @IsEnum(DevicePlatform)
  platform?: DevicePlatform;
}
