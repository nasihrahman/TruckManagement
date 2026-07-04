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
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [TripsService, { provide: TripsRepository, useValue: repo }],
    }).compile();

    service = module.get<TripsService>(TripsService);
  });

  it('creates a trip', async () => {
    repo.create.mockResolvedValue({ id: 't1', origin: 'A', destination: 'B' });
    const res = await service.create('company-1', { origin: 'A', destination: 'B' } as any);
    expect(repo.create).toHaveBeenCalled();
    expect(res).toHaveProperty('id', 't1');
  });
});
