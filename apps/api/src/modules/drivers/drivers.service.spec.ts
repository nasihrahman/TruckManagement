import { Test, TestingModule } from '@nestjs/testing';
import { DriversService } from './drivers.service';
import { DriversRepository } from './drivers.repository';
import { TrucksService } from '../trucks/trucks.service';
import { TripsRepository } from '../trips/trips.repository';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

jest.mock('bcrypt');

describe('DriversService', () => {
  let service: DriversService;
  let repository: DriversRepository;

  const mockRepository = {
    createDriver: jest.fn(),
    updateDriver: jest.fn(),
    findById: jest.fn(),
    findByCompany: jest.fn(),
    deactivateDriver: jest.fn(),
    reactivateDriver: jest.fn(),
    resetPassword: jest.fn(),
    getActiveShift: jest.fn(),
    createShift: jest.fn(),
    endShift: jest.fn(),
    createLocationPing: jest.fn(),
    getOnlineShifts: jest.fn(),
    getLatestPing: jest.fn(),
  };

  const mockTrucksService = {
    findOne: jest.fn(),
  };

  const mockTripsRepository = {
    findActiveTripForDriver: jest.fn(),
  };

  const mockUser = {
    id: 'driver-1',
    companyId: 'company-1',
    phone: '+1234567890',
    email: 'driver@test.com',
    firstName: 'John',
    lastName: 'Doe',
    role: 'DRIVER',
    password: 'hashedpassword',
    isActive: true,
    mustChangePassword: true,
    currentHashedRefreshToken: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DriversService,
        { provide: DriversRepository, useValue: mockRepository },
        { provide: TrucksService, useValue: mockTrucksService },
        { provide: TripsRepository, useValue: mockTripsRepository },
      ],
    }).compile();

    service = module.get<DriversService>(DriversService);
    repository = module.get<DriversRepository>(DriversRepository);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('createDriver', () => {
    it('should create a driver with provided initialPassword', async () => {
      const createDto = {
        name: 'John Doe',
        phone: '+1234567890',
        email: 'driver@test.com',
        licenseNumber: 'DL123456',
        initialPassword: 'tempPassword123',
      };

      (bcrypt.hash as jest.Mock).mockResolvedValue('hashedpassword');
      mockRepository.createDriver.mockResolvedValue(mockUser);

      const result = await service.createDriver('company-1', createDto);

      expect(bcrypt.hash).toHaveBeenCalledWith('tempPassword123', 10);
      expect(mockRepository.createDriver).toHaveBeenCalledWith({
        companyId: 'company-1',
        name: 'John Doe',
        phone: '+1234567890',
        email: 'driver@test.com',
        licenseNumber: 'DL123456',
        hashedPassword: 'hashedpassword',
      });
      expect(result).toEqual({ user: mockUser, tempPassword: 'tempPassword123' });
    });

    it('should create a driver with phone as default password', async () => {
      const createDto = {
        name: 'Jane Doe',
        phone: '+9876543210',
      };

      (bcrypt.hash as jest.Mock).mockResolvedValue('hashedphonepassword');
      mockRepository.createDriver.mockResolvedValue(mockUser);

      const result = await service.createDriver('company-1', createDto);

      expect(bcrypt.hash).toHaveBeenCalledWith('+9876543210', 10);
      expect(result.tempPassword).toBe('+9876543210');
    });
  });

  describe('getDriver', () => {
    it('should return a driver if found and belongs to company', async () => {
      mockRepository.findById.mockResolvedValue(mockUser);

      const result = await service.getDriver('driver-1', 'company-1');

      expect(result).toEqual(mockUser);
    });

    it('should throw NotFoundException if driver not found', async () => {
      mockRepository.findById.mockResolvedValue(null);

      await expect(service.getDriver('driver-1', 'company-1')).rejects.toThrow(NotFoundException);
    });

    it('should throw NotFoundException if driver belongs to different company', async () => {
      mockRepository.findById.mockResolvedValue(mockUser);

      await expect(service.getDriver('driver-1', 'different-company')).rejects.toThrow(NotFoundException);
    });
  });

  describe('deactivateDriver', () => {
    it('should deactivate an active driver', async () => {
      mockRepository.findById.mockResolvedValue(mockUser);
      mockRepository.deactivateDriver.mockResolvedValue({ ...mockUser, isActive: false });

      const result = await service.deactivateDriver('driver-1', 'company-1');

      expect(result.isActive).toBe(false);
      expect(mockRepository.deactivateDriver).toHaveBeenCalledWith('driver-1');
    });

    it('should throw BadRequestException if driver is already deactivated', async () => {
      mockRepository.findById.mockResolvedValue({ ...mockUser, isActive: false });

      await expect(service.deactivateDriver('driver-1', 'company-1')).rejects.toThrow(BadRequestException);
    });
  });

  describe('reactivateDriver', () => {
    it('should reactivate an inactive driver', async () => {
      mockRepository.findById.mockResolvedValue({ ...mockUser, isActive: false });
      mockRepository.reactivateDriver.mockResolvedValue(mockUser);

      const result = await service.reactivateDriver('driver-1', 'company-1');

      expect(result.isActive).toBe(true);
      expect(mockRepository.reactivateDriver).toHaveBeenCalledWith('driver-1');
    });

    it('should throw BadRequestException if driver is already active', async () => {
      mockRepository.findById.mockResolvedValue(mockUser);

      await expect(service.reactivateDriver('driver-1', 'company-1')).rejects.toThrow(BadRequestException);
    });
  });

  describe('resetPassword', () => {
    it('generates a fresh temp password and hashes it', async () => {
      mockRepository.findById.mockResolvedValue(mockUser);
      (bcrypt.hash as jest.Mock).mockResolvedValue('hashed-new-password');
      mockRepository.resetPassword.mockResolvedValue({ ...mockUser, mustChangePassword: true });

      const result = await service.resetPassword('driver-1', 'company-1');

      expect(result.tempPassword).toEqual(expect.any(String));
      expect(result.tempPassword.length).toBeGreaterThan(0);
      expect(bcrypt.hash).toHaveBeenCalledWith(result.tempPassword, 10);
      expect(mockRepository.resetPassword).toHaveBeenCalledWith('driver-1', 'hashed-new-password');
      expect(result.user.mustChangePassword).toBe(true);
    });

    it('throws NotFoundException if the driver does not belong to the company', async () => {
      mockRepository.findById.mockResolvedValue(mockUser);

      await expect(service.resetPassword('driver-1', 'different-company')).rejects.toThrow(NotFoundException);
      expect(mockRepository.resetPassword).not.toHaveBeenCalled();
    });
  });
});
