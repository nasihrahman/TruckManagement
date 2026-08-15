import { resolvePeriodRange } from './period.util';

describe('resolvePeriodRange', () => {
  it('resolves a weekly range starting Monday', () => {
    // 2026-08-15 is a Saturday
    const { start, end } = resolvePeriodRange('weekly', new Date('2026-08-15T12:00:00Z'));
    expect(start.toISOString()).toBe('2026-08-10T00:00:00.000Z'); // Monday
    expect(end.toISOString()).toBe('2026-08-17T00:00:00.000Z'); // next Monday
  });

  it('resolves a weekly range when the anchor is already Monday', () => {
    const { start, end } = resolvePeriodRange('weekly', new Date('2026-08-10T00:00:00Z'));
    expect(start.toISOString()).toBe('2026-08-10T00:00:00.000Z');
    expect(end.toISOString()).toBe('2026-08-17T00:00:00.000Z');
  });

  it('resolves a monthly range', () => {
    const { start, end } = resolvePeriodRange('monthly', new Date('2026-08-15T12:00:00Z'));
    expect(start.toISOString()).toBe('2026-08-01T00:00:00.000Z');
    expect(end.toISOString()).toBe('2026-09-01T00:00:00.000Z');
  });

  it('resolves a quarterly range', () => {
    const { start, end } = resolvePeriodRange('quarterly', new Date('2026-08-15T12:00:00Z'));
    expect(start.toISOString()).toBe('2026-07-01T00:00:00.000Z');
    expect(end.toISOString()).toBe('2026-10-01T00:00:00.000Z');
  });

  it('resolves the first quarter correctly across the year boundary', () => {
    const { start, end } = resolvePeriodRange('quarterly', new Date('2026-01-15T12:00:00Z'));
    expect(start.toISOString()).toBe('2026-01-01T00:00:00.000Z');
    expect(end.toISOString()).toBe('2026-04-01T00:00:00.000Z');
  });
});
