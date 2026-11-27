import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsEmail,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsPhoneNumber,
  IsString,
  MaxLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

import { normalizePhone } from '../../../common/utils/helpers.util';

export class UpdateTechnicianProfileDto {
  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;

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

export class UpdateUserProfileDto {
  @ApiPropertyOptional({ example: 'Ravi Kumar', maxLength: 120 })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @ApiPropertyOptional({ example: 'ravi@example.com', maxLength: 255 })
  @IsOptional()
  @IsEmail()
  @MaxLength(255)
  email?: string;

  @ApiPropertyOptional({ example: '+919876543210', description: 'Booking contact number' })
  @Transform(({ value }) => {
    if (value === null) return null;
    if (typeof value !== 'string') return value;
    const trimmed = value.trim();
    return trimmed === '' ? null : normalizePhone(trimmed);
  })
  @ValidateIf((_, v) => v !== null && v !== undefined)
  @IsPhoneNumber('IN')
  phone?: string | null;

  @ApiPropertyOptional({ type: UpdateTechnicianProfileDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => UpdateTechnicianProfileDto)
  technician?: UpdateTechnicianProfileDto;
}
