import { IsDate, IsEnum, IsNumber, IsOptional, IsString } from 'class-validator';
import { Transform } from 'class-transformer';
import { HitachiPayer } from '@prisma/client';

export class CreateHitachiJobDto {
  @IsOptional()
  @IsString()
  driverId?: string;

  @IsOptional()
  @IsString()
  truckId?: string;

  @Transform(({ value }) => (value ? new Date(value) : value))
  @IsDate()
  date!: Date;

  @IsOptional()
  @IsString()
  customerName?: string;

  @IsOptional()
  @IsString()
  place?: string;

  @IsOptional()
  @IsNumber()
  totalHours?: number;

  @IsOptional()
  @IsNumber()
  paymentReceived?: number;

  @IsOptional()
  @IsEnum(HitachiPayer)
  paymentReceivedBy?: HitachiPayer;

  @IsOptional()
  @IsNumber()
  nDieselExpense?: number;

  @IsOptional()
  @IsEnum(HitachiPayer)
  nDieselPaidBy?: HitachiPayer;

  @IsOptional()
  @IsNumber()
  hDieselExpense?: number;

  @IsOptional()
  @IsEnum(HitachiPayer)
  hDieselPaidBy?: HitachiPayer;

  @IsOptional()
  @IsNumber()
  opBata?: number;

  @IsOptional()
  @IsEnum(HitachiPayer)
  opBataPaidBy?: HitachiPayer;

  @IsOptional()
  @IsNumber()
  otherExpenseM?: number;

  @IsOptional()
  @IsNumber()
  otherExpenseJ?: number;

  @IsOptional()
  @IsNumber()
  salaryAdvance?: number;

  @IsOptional()
  @IsString()
  photoUrl?: string;
}

export class UpdateHitachiJobDto {
  @IsOptional()
  @IsString()
  truckId?: string;

  @IsOptional()
  @Transform(({ value }) => (value ? new Date(value) : value))
  @IsDate()
  date?: Date;

  @IsOptional()
  @IsString()
  customerName?: string;

  @IsOptional()
  @IsString()
  place?: string;

  @IsOptional()
  @IsNumber()
  totalHours?: number;

  @IsOptional()
  @IsNumber()
  paymentReceived?: number;

  @IsOptional()
  @IsEnum(HitachiPayer)
  paymentReceivedBy?: HitachiPayer;

  @IsOptional()
  @IsNumber()
  nDieselExpense?: number;

  @IsOptional()
  @IsEnum(HitachiPayer)
  nDieselPaidBy?: HitachiPayer;

  @IsOptional()
  @IsNumber()
  hDieselExpense?: number;

  @IsOptional()
  @IsEnum(HitachiPayer)
  hDieselPaidBy?: HitachiPayer;

  @IsOptional()
  @IsNumber()
  opBata?: number;

  @IsOptional()
  @IsEnum(HitachiPayer)
  opBataPaidBy?: HitachiPayer;

  @IsOptional()
  @IsNumber()
  otherExpenseM?: number;

  @IsOptional()
  @IsNumber()
  otherExpenseJ?: number;

  @IsOptional()
  @IsNumber()
  salaryAdvance?: number;

  @IsOptional()
  @IsString()
  photoUrl?: string;
}
