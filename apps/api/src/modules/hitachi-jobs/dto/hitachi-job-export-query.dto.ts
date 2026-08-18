import { IsIn, IsOptional, IsDateString } from 'class-validator';

export class HitachiJobExportQueryDto {
  @IsOptional()
  @IsIn(['weekly', 'monthly', 'quarterly'])
  period?: 'weekly' | 'monthly' | 'quarterly';

  @IsOptional()
  @IsDateString()
  date?: string;
}
