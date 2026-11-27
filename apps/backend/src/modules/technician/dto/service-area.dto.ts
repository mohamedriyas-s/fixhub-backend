import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class CustomServiceAreaDto {
  @ApiProperty({ example: 'Kolathur' })
  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  @MaxLength(100)
  name!: string;

  @ApiProperty({ example: '600099' })
  @IsString()
  @Matches(/^[1-9]\d{5}$/, {
    message: 'Pincode must be a valid 6-digit Indian pincode',
  })
  pincode!: string;
}

export class UpdateServiceAreasDto {
  @ApiPropertyOptional({ type: [String], example: ['service-area-uuid-1'] })
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  serviceAreaIds?: string[];

  @ApiPropertyOptional({ type: [CustomServiceAreaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CustomServiceAreaDto)
  customAreas?: CustomServiceAreaDto[];
}
