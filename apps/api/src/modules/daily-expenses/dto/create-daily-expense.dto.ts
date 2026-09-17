import { IsDateString, IsEnum, IsNumber, IsOptional, IsPositive, IsString } from 'class-validator';
import { ExpenseCategory } from '@prisma/client';

export class CreateDailyExpenseDto {
  @IsDateString()
  date!: string;

  @IsEnum(ExpenseCategory)
  category!: ExpenseCategory;

  @IsNumber()
  @IsPositive()
  amount!: number;

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString()
  photoUrl?: string;

  /// Owner logging on a Driver's behalf — ignored/overridden to the caller's
  /// own id when the caller is a Driver, same pattern as Expense (Override 14).
  @IsOptional()
  @IsString()
  driverId?: string;

  @IsOptional()
  @IsString()
  truckId?: string;
}
