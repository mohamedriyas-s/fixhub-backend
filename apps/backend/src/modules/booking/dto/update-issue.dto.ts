import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateIssueDto {
  @ApiPropertyOptional({
    description: 'Detailed description of the issue (max 1000 characters)',
    example: 'AC is not cooling properly and making a strange humming noise.',
  })
  @IsString()
  @IsOptional()
  @MaxLength(1000)
  description?: string;
}
