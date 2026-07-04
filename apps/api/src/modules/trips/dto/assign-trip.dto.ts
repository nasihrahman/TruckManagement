import { IsString, IsOptional } from 'class-validator';

export class AssignTripDto {
  @IsOptional()
  @IsString()
  truckId?: string;

  @IsOptional()
  @IsString()
  driverId?: string;
}
