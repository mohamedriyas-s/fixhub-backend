import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform , Type } from 'class-transformer';
import {
  IsEmail,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsPhoneNumber,
  IsString,
  IsUrl,
  MaxLength,
} from 'class-validator';

import { normalizePhone } from '../../../common/utils/helpers.util';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Ramesh Kumar' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({ example: 'ramesh@example.com' })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ example: '+919876543210', description: 'Booking contact number' })
  @IsOptional()
  @IsPhoneNumber('IN')
  @Transform(({ value }) => (typeof value === 'string' ? normalizePhone(value) : value))
  phone?: string;

  @ApiPropertyOptional({ example: 'https://cdn.fixhub.in/profiles/photo.jpg' })
  @IsOptional()
  @IsUrl()
  profilePictureUrl?: string;

  @ApiPropertyOptional({ example: 13.0826802 })
  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional({ example: 80.2707184 })
  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  longitude?: number;
}
