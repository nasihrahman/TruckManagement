import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Trip, TripStatus, Prisma } from '@prisma/client';

@Injectable()
export class TripsRepository {
  constructor(private prisma: PrismaService) {}

  async create(data: Prisma.TripUncheckedCreateInput): Promise<Trip> {
    return this.prisma.trip.create({ data });
  }

  async findById(id: string): Promise<Trip | null> {
    return this.prisma.trip.findUnique({ where: { id } });
  }

  async findByCompany(companyId: string) {
    return this.prisma.trip.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      include: { expenses: { select: { amount: true, category: true, createdAt: true } } },
    });
  }

  async updateStatus(id: string, status: TripStatus): Promise<Trip> {
    const data: Prisma.TripUpdateInput = { status };
    if (status === 'IN_TRANSIT') {
      data.startedAt = new Date();
    } else if (status === 'DELIVERED' || status === 'FAILED') {
      data.completedAt = new Date();
    }
    return this.prisma.trip.update({ where: { id }, data });
  }

  async setFinanciallyClosed(id: string, financiallyClosed: boolean): Promise<Trip> {
    return this.prisma.trip.update({ where: { id }, data: { financiallyClosed } });
  }

  async update(id: string, data: Prisma.TripUncheckedUpdateInput): Promise<Trip> {
    return this.prisma.trip.update({ where: { id }, data });
  }

  async findByCompanyAndDriver(companyId: string, driverId: string) {
    return this.prisma.trip.findMany({
      where: {
        companyId,
        driverId,
      },
      orderBy: { createdAt: 'desc' },
      include: { expenses: { select: { amount: true, category: true, createdAt: true } } },
    });
  }

  async findActiveTripForDriver(driverId: string): Promise<Trip | null> {
    return this.prisma.trip.findFirst({ where: { driverId, status: 'IN_TRANSIT' } });
  }

  async remove(id: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.expense.deleteMany({ where: { tripId: id } }),
      this.prisma.fuelReceipt.updateMany({ where: { tripId: id }, data: { tripId: null } }),
      this.prisma.issue.updateMany({ where: { tripId: id }, data: { tripId: null } }),
      this.prisma.locationPing.updateMany({ where: { tripId: id }, data: { tripId: null } }),
      this.prisma.trip.delete({ where: { id } }),
    ]);
  }

  async findByCompanyForExport(companyId: string) {
    return this.prisma.trip.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      include: {
        driver: { select: { id: true, firstName: true, lastName: true } },
        truck: { select: { plate: true, brand: true } },
      },
    });
  }

  async findByCompanyForTruckExport(companyId: string) {
    return this.prisma.trip.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' },
      include: {
        driver: { select: { id: true, firstName: true, lastName: true } },
        truck: { select: { id: true, plate: true, brand: true } },
        material: { select: { name: true } },
        supplier: { select: { name: true } },
        expenses: { select: { amount: true } },
      },
    });
  }
}
