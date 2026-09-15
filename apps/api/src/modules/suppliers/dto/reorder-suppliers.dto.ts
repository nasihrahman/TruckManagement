import { ArrayNotEmpty, IsArray, IsString } from 'class-validator';

export class ReorderSuppliersDto {
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  ids!: string[];
}
