import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsNotEmpty, IsPhoneNumber, IsString } from 'class-validator';

import { normalizePhone } from '../../../common/utils/helpers.util';

export class SendOtpDto {
  @ApiProperty({
    example: '+919876543210',
    description: 'Phone number with country code (Indian numbers only)',
  })
  @Transform(({ value }) => (typeof value === 'string' ? normalizePhone(value) : value))
  @IsString()
  @IsNotEmpty()
  @IsPhoneNumber('IN', { message: 'Phone number must be a valid Indian number (+91 or 10 digits)' })
  phone: string;
}
