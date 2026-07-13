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

  async assign(id: string, companyId: string, data: { truckId?: string; driverId?: string }) {
    const trip = await this.findById(id);
    if (trip.companyId !== companyId) throw new ForbiddenException();

    if (data.driverId) {
      const isBusy = await this.tripsRepository.isResourceBusy(data.driverId, 'driver');
      if (isBusy) throw new BadRequestException('This driver is currently on an active trip');
    }

    if (data.truckId) {
      const isBusy = await this.tripsRepository.isResourceBusy(data.truckId, 'truck');
      if (isBusy) throw new BadRequestException('This truck is currently on an active trip');
    }

    return this.tripsRepository.update(id, { truckId: data.truckId, driverId: data.driverId });
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
}
