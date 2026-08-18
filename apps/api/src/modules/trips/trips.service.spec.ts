import { Test, TestingModule } from '@nestjs/testing';
import { TripsService } from './trips.service';
import { TripsRepository } from './trips.repository';

describe('TripsService', () => {
  let service: TripsService;
  const repo = {
    create: jest.fn(),
    findByCompany: jest.fn(),
    findById: jest.fn(),
    update: jest.fn(),
    updateStatus: jest.fn(),
    remove: jest.fn(),
    findByCompanyForTruckExport: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [TripsService, { provide: TripsRepository, useValue: repo }],
    }).compile();

    service = module.get<TripsService>(TripsService);
  });

  it('creates a trip for an Owner, keeping any driverId supplied', async () => {
    repo.create.mockResolvedValue({ id: 't1' });
    const owner = { userId: 'owner-1', role: 'OWNER', companyId: 'company-1' };
    const res = await service.create(owner, { driverId: 'driver-9' } as any);
    expect(repo.create).toHaveBeenCalledWith(
      expect.objectContaining({ companyId: 'company-1', driverId: 'driver-9' }),
    );
    expect(res).toHaveProperty('id', 't1');
  });

  it('forces driverId to self when a Driver self-assigns a trip', async () => {
    repo.create.mockResolvedValue({ id: 't2' });
    const driver = { userId: 'driver-1', role: 'DRIVER', companyId: 'company-1' };
    await service.create(driver, { driverId: 'someone-else' } as any);
    expect(repo.create).toHaveBeenCalledWith(
      expect.objectContaining({ companyId: 'company-1', driverId: 'driver-1' }),
    );
  });

  describe('remove', () => {
    const owner = { userId: 'owner-1', role: 'OWNER', companyId: 'company-1' };
    const driver = { userId: 'driver-1', role: 'DRIVER', companyId: 'company-1' };

    it('lets an Owner delete any trip in their company regardless of status', async () => {
      repo.findById.mockResolvedValue({ id: 't1', companyId: 'company-1', driverId: 'driver-1', status: 'DELIVERED' });
      await service.remove('t1', owner);
      expect(repo.remove).toHaveBeenCalledWith('t1');
    });

    it('blocks an Owner from deleting a trip belonging to another company', async () => {
      repo.findById.mockResolvedValue({ id: 't1', companyId: 'company-2', driverId: 'driver-1', status: 'ASSIGNED' });
      await expect(service.remove('t1', owner)).rejects.toThrow();
      expect(repo.remove).not.toHaveBeenCalled();
    });

    it('lets a Driver delete their own ASSIGNED trip', async () => {
      repo.findById.mockResolvedValue({ id: 't1', companyId: 'company-1', driverId: 'driver-1', status: 'ASSIGNED' });
      await service.remove('t1', driver);
      expect(repo.remove).toHaveBeenCalledWith('t1');
    });

    it('blocks a Driver from deleting a trip assigned to someone else', async () => {
      repo.findById.mockResolvedValue({ id: 't1', companyId: 'company-1', driverId: 'other-driver', status: 'ASSIGNED' });
      await expect(service.remove('t1', driver)).rejects.toThrow();
      expect(repo.remove).not.toHaveBeenCalled();
    });

    it('blocks a Driver from deleting their own trip once it is past ASSIGNED', async () => {
      repo.findById.mockResolvedValue({ id: 't1', companyId: 'company-1', driverId: 'driver-1', status: 'IN_TRANSIT' });
      await expect(service.remove('t1', driver)).rejects.toThrow();
      expect(repo.remove).not.toHaveBeenCalled();
    });
  });

  describe('exportByTruckToExcel', () => {
    it('exports all-time when no period is given', async () => {
      repo.findByCompanyForTruckExport.mockResolvedValue([]);

      await service.exportByTruckToExcel('company-1');

      expect(repo.findByCompanyForTruckExport).toHaveBeenCalledWith('company-1', undefined);
    });

    it('scopes the export to the resolved period range when a period is given', async () => {
      repo.findByCompanyForTruckExport.mockResolvedValue([]);

      await service.exportByTruckToExcel('company-1', 'weekly', '2026-08-15');

      expect(repo.findByCompanyForTruckExport).toHaveBeenCalledWith('company-1', {
        start: new Date('2026-08-10T00:00:00.000Z'),
        end: new Date('2026-08-17T00:00:00.000Z'),
      });
    });
  });
});
