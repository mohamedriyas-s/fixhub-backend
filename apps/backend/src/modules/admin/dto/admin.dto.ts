import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { CouponType, PaymentStatus, VerificationStatus } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsPhoneNumber,
  IsPositive,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

import { PaginationDto } from '../../../common/dto/pagination.dto';

export class CustomerQueryDto extends PaginationDto {
  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @Transform(({ obj, key }) =>
    obj[key] === 'true' ? true : obj[key] === 'false' ? false : obj[key],
  )
  @IsBoolean()
  isActive?: boolean;
}

export class TechnicianQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: VerificationStatus })
  @IsOptional()
  @IsEnum(VerificationStatus)
  verificationStatus?: VerificationStatus;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @Transform(({ obj, key }) =>
    obj[key] === 'true' ? true : obj[key] === 'false' ? false : obj[key],
  )
  @IsBoolean()
  isAvailable?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @Transform(({ obj, key }) =>
    obj[key] === 'true' ? true : obj[key] === 'false' ? false : obj[key],
  )
  @IsBoolean()
  isActive?: boolean;
}

export class UpdateUserStatusDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  isActive!: boolean;

  @ApiPropertyOptional({ example: 'Violating terms of service' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class VerifyTechnicianDto {
  @ApiProperty({ enum: VerificationStatus, example: VerificationStatus.VERIFIED })
  @IsEnum(VerificationStatus)
  status!: VerificationStatus;

  @ApiPropertyOptional({ example: 'Documents missing' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  rejectionNote?: string;
}

export class PaymentQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: PaymentStatus })
  @IsOptional()
  @IsEnum(PaymentStatus)
  status?: PaymentStatus;
}

// ─── Technician CRUD ─────────────────────────────────────────

export class CreateTechnicianDto {
  @ApiProperty({ example: 'Ravi Kumar' })
  @IsString()
  @MaxLength(100)
  name!: string;

  @ApiProperty({ example: '9876543210' })
  @IsString()
  phone!: string;

  @ApiPropertyOptional({ example: 'ravi@example.com' })
  @IsOptional()
  @IsEmail()
  email?: string;
}

export class UpdateTechnicianDetailsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  email?: string;
}

export class ManageSpecializationDto {
  @ApiProperty()
  @IsUUID()
  subServiceId!: string;
}

export class ManageServiceAreaDto {
  @ApiProperty()
  @IsUUID()
  serviceAreaId!: string;
}

export class EligibleTechnicianQueryDto {
  @ApiProperty({ description: 'SubService ID for matching specializations' })
  @IsUUID()
  subServiceId!: string;

  @ApiProperty({ description: 'Pincode for matching service areas' })
  @IsString()
  pincode!: string;
}

// ─── Customer CRUD ───────────────────────────────────────────

export class CreateCustomerDto {
  @ApiProperty({ example: 'Priya Sharma' })
  @IsString()
  @MaxLength(100)
  name!: string;

  @ApiProperty({ example: '9123456789' })
  @IsString()
  phone!: string;

  @ApiPropertyOptional({ example: 'priya@example.com' })
  @IsOptional()
  @IsEmail()
  email?: string;
}

export class UpdateCustomerDetailsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  email?: string;
}

export class NotifyCustomerDto {
  @ApiProperty({
    example: 'Please complete your profile to get personalized service recommendations.',
  })
  @IsString()
  @MaxLength(500)
  message!: string;
}

// ─── Booking CRUD ─────────────────────────────────────────────

export class AdminCreateBookingDto {
  @ApiProperty()
  @IsUUID()
  customerId!: string;

  @ApiProperty()
  @IsUUID()
  subServiceId!: string;

  @ApiProperty()
  @IsUUID()
  addressId!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  technicianId?: string;

  @ApiProperty({ example: '2025-08-01' })
  @IsDateString()
  scheduledDate!: string;

  @ApiProperty({ example: '10:00-12:00' })
  @IsString()
  scheduledSlot!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ example: 499 })
  @IsNumber()
  @IsPositive()
  totalAmount!: number;
}

export class AdminCancelBookingDto {
  @ApiProperty({ example: 'Customer requested cancellation via phone' })
  @IsString()
  @MaxLength(500)
  reason!: string;
}

// ─── Pricing CRUD ─────────────────────────────────────────────

export class CreatePricingRuleDto {
  @ApiPropertyOptional({ description: 'null = global default' })
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @ApiProperty({ example: 'Electrical Services' })
  @IsString()
  @MaxLength(100)
  label!: string;

  @ApiProperty({ example: 49, description: 'Base diagnostic/visiting fee in ₹' })
  @IsNumber()
  @Min(0)
  baseFee!: number;

  @ApiProperty({ example: 18, description: 'GST percentage' })
  @IsNumber()
  @Min(0)
  taxPercent!: number;

  @ApiPropertyOptional({ example: 10, description: 'Cancellation fee as % of total amount' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  cancellationFeePercent?: number;

  @ApiPropertyOptional({ example: 60, description: 'Free cancellation window in minutes' })
  @IsOptional()
  @IsInt()
  @Min(0)
  cancellationWindowMins?: number;
}

export class UpdatePricingRuleDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  label?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  baseFee?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  taxPercent?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  cancellationFeePercent?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  cancellationWindowMins?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

// ─── Coupon CRUD ──────────────────────────────────────────────

export class CreateCouponDto {
  @ApiProperty({ example: 'FIRST25' })
  @IsString()
  @MaxLength(50)
  code!: string;

  @ApiPropertyOptional({ example: '25% OFF on your first booking' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;

  @ApiProperty({ enum: CouponType, example: CouponType.PERCENTAGE })
  @IsEnum(CouponType)
  type!: CouponType;

  @ApiProperty({ example: 25, description: 'Percentage value or flat ₹ amount' })
  @IsNumber()
  @IsPositive()
  value!: number;

  @ApiPropertyOptional({ example: 500, description: 'Max discount cap for percentage coupons' })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  maxDiscountAmount?: number;

  @ApiPropertyOptional({ example: 200, description: 'Minimum order amount to apply coupon' })
  @IsOptional()
  @IsNumber()
  @IsPositive()
  minOrderAmount?: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  firstBookingOnly?: boolean;

  @ApiPropertyOptional({ example: 1000 })
  @IsOptional()
  @IsInt()
  @IsPositive()
  maxUses?: number;

  @ApiPropertyOptional({ example: '2025-12-31T23:59:59Z' })
  @IsOptional()
  @IsDateString()
  expiresAt?: string;

  @ApiPropertyOptional({ description: 'Restrict to a category (null = all)' })
  @IsOptional()
  @IsUUID()
  categoryId?: string;
}

export class UpdateCouponDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @IsPositive()
  maxUses?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  expiresAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class CouponQueryDto extends PaginationDto {
  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @Transform(({ obj, key }) =>
    obj[key] === 'true' ? true : obj[key] === 'false' ? false : obj[key],
  )
  @IsBoolean()
  isActive?: boolean;
}
