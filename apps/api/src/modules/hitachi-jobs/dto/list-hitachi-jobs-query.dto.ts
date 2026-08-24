import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

/// Pagination for GET /hitachi-jobs. Opt-in for the same reason as
/// ListTripsQueryDto: omitting `limit` returns everything, which is what the
/// currently-deployed mobile app expects. A default page size here would
/// silently truncate the list for users running the existing APK.
export class ListHitachiJobsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;
}
