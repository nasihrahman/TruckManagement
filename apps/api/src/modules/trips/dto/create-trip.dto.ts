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

  @IsOptional()
  @IsNumber()
  @IsPositive()
  qtyCf?: number;

  @IsOptional()
  @IsString()
  customerName?: string;
}
