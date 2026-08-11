import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { TripsRepository } from './trips.repository';
import { Trip, TripStatus, Prisma } from '@prisma/client';

@Injectable()
export class TripsService {
  constructor(private readonly tripsRepository: TripsRepository) {}

  async create(companyId: string, payload: Prisma.TripUncheckedCreateInput): Promise<Trip> {
    return this.tripsRepository.create({ ...payload, companyId });
  }

  async findByCompany(companyId: string, userId?: string, role?: string): Promise<Trip[]> {
    if (role === 'DRIVER' && userId) {
      return this.tripsRepository.findByCompanyAndDriver(companyId, userId);
    }
    return this.tripsRepository.findByCompany(companyId);
  }

  async findById(id: string): Promise<Trip> {
    const trip = await this.tripsRepository.findById(id);
    if (!trip) throw new NotFoundException('Trip not found');
    return trip;
  }

  async update(
    id: string,
    companyId: string,
    data: { origin?: string; destination?: string; scheduledAt?: string; truckId?: string; driverId?: string },
  ) {
    const trip = await this.findById(id);
    if (trip.companyId !== companyId) throw new ForbiddenException();

    return this.tripsRepository.update(id, data);
  }

  async updateStatus(id: string, user: { userId: string; role: string; companyId: string }, status: TripStatus) {
    const trip = await this.findById(id);
    if (trip.companyId !== user.companyId) throw new ForbiddenException();

    if (user.role === 'DRIVER') {
      if (!trip.driverId || trip.driverId !== user.userId) throw new ForbiddenException('Driver not assigned to this trip');
    }

    // Validate state transition
    if (status === 'IN_TRANSIT' && trip.status !== 'ASSIGNED') {
      throw new BadRequestException('Trip must be ASSIGNED before starting');
    }
    if ((status === 'DELIVERED' || status === 'FAILED') && trip.status !== 'IN_TRANSIT') {
      throw new BadRequestException('Trip must be IN_TRANSIT before completing');
    }
    if (trip.status === status) {
      throw new BadRequestException(`Trip is already ${status}`);
    }

    return this.tripsRepository.updateStatus(id, status);
  }

  async setFinanciallyClosed(id: string, companyId: string, financiallyClosed: boolean): Promise<Trip> {
    const trip = await this.findById(id);
    if (trip.companyId !== companyId) throw new ForbiddenException();

    return this.tripsRepository.setFinanciallyClosed(id, financiallyClosed);
  }
}
