import { IsNotEmpty, IsString, IsOptional, Length } from 'class-validator';

export class CreateDriverDto {
  @IsNotEmpty()
  @IsString()
  name!: string;

  @IsNotEmpty()
  @IsString()
  @Length(10, 15)
  phone!: string;

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsString()
  licenseNumber?: string;

  @IsOptional()
  @IsString()
  initialPassword?: string;
}
