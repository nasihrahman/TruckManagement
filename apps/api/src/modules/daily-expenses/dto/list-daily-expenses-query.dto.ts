import { IsDateString, IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class ListDailyExpensesQueryDto {
  @IsOptional()
  @IsIn(['daily', 'weekly', 'monthly', 'quarterly'])
  period?: 'daily' | 'weekly' | 'monthly' | 'quarterly';

  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;
}
