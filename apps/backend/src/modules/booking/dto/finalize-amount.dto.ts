import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNumber, IsOptional, IsString, Length, Min } from 'class-validator';

export class FinalizeAmountDto {
  @ApiProperty({ description: 'Final additional amount in INR', example: 50.0 })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  finalAdditionalAmount!: number;

  @ApiPropertyOptional({
    description: 'Payment method chosen: ONLINE or CASH',
    enum: ['ONLINE', 'CASH'],
    default: 'ONLINE',
  })
  @IsOptional()
  @IsEnum(['ONLINE', 'CASH'])
  paymentMethod?: 'ONLINE' | 'CASH';
}

export class VerifyCompletionOtpDto {
  @ApiProperty({ description: 'Completion OTP provided by customer', example: '1234' })
  @IsString()
  @Length(4, 4)
  otp!: string;
}
