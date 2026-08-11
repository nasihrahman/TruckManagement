import { IsNotEmpty, IsString, IsOptional } from 'class-validator';

export class CreateTruckDto {
  @IsNotEmpty()
  @IsString()
  plate!: string;

  @IsNotEmpty()
  @IsString()
  brand!: string;

  @IsOptional()
  @IsString()
  vin?: string;
}

export class UpdateTruckDto {
  @IsOptional()
  @IsString()
  plate?: string;

  @IsOptional()
  @IsString()
  brand?: string;

  @IsOptional()
  @IsString()
  vin?: string;
}
