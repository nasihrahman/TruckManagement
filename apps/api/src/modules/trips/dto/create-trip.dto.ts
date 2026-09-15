import { IsNumber, IsOptional, IsPositive, IsString, IsDate } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateTripDto {
  @IsOptional()
  @Transform(({ value }) => (value ? new Date(value) : value))
  @IsDate()
  scheduledAt?: Date;

  @IsOptional()
  @IsString()
  truckId?: string;

  @IsOptional()
  @IsString()
  driverId?: string;

  @IsOptional()
  @IsString()
  materialId?: string;

  @IsOptional()
  @IsString()
  supplierId?: string;

  // "Other" escape hatch — a one-off value for this trip only, not added to
  // the managed list. The form sends one of materialId/materialOther, never
  // both; not enforced here since there's nothing unsafe about both being
  // absent or the client clearing one by omission.
  @IsOptional()
  @IsString()
  materialOther?: string;

  @IsOptional()
  @IsString()
  supplierOther?: string;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  qtyCf?: number;

  @IsOptional()
  @IsString()
  customerName?: string;
}
