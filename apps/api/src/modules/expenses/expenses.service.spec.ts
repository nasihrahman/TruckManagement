import { Test, TestingModule } from '@nestjs/testing';
import { ExpensesService } from './expenses.service';
import { ExpensesRepository } from './expenses.repository';
import { TripsRepository } from '../trips/trips.repository';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';

describe('ExpensesService', () => {
  let service: ExpensesService;

  const mockExpensesRepository = {
    create: jest.fn(),
    findById: jest.fn(),
    findByTrip: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };

  const mockTripsRepository = {
    findById: jest.fn(),
  };

  const driverUser = { userId: 'driver-1', role: 'DRIVER', companyId: 'company-1' };
  const otherDriverUser = { userId: 'driver-2', role: 'DRIVER', companyId: 'company-1' };
  const ownerUser = { userId: 'owner-1', role: 'OWNER', companyId: 'company-1' };

  const openTrip = {
    id: 'trip-1',
    companyId: 'company-1',
    driverId: 'driver-1',
    financiallyClosed: false,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ExpensesService,
        { provide: ExpensesRepository, useValue: mockExpensesRepository },
        { provide: TripsRepository, useValue: mockTripsRepository },
      ],
    }).compile();

    service = module.get<ExpensesService>(ExpensesService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    const dto = { category: 'FUEL' as const, amount: 50, odometer: 12345 };

    it('lets the assigned driver log an expense on an open trip', async () => {
      mockTripsRepository.findById.mockResolvedValue(openTrip);
      mockExpensesRepository.create.mockResolvedValue({ id: 'expense-1', ...dto });

      const result = await service.create('trip-1', driverUser, dto);

      expect(mockExpensesRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({ tripId: 'trip-1', driverId: 'driver-1', companyId: 'company-1', category: 'FUEL', amount: 50 }),
      );
      expect(result).toEqual({ id: 'expense-1', ...dto });
    });

    it('throws NotFoundException if the trip belongs to a different company', async () => {
      mockTripsRepository.findById.mockResolvedValue({ ...openTrip, companyId: 'other-company' });

      await expect(service.create('trip-1', driverUser, dto)).rejects.toThrow(NotFoundException);
    });

    it('throws ForbiddenException if the driver is not assigned to the trip', async () => {
      mockTripsRepository.findById.mockResolvedValue(openTrip);

      await expect(service.create('trip-1', otherDriverUser, dto)).rejects.toThrow(ForbiddenException);
    });

    it('throws ForbiddenException for an Owner trying to log an expense', async () => {
      mockTripsRepository.findById.mockResolvedValue(openTrip);

      await expect(service.create('trip-1', ownerUser, dto)).rejects.toThrow(ForbiddenException);
    });

    it('throws BadRequestException if the trip is financially closed', async () => {
      mockTripsRepository.findById.mockResolvedValue({ ...openTrip, financiallyClosed: true });

      await expect(service.create('trip-1', driverUser, dto)).rejects.toThrow(BadRequestException);
    });
  });

  describe('findByTrip', () => {
    it('lets the Owner list expenses for any trip in their company', async () => {
      mockTripsRepository.findById.mockResolvedValue(openTrip);
      mockExpensesRepository.findByTrip.mockResolvedValue([]);

      await expect(service.findByTrip('trip-1', ownerUser)).resolves.toEqual([]);
    });

    it('blocks a driver from listing expenses on a trip they are not assigned to', async () => {
      mockTripsRepository.findById.mockResolvedValue(openTrip);

      await expect(service.findByTrip('trip-1', otherDriverUser)).rejects.toThrow(ForbiddenException);
    });
  });

  describe('update', () => {
    const existingExpense = { id: 'expense-1', tripId: 'trip-1', driverId: 'driver-1' };

    it('lets the logging driver edit their expense on an open trip', async () => {
      mockTripsRepository.findById.mockResolvedValue(openTrip);
      mockExpensesRepository.findById.mockResolvedValue(existingExpense);
      mockExpensesRepository.update.mockResolvedValue({ ...existingExpense, amount: 75 });

      const result = await service.update('trip-1', 'expense-1', driverUser, { amount: 75 });

      expect(result.amount).toBe(75);
    });

    it('throws BadRequestException once the trip is financially closed', async () => {
      mockTripsRepository.findById.mockResolvedValue({ ...openTrip, financiallyClosed: true });
      mockExpensesRepository.findById.mockResolvedValue(existingExpense);

      await expect(service.update('trip-1', 'expense-1', driverUser, { amount: 75 })).rejects.toThrow(BadRequestException);
    });

    it('throws ForbiddenException if a different driver tries to edit the expense', async () => {
      mockTripsRepository.findById.mockResolvedValue({ ...openTrip, driverId: 'driver-2' });
      mockExpensesRepository.findById.mockResolvedValue({ ...existingExpense, driverId: 'driver-2' });

      await expect(service.update('trip-1', 'expense-1', driverUser, { amount: 75 })).rejects.toThrow(ForbiddenException);
    });

    it('throws NotFoundException if the expense does not belong to the given trip', async () => {
      mockTripsRepository.findById.mockResolvedValue(openTrip);
      mockExpensesRepository.findById.mockResolvedValue({ ...existingExpense, tripId: 'trip-other' });

      await expect(service.update('trip-1', 'expense-1', driverUser, { amount: 75 })).rejects.toThrow(NotFoundException);
    });
  });

  describe('delete', () => {
    const existingExpense = { id: 'expense-1', tripId: 'trip-1', driverId: 'driver-1' };

    it('lets the logging driver delete their expense on an open trip', async () => {
      mockTripsRepository.findById.mockResolvedValue(openTrip);
      mockExpensesRepository.findById.mockResolvedValue(existingExpense);
      mockExpensesRepository.delete.mockResolvedValue(existingExpense);

      await service.delete('trip-1', 'expense-1', driverUser);

      expect(mockExpensesRepository.delete).toHaveBeenCalledWith('expense-1');
    });

    it('throws BadRequestException once the trip is financially closed', async () => {
      mockTripsRepository.findById.mockResolvedValue({ ...openTrip, financiallyClosed: true });
      mockExpensesRepository.findById.mockResolvedValue(existingExpense);

      await expect(service.delete('trip-1', 'expense-1', driverUser)).rejects.toThrow(BadRequestException);
    });

    it('throws ForbiddenException if a different driver tries to delete the expense', async () => {
      mockTripsRepository.findById.mockResolvedValue({ ...openTrip, driverId: 'driver-2' });
      mockExpensesRepository.findById.mockResolvedValue({ ...existingExpense, driverId: 'driver-2' });

      await expect(service.delete('trip-1', 'expense-1', driverUser)).rejects.toThrow(ForbiddenException);
    });

    it('throws NotFoundException if the expense does not belong to the given trip', async () => {
      mockTripsRepository.findById.mockResolvedValue(openTrip);
      mockExpensesRepository.findById.mockResolvedValue({ ...existingExpense, tripId: 'trip-other' });

      await expect(service.delete('trip-1', 'expense-1', driverUser)).rejects.toThrow(NotFoundException);
    });
  });
});
