import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';

export class CustomServiceAreaDto {
  @ApiProperty({ example: 'Kolathur' })
  @IsString()
  name!: string;

  @ApiProperty({ example: '600099' })
  @IsString()
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
