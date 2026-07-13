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

  async update(id: string, data: Prisma.TripUncheckedUpdateInput): Promise<Trip> {
    return this.prisma.trip.update({ where: { id }, data });
  }

  async isResourceBusy(resourceId: string, type: 'driver' | 'truck'): Promise<boolean> {
    const whereClause = type === 'driver' 
      ? { driverId: resourceId, status: 'IN_TRANSIT' as TripStatus } 
      : { truckId: resourceId, status: 'IN_TRANSIT' as TripStatus };
      
    const count = await this.prisma.trip.count({
      where: whereClause,
    });
    return count > 0;
  }
}
