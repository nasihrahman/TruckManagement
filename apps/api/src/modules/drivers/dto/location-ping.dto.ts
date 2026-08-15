import { IsLatitude, IsLongitude } from 'class-validator';

export class LocationPingDto {
  @IsLatitude()
  latitude!: number;

  @IsLongitude()
  longitude!: number;
}
