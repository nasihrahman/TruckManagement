import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { User, DriverProfile } from '@prisma/client';

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
  }): Promise<User & { driverProfile: DriverProfile | null }> {
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
        driverProfile: {
          create: {
            licenseNumber: input.licenseNumber,
          },
        },
      },
      include: { driverProfile: true },
    });
  }

  async findById(id: string): Promise<(User & { driverProfile: DriverProfile | null }) | null> {
    return this.prisma.user.findUnique({
      where: { id },
      include: { driverProfile: true },
    });
  }

  async findByCompany(companyId: string): Promise<(User & { driverProfile: DriverProfile | null })[]> {
    return this.prisma.user.findMany({
      where: { companyId, role: 'DRIVER' },
      include: { driverProfile: true },
    });
  }

  async deactivateDriver(id: string): Promise<User> {
    return this.prisma.user.update({
      where: { id },
      data: { isActive: false },
    });
  }

  async reactivateDriver(id: string): Promise<User> {
    return this.prisma.user.update({
      where: { id },
      data: { isActive: true },
    });
  }
}
