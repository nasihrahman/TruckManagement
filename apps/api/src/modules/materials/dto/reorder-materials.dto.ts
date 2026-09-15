import { ArrayNotEmpty, IsArray, IsString } from 'class-validator';

/// Every Material id belonging to the company, in the new display order —
/// the client always sends the full list since a drag reorders the whole
/// sequence, not one item's position in isolation.
export class ReorderMaterialsDto {
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  ids!: string[];
}
