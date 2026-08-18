import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { SuppliersService } from './suppliers.service';
import { SuppliersRepository } from './suppliers.repository';

describe('SuppliersService', () => {
  let service: SuppliersService;

  const mockRepository = {
    create: jest.fn(),
    findAll: jest.fn(),
    findById: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };

  const mockSupplier = { id: 'supplier-1', companyId: 'company-1', name: 'ACME Quarry', createdAt: new Date() };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [SuppliersService, { provide: SuppliersRepository, useValue: mockRepository }],
    }).compile();

    service = module.get<SuppliersService>(SuppliersService);
  });

  describe('create', () => {
    it('creates a supplier for the company', async () => {
      mockRepository.create.mockResolvedValue(mockSupplier);

      const result = await service.create('company-1', { name: 'ACME Quarry' });

      expect(mockRepository.create).toHaveBeenCalledWith('company-1', 'ACME Quarry');
      expect(result).toEqual(mockSupplier);
    });

    it('translates a duplicate name into a BadRequestException', async () => {
      const error = new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
        code: 'P2002',
        clientVersion: '5.0.0',
        meta: { target: ['companyId', 'name'] },
      });
      mockRepository.create.mockRejectedValue(error);

      await expect(service.create('company-1', { name: 'ACME Quarry' })).rejects.toThrow(BadRequestException);
    });
  });

  describe('findOne', () => {
    it('throws NotFoundException when the supplier does not belong to the company', async () => {
      mockRepository.findById.mockResolvedValue(null);

      await expect(service.findOne('supplier-1', 'company-1')).rejects.toThrow(NotFoundException);
    });
  });

  describe('update', () => {
    it('renames an existing supplier', async () => {
      mockRepository.findById.mockResolvedValue(mockSupplier);
      mockRepository.update.mockResolvedValue({ ...mockSupplier, name: 'Beta Traders' });

      const result = await service.update('supplier-1', 'company-1', { name: 'Beta Traders' });

      expect(mockRepository.update).toHaveBeenCalledWith('supplier-1', 'Beta Traders');
      expect(result.name).toBe('Beta Traders');
    });
  });

  describe('remove', () => {
    it('deletes a supplier after confirming it belongs to the company', async () => {
      mockRepository.findById.mockResolvedValue(mockSupplier);
      mockRepository.delete.mockResolvedValue(mockSupplier);

      const result = await service.remove('supplier-1', 'company-1');

      expect(mockRepository.delete).toHaveBeenCalledWith('supplier-1');
      expect(result).toEqual(mockSupplier);
    });

    it('throws NotFoundException when the supplier does not belong to the company', async () => {
      mockRepository.findById.mockResolvedValue(null);

      await expect(service.remove('supplier-1', 'company-1')).rejects.toThrow(NotFoundException);
      expect(mockRepository.delete).not.toHaveBeenCalled();
    });
  });
});
