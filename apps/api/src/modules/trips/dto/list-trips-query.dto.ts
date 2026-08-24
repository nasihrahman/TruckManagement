import { IsInt, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

/// Pagination for GET /trips. Deliberately OPT-IN: omitting `limit` returns
/// every trip, which is the behaviour the currently-deployed mobile app
/// depends on (the Owner dashboard derives its trip counts and expense totals
/// from the full list client-side). Defaulting to a page size here would
/// silently make those figures wrong. Once the app sends `limit` and the
/// dashboard totals are computed server-side, the default can change.
export class ListTripsQueryDto {
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
