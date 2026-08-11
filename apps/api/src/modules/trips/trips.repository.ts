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

  async findByCompany(companyId: string): Promise<Trip[]> {
    return this.prisma.trip.findMany({ where: { companyId } });
  }

  async updateStatus(id: string, status: TripStatus): Promise<Trip> {
    return this.prisma.trip.update({ where: { id }, data: { status } });
  }

  async setFinanciallyClosed(id: string, financiallyClosed: boolean): Promise<Trip> {
    return this.prisma.trip.update({ where: { id }, data: { financiallyClosed } });
  }

  async update(id: string, data: Prisma.TripUncheckedUpdateInput): Promise<Trip> {
    return this.prisma.trip.update({ where: { id }, data });
  }

  async findByCompanyAndDriver(companyId: string, driverId: string): Promise<Trip[]> {
    return this.prisma.trip.findMany({
      where: {
        companyId,
        driverId,
      },
    });
  }
}
