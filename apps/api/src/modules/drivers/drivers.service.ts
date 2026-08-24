import { Injectable, ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';
import { DriversRepository, SafeDriver } from './drivers.repository';
import { CreateDriverDto } from './dto/create-driver.dto';
import { UpdateDriverDto } from './dto/update-driver.dto';
import { LocationPingDto } from './dto/location-ping.dto';
import { TrucksService } from '../trucks/trucks.service';
import { TripsRepository } from '../trips/trips.repository';
import { Prisma } from '@prisma/client';

function generateTempPassword(): string {
  return randomBytes(6).toString('base64url');
}

@Injectable()
export class DriversService {
  constructor(
    private driversRepository: DriversRepository,
    private trucksService: TrucksService,
    private tripsRepository: TripsRepository,
  ) {}

  private async assertTruckBelongsToCompany(truckId: string, companyId: string): Promise<void> {
    await this.trucksService.findOne(truckId, companyId);
  }

  async createDriver(companyId: string, dto: CreateDriverDto): Promise<{ user: SafeDriver; tempPassword: string }> {
    if (dto.defaultTruckId) {
      await this.assertTruckBelongsToCompany(dto.defaultTruckId, companyId);
    }

    // Use provided password or phone as temp password
    const tempPassword = dto.initialPassword || dto.phone;
    const hashedPassword = await bcrypt.hash(tempPassword, 10);

    try {
      const user = await this.driversRepository.createDriver({
        companyId,
        name: dto.name,
        phone: dto.phone,
        email: dto.email,
        licenseNumber: dto.licenseNumber,
        hashedPassword,
        defaultTruckId: dto.defaultTruckId,
      });

      return { user, tempPassword };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2002') {
          const target = (error.meta?.target as string[]) || [];
          if (target.includes('phone')) {
            throw new BadRequestException('A driver with this phone number already exists');
          }
          if (target.includes('email')) {
            throw new BadRequestException('A driver with this email address already exists');
          }
        }
      }
      throw error;
    }
  }

  async updateDriver(id: string, companyId: string, dto: UpdateDriverDto): Promise<SafeDriver> {
    await this.getDriver(id, companyId);

    if (dto.defaultTruckId) {
      await this.assertTruckBelongsToCompany(dto.defaultTruckId, companyId);
    }

    try {
      return await this.driversRepository.updateDriver(id, {
        name: dto.name,
        phone: dto.phone,
        email: dto.email,
        licenseNumber: dto.licenseNumber,
        defaultTruckId: dto.defaultTruckId,
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2002') {
          const target = (error.meta?.target as string[]) || [];
          if (target.includes('phone')) {
            throw new BadRequestException('A driver with this phone number already exists');
          }
          if (target.includes('email')) {
            throw new BadRequestException('A driver with this email address already exists');
          }
        }
      }
      throw error;
    }
  }

  async getDrivers(companyId: string): Promise<SafeDriver[]> {
    return this.driversRepository.findByCompany(companyId);
  }

  async getDriver(id: string, companyId: string): Promise<SafeDriver> {
    const driver = await this.driversRepository.findById(id);
    if (!driver || driver.companyId !== companyId) {
      throw new NotFoundException('Driver not found');
    }
    return driver;
  }

  async deactivateDriver(id: string, companyId: string): Promise<SafeDriver> {
    const driver = await this.getDriver(id, companyId);
    if (!driver.isActive) {
      throw new BadRequestException('Driver is already deactivated');
    }
    return this.driversRepository.deactivateDriver(id);
  }

  async reactivateDriver(id: string, companyId: string): Promise<SafeDriver> {
    const driver = await this.getDriver(id, companyId);
    if (driver.isActive) {
      throw new BadRequestException('Driver is already active');
    }
    return this.driversRepository.reactivateDriver(id);
  }

  async resetPassword(id: string, companyId: string): Promise<{ user: SafeDriver; tempPassword: string }> {
    await this.getDriver(id, companyId);
    const tempPassword = generateTempPassword();
    const hashedPassword = await bcrypt.hash(tempPassword, 10);
    const user = await this.driversRepository.resetPassword(id, hashedPassword);
    return { user, tempPassword };
  }

  async getOwnProfile(userId: string, companyId: string): Promise<SafeDriver & { isOnline: boolean }> {
    const driver = await this.getDriver(userId, companyId);
    const activeShift = await this.driversRepository.getActiveShift(userId);
    return { ...driver, isOnline: !!activeShift };
  }

  async recordLocation(userId: string, companyId: string, dto: LocationPingDto) {
    const activeShift = await this.driversRepository.getActiveShift(userId);
    if (!activeShift) {
      throw new BadRequestException('Driver must be online to send location pings');
    }

    const activeTrip = await this.tripsRepository.findActiveTripForDriver(userId);
    return this.driversRepository.createLocationPing({
      driverId: userId,
      companyId,
      tripId: activeTrip?.id ?? null,
      latitude: dto.latitude,
      longitude: dto.longitude,
    });
  }

  async getOnlineLocations(companyId: string) {
    const shifts = await this.driversRepository.getOnlineShifts(companyId);
    return Promise.all(
      shifts.map(async (shift) => {
        const latestPing = await this.driversRepository.getLatestPing(shift.driverId);
        return {
          driverId: shift.driverId,
          name: [shift.driver.firstName, shift.driver.lastName].filter(Boolean).join(' ') || 'Driver',
          onlineSince: shift.startedAt,
          lastLocation: latestPing
            ? { latitude: latestPing.latitude, longitude: latestPing.longitude, at: latestPing.updatedAt, tripId: latestPing.tripId }
            : null,
        };
      }),
    );
  }

  async goOnline(userId: string, companyId: string): Promise<void> {
    const driver = await this.getDriver(userId, companyId);
    if (!driver.isActive) {
      throw new BadRequestException('Driver is deactivated');
    }

    const activeShift = await this.driversRepository.getActiveShift(userId);
    if (activeShift) {
      throw new BadRequestException('Driver is already online');
    }

    await this.driversRepository.createShift(userId, companyId);
  }

  async goOffline(userId: string, companyId: string): Promise<void> {
    const driver = await this.getDriver(userId, companyId);
    if (!driver.isActive) {
      throw new BadRequestException('Driver is deactivated');
    }

    const activeShift = await this.driversRepository.getActiveShift(userId);
    if (!activeShift) {
      throw new BadRequestException('Driver is already offline');
    }

    await this.driversRepository.endShift(activeShift.id);
  }
}
