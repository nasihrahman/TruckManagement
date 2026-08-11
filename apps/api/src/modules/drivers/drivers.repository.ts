import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

const SAFE_DRIVER_SELECT = {
  id: true,
  companyId: true,
  email: true,
  phone: true,
  role: true,
  firstName: true,
  lastName: true,
  isActive: true,
  mustChangePassword: true,
  createdAt: true,
  defaultTruckId: true,
  defaultTruck: {
    select: { id: true, plate: true, brand: true },
  },
  driverProfile: {
    select: { id: true, licenseNumber: true, updatedAt: true },
  },
} as const;

export type SafeDriver = {
  id: string;
  companyId: string;
  email: string | null;
  phone: string;
  role: 'OWNER' | 'DRIVER';
  firstName: string | null;
  lastName: string | null;
  isActive: boolean;
  mustChangePassword: boolean;
  createdAt: Date;
  defaultTruckId: string | null;
  defaultTruck: { id: string; plate: string; brand: string | null } | null;
  driverProfile: { id: string; licenseNumber: string | null; updatedAt: Date } | null;
};

@Injectable()
export class DriversRepository {
  constructor(private prisma: PrismaService) {}

  async createDriver(input: {
    companyId: string;
    name: string;
    phone: string;
    email?: string;
    licenseNumber?: string;
    hashedPassword: string;
    defaultTruckId?: string;
  }): Promise<SafeDriver> {
    return this.prisma.user.create({
      data: {
        companyId: input.companyId,
        email: input.email,
        phone: input.phone,
        password: input.hashedPassword,
        role: 'DRIVER',
        firstName: input.name,
        mustChangePassword: true,
        isActive: true,
        defaultTruckId: input.defaultTruckId,
        driverProfile: {
          create: {
            licenseNumber: input.licenseNumber,
          },
        },
      },
      select: SAFE_DRIVER_SELECT,
    });
  }

  async updateDriver(
    id: string,
    input: {
      name?: string;
      phone?: string;
      email?: string;
      licenseNumber?: string;
      defaultTruckId?: string;
    },
  ): Promise<SafeDriver> {
    return this.prisma.user.update({
      where: { id },
      data: {
        firstName: input.name,
        phone: input.phone,
        email: input.email,
        defaultTruckId: input.defaultTruckId,
        driverProfile: input.licenseNumber !== undefined
          ? {
              upsert: {
                create: { licenseNumber: input.licenseNumber },
                update: { licenseNumber: input.licenseNumber },
              },
            }
          : undefined,
      },
      select: SAFE_DRIVER_SELECT,
    });
  }

  async findById(id: string): Promise<SafeDriver | null> {
    return this.prisma.user.findUnique({
      where: { id },
      select: SAFE_DRIVER_SELECT,
    });
  }

  async findByCompany(companyId: string): Promise<SafeDriver[]> {
    return this.prisma.user.findMany({
      where: { companyId, role: 'DRIVER' },
      select: SAFE_DRIVER_SELECT,
    });
  }

  async deactivateDriver(id: string): Promise<SafeDriver> {
    return this.prisma.user.update({
      where: { id },
      data: { isActive: false },
      select: SAFE_DRIVER_SELECT,
    });
  }

  async reactivateDriver(id: string): Promise<SafeDriver> {
    return this.prisma.user.update({
      where: { id },
      data: { isActive: true },
      select: SAFE_DRIVER_SELECT,
    });
  }

  async getActiveShift(userId: string): Promise<any | null> {
    return this.prisma.driverShift.findFirst({
      where: {
        driverId: userId,
        endedAt: null,
      },
    });
  }

  async createShift(userId: string, companyId: string): Promise<void> {
    await this.prisma.driverShift.create({
      data: {
        driverId: userId,
        companyId,
      },
    });
  }

  async endShift(shiftId: string): Promise<void> {
    await this.prisma.driverShift.update({
      where: { id: shiftId },
      data: { endedAt: new Date() },
    });
  }
}
