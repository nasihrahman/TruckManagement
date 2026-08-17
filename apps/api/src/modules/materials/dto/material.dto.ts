import { IsNotEmpty, IsString, IsOptional } from 'class-validator';

export class CreateMaterialDto {
  @IsNotEmpty()
  @IsString()
  name!: string;
}

export class UpdateMaterialDto {
  @IsOptional()
  @IsString()
  name?: string;
}
