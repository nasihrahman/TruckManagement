import { IsDateString, IsIn, IsOptional } from 'class-validator';

/// Unlike the trips/Hitachi export DTOs, this one includes 'daily' — the
/// client explicitly asked to export "daily, weekly, etc." for lump expenses,
/// where a single day is a meaningful export unit on its own.
export class DailyExpenseExportQueryDto {
  @IsOptional()
  @IsIn(['daily', 'weekly', 'monthly', 'quarterly'])
  period?: 'daily' | 'weekly' | 'monthly' | 'quarterly';

  @IsOptional()
  @IsDateString()
  date?: string;
}
