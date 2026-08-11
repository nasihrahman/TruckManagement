import { IsISO8601, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class UpdateTripDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  origin?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  destination?: string;

  @IsOptional()
  @IsISO8601()
  scheduledAt?: string;

  @IsOptional()
  @IsString()
  truckId?: string;

  @IsOptional()
  @IsString()
  driverId?: string;
}
