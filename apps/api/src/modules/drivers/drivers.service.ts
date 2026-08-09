import { Injectable, ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { DriversRepository, SafeDriver } from './drivers.repository';
import { CreateDriverDto } from './dto/create-driver.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class DriversService {
  constructor(private driversRepository: DriversRepository) {}

  async createDriver(companyId: string, dto: CreateDriverDto): Promise<{ user: SafeDriver; tempPassword: string }> {
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
