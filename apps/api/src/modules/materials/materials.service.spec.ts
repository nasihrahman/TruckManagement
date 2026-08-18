import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { MaterialsService } from './materials.service';
import { MaterialsRepository } from './materials.repository';

describe('MaterialsService', () => {
  let service: MaterialsService;

  const mockRepository = {
    create: jest.fn(),
    findAll: jest.fn(),
    findById: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };

  const mockMaterial = { id: 'material-1', companyId: 'company-1', name: 'P Sand', createdAt: new Date() };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [MaterialsService, { provide: MaterialsRepository, useValue: mockRepository }],
    }).compile();

    service = module.get<MaterialsService>(MaterialsService);
  });

  describe('create', () => {
    it('creates a material for the company', async () => {
      mockRepository.create.mockResolvedValue(mockMaterial);

      const result = await service.create('company-1', { name: 'P Sand' });

      expect(mockRepository.create).toHaveBeenCalledWith('company-1', 'P Sand');
      expect(result).toEqual(mockMaterial);
    });

    it('translates a duplicate name into a BadRequestException', async () => {
      const error = new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
        code: 'P2002',
        clientVersion: '5.0.0',
        meta: { target: ['companyId', 'name'] },
      });
      mockRepository.create.mockRejectedValue(error);

      await expect(service.create('company-1', { name: 'P Sand' })).rejects.toThrow(BadRequestException);
    });
  });

  describe('findOne', () => {
    it('throws NotFoundException when the material does not belong to the company', async () => {
      mockRepository.findById.mockResolvedValue(null);

      await expect(service.findOne('material-1', 'company-1')).rejects.toThrow(NotFoundException);
    });
  });

  describe('update', () => {
    it('renames an existing material', async () => {
      mockRepository.findById.mockResolvedValue(mockMaterial);
      mockRepository.update.mockResolvedValue({ ...mockMaterial, name: 'M Sand' });

      const result = await service.update('material-1', 'company-1', { name: 'M Sand' });

      expect(mockRepository.update).toHaveBeenCalledWith('material-1', 'M Sand');
      expect(result.name).toBe('M Sand');
    });
  });

  describe('remove', () => {
    it('deletes a material after confirming it belongs to the company', async () => {
      mockRepository.findById.mockResolvedValue(mockMaterial);
      mockRepository.delete.mockResolvedValue(mockMaterial);

      const result = await service.remove('material-1', 'company-1');

      expect(mockRepository.delete).toHaveBeenCalledWith('material-1');
      expect(result).toEqual(mockMaterial);
    });

    it('throws NotFoundException when the material does not belong to the company', async () => {
      mockRepository.findById.mockResolvedValue(null);

      await expect(service.remove('material-1', 'company-1')).rejects.toThrow(NotFoundException);
      expect(mockRepository.delete).not.toHaveBeenCalled();
    });
  });
});
