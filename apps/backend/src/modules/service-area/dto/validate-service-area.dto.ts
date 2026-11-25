import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsNumber, IsOptional, Matches } from 'class-validator';

export class ValidateServiceAreaDto {
  @ApiProperty({ example: '600099' })
  @Matches(/^\d{6}$/)
  pincode!: string;

  @ApiPropertyOptional({ example: 13.0827 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  latitude?: number;

  @ApiPropertyOptional({ example: 80.2707 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  longitude?: number;
}
