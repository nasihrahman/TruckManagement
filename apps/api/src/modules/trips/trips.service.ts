import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { TripsRepository } from './trips.repository';
import { Trip, TripStatus, Prisma } from '@prisma/client';
import * as ExcelJS from 'exceljs';

@Injectable()
export class TripsService {
  constructor(private readonly tripsRepository: TripsRepository) {}

  async create(
    user: { userId: string; role: string; companyId: string },
    payload: Prisma.TripUncheckedCreateInput,
  ): Promise<Trip> {
    const driverId = user.role === 'DRIVER' ? user.userId : payload.driverId;
    return this.tripsRepository.create({ ...payload, driverId, companyId: user.companyId });
  }

  async findByCompany(companyId: string, userId?: string, role?: string) {
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
    data: {
      origin?: string;
      destination?: string;
      scheduledAt?: Date;
      truckId?: string;
      driverId?: string;
      materialId?: string;
      supplier?: string;
      qtyCf?: number;
      customerName?: string;
    },
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

  async remove(id: string, user: { userId: string; role: string; companyId: string }): Promise<void> {
    const trip = await this.findById(id);
    if (trip.companyId !== user.companyId) throw new ForbiddenException();

    if (user.role === 'DRIVER') {
      if (!trip.driverId || trip.driverId !== user.userId) {
        throw new ForbiddenException('Driver not assigned to this trip');
      }
      if (trip.status !== 'ASSIGNED') {
        throw new BadRequestException('Only assigned trips can be deleted');
      }
    }

    await this.tripsRepository.remove(id);
  }

  async setFinanciallyClosed(id: string, companyId: string, financiallyClosed: boolean): Promise<Trip> {
    const trip = await this.findById(id);
    if (trip.companyId !== companyId) throw new ForbiddenException();

    return this.tripsRepository.setFinanciallyClosed(id, financiallyClosed);
  }

  async exportToExcel(companyId: string): Promise<Buffer> {
    const trips = await this.tripsRepository.findByCompanyForExport(companyId);

    const groups = new Map<string, { name: string; trips: typeof trips }>();
    for (const trip of trips) {
      const key = trip.driver?.id ?? 'unassigned';
      const name = trip.driver
        ? [trip.driver.firstName, trip.driver.lastName].filter(Boolean).join(' ') || 'Driver'
        : 'Unassigned';
      if (!groups.has(key)) groups.set(key, { name, trips: [] });
      groups.get(key)!.trips.push(trip);
    }

    const workbook = new ExcelJS.Workbook();
    const columns = [
      { header: 'Origin', key: 'origin', width: 20 },
      { header: 'Destination', key: 'destination', width: 20 },
      { header: 'Truck', key: 'truck', width: 20 },
      { header: 'Delivery Date', key: 'scheduledAt', width: 16 },
      { header: 'Status', key: 'status', width: 14 },
      { header: 'Started At', key: 'startedAt', width: 18 },
      { header: 'Delivered / Failed On', key: 'completedAt', width: 18 },
    ];

    const usedNames = new Set<string>();
    for (const { name, trips: driverTrips } of groups.values()) {
      let sheetName = name.replace(/[*?:/\\[\]]/g, ' ').trim().slice(0, 31) || 'Driver';
      let suffix = 2;
      while (usedNames.has(sheetName)) {
        sheetName = `${sheetName.slice(0, 28)} (${suffix++})`;
      }
      usedNames.add(sheetName);

      const sheet = workbook.addWorksheet(sheetName);
      sheet.columns = columns;
      sheet.getRow(1).font = { bold: true };

      for (const trip of driverTrips) {
        sheet.addRow({
          origin: trip.origin,
          destination: trip.destination,
          truck: trip.truck ? [trip.truck.plate, trip.truck.brand].filter(Boolean).join(' · ') : 'Unassigned',
          scheduledAt: trip.scheduledAt ? trip.scheduledAt.toISOString().slice(0, 10) : '',
          status: trip.status,
          startedAt: trip.startedAt ? trip.startedAt.toISOString().slice(0, 16).replace('T', ' ') : '',
          completedAt: trip.completedAt ? trip.completedAt.toISOString().slice(0, 16).replace('T', ' ') : '',
        });
      }
    }

    if (workbook.worksheets.length === 0) {
      const sheet = workbook.addWorksheet('Trips');
      sheet.columns = columns;
    }

    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }

  async exportByTruckToExcel(companyId: string): Promise<Buffer> {
    const trips = await this.tripsRepository.findByCompanyForTruckExport(companyId);

    const groups = new Map<string, { name: string; trips: typeof trips }>();
    for (const trip of trips) {
      const key = trip.truck?.id ?? 'unassigned';
      const name = trip.truck ? trip.truck.plate : 'Unassigned';
      if (!groups.has(key)) groups.set(key, { name, trips: [] });
      groups.get(key)!.trips.push(trip);
    }

    const workbook = new ExcelJS.Workbook();
    const columns = [
      { header: 'Date', key: 'scheduledAt', width: 14 },
      { header: 'Material', key: 'material', width: 16 },
      { header: 'Supplier', key: 'supplier', width: 18 },
      { header: 'Qty (CF)', key: 'qtyCf', width: 12 },
      { header: 'Customer', key: 'customerName', width: 20 },
      { header: 'Origin', key: 'origin', width: 20 },
      { header: 'Destination', key: 'destination', width: 20 },
      { header: 'Driver', key: 'driver', width: 20 },
      { header: 'Status', key: 'status', width: 14 },
      { header: 'Expenses', key: 'expenseTotal', width: 12 },
    ];

    const usedNames = new Set<string>();
    for (const { name, trips: truckTrips } of groups.values()) {
      let sheetName = name.replace(/[*?:/\\[\]]/g, ' ').trim().slice(0, 31) || 'Truck';
      let suffix = 2;
      while (usedNames.has(sheetName)) {
        sheetName = `${sheetName.slice(0, 28)} (${suffix++})`;
      }
      usedNames.add(sheetName);

      const sheet = workbook.addWorksheet(sheetName);
      sheet.columns = columns;
      sheet.getRow(1).font = { bold: true };

      for (const trip of truckTrips) {
        const expenseTotal = trip.expenses.reduce((sum, e) => sum + Number(e.amount), 0);
        sheet.addRow({
          scheduledAt: trip.scheduledAt ? trip.scheduledAt.toISOString().slice(0, 10) : '',
          material: trip.material?.name ?? '',
          supplier: trip.supplier ?? '',
          qtyCf: trip.qtyCf ? Number(trip.qtyCf) : '',
          customerName: trip.customerName ?? '',
          origin: trip.origin,
          destination: trip.destination,
          driver: trip.driver
            ? [trip.driver.firstName, trip.driver.lastName].filter(Boolean).join(' ') || 'Driver'
            : 'Unassigned',
          status: trip.status,
          expenseTotal,
        });
      }
    }

    if (workbook.worksheets.length === 0) {
      const sheet = workbook.addWorksheet('Trips');
      sheet.columns = columns;
    }

    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }
}
