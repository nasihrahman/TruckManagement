export type ReportPeriod = 'weekly' | 'monthly' | 'quarterly';

export interface PeriodRange {
  start: Date;
  end: Date;
}

/**
 * Resolves a period keyword + anchor date into a [start, end) UTC range.
 * end is exclusive. Weeks start on Monday.
 */
export function resolvePeriodRange(period: ReportPeriod, anchor: Date): PeriodRange {
  const day = new Date(Date.UTC(anchor.getUTCFullYear(), anchor.getUTCMonth(), anchor.getUTCDate()));

  switch (period) {
    case 'weekly': {
      const weekday = day.getUTCDay(); // 0=Sun..6=Sat
      const diffToMonday = (weekday + 6) % 7;
      const start = new Date(day);
      start.setUTCDate(day.getUTCDate() - diffToMonday);
      const end = new Date(start);
      end.setUTCDate(start.getUTCDate() + 7);
      return { start, end };
    }
    case 'monthly': {
      const start = new Date(Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), 1));
      const end = new Date(Date.UTC(day.getUTCFullYear(), day.getUTCMonth() + 1, 1));
      return { start, end };
    }
    case 'quarterly': {
      const quarter = Math.floor(day.getUTCMonth() / 3);
      const start = new Date(Date.UTC(day.getUTCFullYear(), quarter * 3, 1));
      const end = new Date(Date.UTC(day.getUTCFullYear(), quarter * 3 + 3, 1));
      return { start, end };
    }
  }
}
