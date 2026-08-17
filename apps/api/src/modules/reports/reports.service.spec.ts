import { Test, TestingModule } from '@nestjs/testing';
import { ReportsService } from './reports.service';
import { ReportsRepository } from './reports.repository';

describe('ReportsService', () => {
  let service: ReportsService;

  const mockRepository = {
    findTripsCreatedInRange: jest.fn(),
    findTripsCompletedInRange: jest.fn(),
    findExpensesInRange: jest.fn(),
    findTripsCreatedInRangeDetailed: jest.fn(),
    findExpensesInRangeDetailed: jest.fn(),
  };

  const driverA = { id: 'driver-a', firstName: 'Alice', lastName: null };
  const driverB = { id: 'driver-b', firstName: 'Bob', lastName: null };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [ReportsService, { provide: ReportsRepository, useValue: mockRepository }],
    }).compile();

    service = module.get<ReportsService>(ReportsService);
  });

  it('aggregates trips and expenses for the period', async () => {
    mockRepository.findTripsCreatedInRange.mockResolvedValue([{ id: 't1' }, { id: 't2' }, { id: 't3' }]);
    mockRepository.findTripsCompletedInRange.mockResolvedValue([
      { id: 't1', status: 'DELIVERED', driverId: 'driver-a', driver: driverA },
      { id: 't2', status: 'DELIVERED', driverId: 'driver-a', driver: driverA },
      { id: 't3', status: 'FAILED', driverId: 'driver-b', driver: driverB },
    ]);
    mockRepository.findExpensesInRange.mockResolvedValue([
      { id: 'e1', amount: 100, category: 'FUEL', driverId: 'driver-a', driver: driverA },
      { id: 'e2', amount: 50, category: 'FINE', driverId: 'driver-b', driver: driverB },
    ]);

    const result = await service.getOperationsReport('company-1', 'weekly');

    expect(result.trips.createdTotal).toBe(3);
    expect(result.trips.completedTotal).toBe(3);
    expect(result.trips.delivered).toBe(2);
    expect(result.trips.failed).toBe(1);
    expect(result.trips.completionRate).toBeCloseTo(2 / 3);
    expect(result.trips.byDriver).toEqual(
      expect.arrayContaining([
        { driverId: 'driver-a', name: 'Alice', delivered: 2, failed: 0 },
        { driverId: 'driver-b', name: 'Bob', delivered: 0, failed: 1 },
      ]),
    );

    expect(result.expenses.total).toBe(150);
    expect(result.expenses.byCategory).toEqual({ FUEL: 100, FINE: 50 });
    expect(result.expenses.byDriver).toEqual(
      expect.arrayContaining([
        { driverId: 'driver-a', name: 'Alice', total: 100 },
        { driverId: 'driver-b', name: 'Bob', total: 50 },
      ]),
    );
  });

  it('returns a zero completion rate when nothing completed in the period', async () => {
    mockRepository.findTripsCreatedInRange.mockResolvedValue([]);
    mockRepository.findTripsCompletedInRange.mockResolvedValue([]);
    mockRepository.findExpensesInRange.mockResolvedValue([]);

    const result = await service.getOperationsReport('company-1', 'monthly');

    expect(result.trips.completionRate).toBe(0);
    expect(result.trips.createdTotal).toBe(0);
    expect(result.expenses.total).toBe(0);
  });

  it('passes the requested period through to the response', async () => {
    mockRepository.findTripsCreatedInRange.mockResolvedValue([]);
    mockRepository.findTripsCompletedInRange.mockResolvedValue([]);
    mockRepository.findExpensesInRange.mockResolvedValue([]);

    const result = await service.getOperationsReport('company-1', 'quarterly', '2026-02-01');

    expect(result.period).toBe('quarterly');
    expect(result.rangeStart).toBe('2026-01-01T00:00:00.000Z');
    expect(result.rangeEnd).toBe('2026-04-01T00:00:00.000Z');
  });

  describe('exportOperationsDetail', () => {
    it('queries the detailed repository methods for the resolved range and returns a workbook buffer', async () => {
      mockRepository.findTripsCreatedInRangeDetailed.mockResolvedValue([
        {
          supplier: { name: 'ACME Quarry' },
          customerName: 'B',
          status: 'DELIVERED',
          scheduledAt: new Date('2026-08-11'),
          startedAt: new Date('2026-08-11'),
          completedAt: new Date('2026-08-12'),
          financiallyClosed: true,
          driver: driverA,
          truck: { plate: 'TRK-1', brand: 'Tata' },
        },
      ]);
      mockRepository.findExpensesInRangeDetailed.mockResolvedValue([
        {
          amount: 250,
          category: 'FUEL',
          reason: null,
          notes: 'Full tank',
          createdAt: new Date('2026-08-11'),
          driver: driverA,
          trip: { supplier: { name: 'ACME Quarry' }, customerName: 'B' },
        },
      ]);

      const buffer = await service.exportOperationsDetail('company-1', 'weekly', '2026-08-15');

      expect(mockRepository.findTripsCreatedInRangeDetailed).toHaveBeenCalledWith(
        'company-1',
        new Date('2026-08-10T00:00:00.000Z'),
        new Date('2026-08-17T00:00:00.000Z'),
      );
      expect(mockRepository.findExpensesInRangeDetailed).toHaveBeenCalledWith(
        'company-1',
        new Date('2026-08-10T00:00:00.000Z'),
        new Date('2026-08-17T00:00:00.000Z'),
      );
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(0);
    });
  });
});
