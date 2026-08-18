import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TrucksService } from './trucks.service';
import { TrucksRepository } from './trucks.repository';

describe('TrucksService', () => {
  let service: TrucksService;

  const mockRepository = {
    create: jest.fn(),
    findAll: jest.fn(),
    findById: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };

  const mockTruck = { id: 'truck-1', companyId: 'company-1', plate: 'TRK-1', brand: 'Tata', vin: null, createdAt: new Date() };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [TrucksService, { provide: TrucksRepository, useValue: mockRepository }],
    }).compile();

    service = module.get<TrucksService>(TrucksService);
  });

  describe('remove', () => {
    it('deletes a truck after confirming it belongs to the company', async () => {
      mockRepository.findById.mockResolvedValue(mockTruck);
      mockRepository.delete.mockResolvedValue(mockTruck);

      const result = await service.remove('truck-1', 'company-1');

      expect(mockRepository.delete).toHaveBeenCalledWith('truck-1', 'company-1');
      expect(result).toEqual(mockTruck);
    });

    it('throws NotFoundException when the truck does not belong to the company', async () => {
      mockRepository.findById.mockResolvedValue(null);

      await expect(service.remove('truck-1', 'company-1')).rejects.toThrow(NotFoundException);
      expect(mockRepository.delete).not.toHaveBeenCalled();
    });

    it('translates a maintenance-record foreign key conflict into a friendly error', async () => {
      mockRepository.findById.mockResolvedValue(mockTruck);
      const error = new Prisma.PrismaClientKnownRequestError('Foreign key constraint failed', {
        code: 'P2003',
        clientVersion: '5.0.0',
        meta: { field_name: 'MaintenanceRecord_truckId_fkey' },
      });
      mockRepository.delete.mockRejectedValue(error);

      await expect(service.remove('truck-1', 'company-1')).rejects.toThrow(BadRequestException);
    });
  });
});
