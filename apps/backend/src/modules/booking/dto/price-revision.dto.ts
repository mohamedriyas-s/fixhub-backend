import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsNumber, IsOptional, IsPositive, IsString, Max, MaxLength, Min } from 'class-validator';

// ── Additional Charge & Price Revision DTOs ───────────────────────────────────

export class ProposeAdditionalChargeDto {
  @ApiProperty({
    example: 50.0,
    description:
      'Additional charge requested in INR (strictly numbers, positive, max 2 decimal places)',
  })
  @Type(() => Number)
  @IsNumber(
    { allowNaN: false, allowInfinity: false, maxDecimalPlaces: 2 },
    { message: 'Amount must be a valid number with at most 2 decimal places' },
  )
  @IsPositive({ message: 'Amount must be a positive number greater than 0' })
  @Min(1, { message: 'Amount must be at least ₹1' })
  @Max(100000, { message: 'Amount cannot exceed ₹100,000' })
  amount!: number;

  @ApiPropertyOptional({
    example: 'AC dual-run capacitor replacement',
    description: 'Optional description of extra items or work (max 100 characters)',
  })
  @IsOptional()
  @IsString({ message: 'Description must be a string' })
  @MaxLength(100, { message: 'Description cannot exceed 100 characters' })
  description?: string;

  @ApiPropertyOptional({
    example: 'Capacitor damaged due to power fluctuation',
    description: 'Optional reason for the additional charge (max 300 characters)',
  })
  @IsOptional()
  @IsString({ message: 'Reason must be a string' })
  @MaxLength(300, { message: 'Reason cannot exceed 300 characters' })
  reason?: string;
}

export class ProposeRevisionDto {
  @ApiPropertyOptional({ example: 1500.0, description: 'Proposed revised total amount in INR' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber(
    { allowNaN: false, allowInfinity: false, maxDecimalPlaces: 2 },
    { message: 'Revised amount must be a valid number with at most 2 decimal places' },
  )
  @IsPositive({ message: 'Revised amount must be greater than 0' })
  @Min(1, { message: 'Revised amount must be at least ₹1' })
  @Max(200000, { message: 'Revised amount cannot exceed ₹200,000' })
  revisedAmount?: number;

  @ApiPropertyOptional({ example: 50.0, description: 'Additional charge requested in INR' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber(
    { allowNaN: false, allowInfinity: false, maxDecimalPlaces: 2 },
    { message: 'Amount must be a valid number with at most 2 decimal places' },
  )
  @IsPositive({ message: 'Amount must be greater than 0' })
  @Min(1, { message: 'Amount must be at least ₹1' })
  @Max(100000, { message: 'Amount cannot exceed ₹100,000' })
  amount?: number;

  @ApiPropertyOptional({ example: 'AC capacitor replacement' })
  @IsOptional()
  @IsString({ message: 'Description must be a string' })
  @MaxLength(100, { message: 'Description cannot exceed 100 characters' })
  description?: string;

  @ApiPropertyOptional({ example: 'Capacitor burnt out' })
  @IsOptional()
  @IsString({ message: 'Reason must be a string' })
  @MaxLength(300, { message: 'Reason cannot exceed 300 characters' })
  reason?: string;

  @ApiPropertyOptional({ example: 'Additional parts required for the repair' })
  @IsOptional()
  @IsString({ message: 'Note must be a string' })
  @MaxLength(300, { message: 'Note cannot exceed 300 characters' })
  note?: string;
}
