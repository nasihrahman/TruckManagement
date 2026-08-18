import { IsIn, IsOptional, IsDateString } from 'class-validator';

export class TruckExportQueryDto {
  @IsOptional()
  @IsIn(['weekly', 'monthly', 'quarterly'])
  period?: 'weekly' | 'monthly' | 'quarterly';

  @IsOptional()
  @IsDateString()
  date?: string;
}
