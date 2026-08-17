import { IsNotEmpty, IsString, IsOptional } from 'class-validator';

export class CreateSupplierDto {
  @IsNotEmpty()
  @IsString()
  name!: string;
}

export class UpdateSupplierDto {
  @IsOptional()
  @IsString()
  name?: string;
}
