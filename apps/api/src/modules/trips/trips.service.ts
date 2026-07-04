import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { TripsRepository } from './trips.repository';
import { Trip, TripStatus, Prisma } from '@prisma/client';

@Injectable()
export class TripsService {
  constructor(private readonly tripsRepository: TripsRepository) {}

  async create(companyId: string, payload: Prisma.TripUncheckedCreateInput): Promise<Trip> {
    return this.tripsRepository.create({ ...payload, companyId });
  }

  async findByCompany(companyId: string): Promise<Trip[]> {
    return this.tripsRepository.findByCompany(companyId);
  }

  async findById(id: string): Promise<Trip> {
    const trip = await this.tripsRepository.findById(id);
    if (!trip) throw new NotFoundException('Trip not found');
    return trip;
  }

  async assign(id: string, companyId: string, data: { truckId?: string; driverId?: string }) {
    const trip = await this.findById(id);
    if (trip.companyId !== companyId) throw new ForbiddenException();
    return this.tripsRepository.update(id, { truckId: data.truckId, driverId: data.driverId });
  }

  async updateStatus(id: string, user: { userId: string; role: string; companyId: string }, status: TripStatus) {
    const trip = await this.findById(id);
    if (trip.companyId !== user.companyId) throw new ForbiddenException();

    if (user.role === 'DRIVER') {
      if (!trip.driverId || trip.driverId !== user.userId) throw new ForbiddenException('Driver not assigned to this trip');
    }

    return this.tripsRepository.updateStatus(id, status);
  }
}
