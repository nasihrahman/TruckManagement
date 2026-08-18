import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { HitachiJobsService } from './hitachi-jobs.service';
import { HitachiJobsRepository } from './hitachi-jobs.repository';

describe('HitachiJobsService', () => {
  let service: HitachiJobsService;

  const mockRepository = {
    create: jest.fn(),
    findById: jest.fn(),
    findByCompany: jest.fn(),
    findByCompanyAndDriver: jest.fn(),
    findForExport: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };

  const mockJob = {
    id: 'job-1',
    companyId: 'company-1',
    driverId: 'driver-1',
    date: new Date('2026-08-18'),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [HitachiJobsService, { provide: HitachiJobsRepository, useValue: mockRepository }],
    }).compile();

    service = module.get<HitachiJobsService>(HitachiJobsService);
  });

  describe('create', () => {
    it('forces driverId to the caller when the caller is a DRIVER', async () => {
      mockRepository.create.mockResolvedValue(mockJob);

      await service.create(
        { userId: 'driver-1', role: 'DRIVER', companyId: 'company-1' },
        { date: mockJob.date, driverId: 'someone-else' } as any,
      );

      expect(mockRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({ driverId: 'driver-1', companyId: 'company-1' }),
      );
    });

    it('uses the supplied driverId when the caller is an OWNER', async () => {
      mockRepository.create.mockResolvedValue(mockJob);

      await service.create(
        { userId: 'owner-1', role: 'OWNER', companyId: 'company-1' },
        { date: mockJob.date, driverId: 'driver-1' } as any,
      );

      expect(mockRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({ driverId: 'driver-1', companyId: 'company-1' }),
      );
    });

    it('throws BadRequestException when an OWNER omits driverId', async () => {
      await expect(
        service.create({ userId: 'owner-1', role: 'OWNER', companyId: 'company-1' }, { date: mockJob.date } as any),
      ).rejects.toThrow(BadRequestException);
      expect(mockRepository.create).not.toHaveBeenCalled();
    });
  });

  describe('findOne', () => {
    it('throws NotFoundException when the job is not in the caller company', async () => {
      mockRepository.findById.mockResolvedValue({ ...mockJob, companyId: 'other-company' });

      await expect(
        service.findOne('job-1', { userId: 'driver-1', role: 'DRIVER', companyId: 'company-1' }),
      ).rejects.toThrow(NotFoundException);
    });

    it('throws ForbiddenException when a driver requests another driver\'s entry', async () => {
      mockRepository.findById.mockResolvedValue(mockJob);

      await expect(
        service.findOne('job-1', { userId: 'driver-2', role: 'DRIVER', companyId: 'company-1' }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('remove', () => {
    it('lets the owning driver delete their own entry', async () => {
      mockRepository.findById.mockResolvedValue(mockJob);
      mockRepository.delete.mockResolvedValue(mockJob);

      const result = await service.remove('job-1', { userId: 'driver-1', role: 'DRIVER', companyId: 'company-1' });

      expect(mockRepository.delete).toHaveBeenCalledWith('job-1');
      expect(result).toEqual(mockJob);
    });

    it('blocks a different driver from deleting the entry', async () => {
      mockRepository.findById.mockResolvedValue(mockJob);

      await expect(
        service.remove('job-1', { userId: 'driver-2', role: 'DRIVER', companyId: 'company-1' }),
      ).rejects.toThrow(ForbiddenException);
      expect(mockRepository.delete).not.toHaveBeenCalled();
    });
  });

  describe('exportToExcel', () => {
    it('scopes the export to the caller when they are a DRIVER, with no date range when period is omitted', async () => {
      mockRepository.findForExport.mockResolvedValue([]);

      await service.exportToExcel({ userId: 'driver-1', role: 'DRIVER', companyId: 'company-1' });

      expect(mockRepository.findForExport).toHaveBeenCalledWith('company-1', 'driver-1', undefined);
    });

    it('exports the whole company (no driver filter) when the caller is an OWNER', async () => {
      mockRepository.findForExport.mockResolvedValue([]);

      await service.exportToExcel({ userId: 'owner-1', role: 'OWNER', companyId: 'company-1' });

      expect(mockRepository.findForExport).toHaveBeenCalledWith('company-1', undefined, undefined);
    });

    it('resolves a date range when a period is given', async () => {
      mockRepository.findForExport.mockResolvedValue([]);

      await service.exportToExcel({ userId: 'driver-1', role: 'DRIVER', companyId: 'company-1' }, 'weekly', '2026-08-18');

      expect(mockRepository.findForExport).toHaveBeenCalledWith(
        'company-1',
        'driver-1',
        { start: new Date(Date.UTC(2026, 7, 17)), end: new Date(Date.UTC(2026, 7, 24)) },
      );
    });

    it('computes Bal (J) correctly, only counting diesel/bata paid by Jamal', async () => {
      mockRepository.findForExport.mockResolvedValue([
        {
          date: new Date('2026-08-18'),
          driver: { firstName: 'Test', lastName: 'Driver' },
          customerName: 'Arjuna',
          place: 'Edayar',
          totalHours: '6.7',
          paymentReceived: '8400',
          paymentReceivedBy: 'J',
          nDieselExpense: '1600',
          nDieselPaidBy: 'J',
          hDieselExpense: '300',
          hDieselPaidBy: 'M',
          opBata: '300',
          opBataPaidBy: 'J',
          otherExpenseM: null,
          otherExpenseJ: '200',
          salaryAdvance: '500',
        },
      ]);

      const buffer = await service.exportToExcel({ userId: 'owner-1', role: 'OWNER', companyId: 'company-1' });
      expect(buffer.length).toBeGreaterThan(0);
    });
  });
});
