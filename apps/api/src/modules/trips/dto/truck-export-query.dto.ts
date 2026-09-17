import { IsIn, IsOptional, IsDateString } from 'class-validator';

export class TruckExportQueryDto {
  @IsOptional()
  @IsIn(['daily', 'weekly', 'monthly', 'quarterly'])
  period?: 'daily' | 'weekly' | 'monthly' | 'quarterly';

  @IsOptional()
  @IsDateString()
  date?: string;
}
