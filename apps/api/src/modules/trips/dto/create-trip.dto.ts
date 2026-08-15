import { IsNotEmpty, IsOptional, IsString, IsDate } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateTripDto {
  @IsString()
  @IsNotEmpty()
  origin!: string;

  @IsString()
  @IsNotEmpty()
  destination!: string;

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
}
