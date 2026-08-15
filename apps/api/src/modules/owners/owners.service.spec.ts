import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { OwnersService } from './owners.service';
import { OwnersRepository } from './owners.repository';
import * as bcrypt from 'bcrypt';

jest.mock('bcrypt');

describe('OwnersService', () => {
  let service: OwnersService;

  const mockRepository = {
    createOwner: jest.fn(),
    findByCompany: jest.fn(),
  };

  const mockOwner = {
    id: 'owner-2',
    companyId: 'company-1',
    phone: '+1234567890',
    email: 'owner2@test.com',
    firstName: 'Jane',
    lastName: null,
    role: 'OWNER',
    isActive: true,
    mustChangePassword: true,
    createdAt: new Date(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [OwnersService, { provide: OwnersRepository, useValue: mockRepository }],
    }).compile();

    service = module.get<OwnersService>(OwnersService);
  });

  describe('createOwner', () => {
    it('creates an owner with a provided initialPassword', async () => {
      (bcrypt.hash as jest.Mock).mockResolvedValue('hashedpassword');
      mockRepository.createOwner.mockResolvedValue(mockOwner);

      const result = await service.createOwner('company-1', {
        name: 'Jane',
        phone: '+1234567890',
        email: 'owner2@test.com',
        initialPassword: 'tempPassword123',
      });

      expect(bcrypt.hash).toHaveBeenCalledWith('tempPassword123', 10);
      expect(mockRepository.createOwner).toHaveBeenCalledWith({
        companyId: 'company-1',
        name: 'Jane',
        phone: '+1234567890',
        email: 'owner2@test.com',
        hashedPassword: 'hashedpassword',
      });
      expect(result).toEqual({ user: mockOwner, tempPassword: 'tempPassword123' });
    });

    it('falls back to phone as the temp password when none is provided', async () => {
      (bcrypt.hash as jest.Mock).mockResolvedValue('hashedphonepassword');
      mockRepository.createOwner.mockResolvedValue(mockOwner);

      const result = await service.createOwner('company-1', { name: 'Jane', phone: '+9876543210' });

      expect(bcrypt.hash).toHaveBeenCalledWith('+9876543210', 10);
      expect(result.tempPassword).toBe('+9876543210');
    });

    it('translates a duplicate phone into a BadRequestException', async () => {
      (bcrypt.hash as jest.Mock).mockResolvedValue('hashedpassword');
      const error = new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
        code: 'P2002',
        clientVersion: '5.0.0',
        meta: { target: ['phone'] },
      });
      mockRepository.createOwner.mockRejectedValue(error);

      await expect(
        service.createOwner('company-1', { name: 'Jane', phone: '+1234567890' }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('getOwners', () => {
    it('lists owners for the company', async () => {
      mockRepository.findByCompany.mockResolvedValue([mockOwner]);

      const result = await service.getOwners('company-1');

      expect(mockRepository.findByCompany).toHaveBeenCalledWith('company-1');
      expect(result).toEqual([mockOwner]);
    });
  });
});
