import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

const DRIVER_SELECT = { id: true, firstName: true, lastName: true } as const;

@Injectable()
export class ReportsRepository {
  constructor(private prisma: PrismaService) {}

  async findTripsCreatedInRange(companyId: string, start: Date, end: Date) {
    return this.prisma.trip.findMany({
      where: { companyId, createdAt: { gte: start, lt: end } },
      select: { id: true, status: true, driverId: true, driver: { select: DRIVER_SELECT } },
    });
  }

  async findTripsCompletedInRange(companyId: string, start: Date, end: Date) {
    return this.prisma.trip.findMany({
      where: { companyId, completedAt: { gte: start, lt: end } },
      select: { id: true, status: true, driverId: true, driver: { select: DRIVER_SELECT } },
    });
  }

  async findExpensesInRange(companyId: string, start: Date, end: Date) {
    return this.prisma.expense.findMany({
      where: { companyId, createdAt: { gte: start, lt: end } },
      select: {
        id: true,
        amount: true,
        category: true,
        driverId: true,
        driver: { select: DRIVER_SELECT },
      },
    });
  }
}
