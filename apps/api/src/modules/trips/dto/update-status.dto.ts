import { IsEnum } from 'class-validator';
import { TripStatus } from '@prisma/client';

export class UpdateStatusDto {
  @IsEnum(TripStatus)
  status!: TripStatus;
}
