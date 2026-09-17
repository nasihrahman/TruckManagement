import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { DailyExpense, Prisma } from '@prisma/client';

const DRIVER_SELECT = { id: true, firstName: true, lastName: true };
const TRUCK_SELECT = { id: true, plate: true, brand: true };

type Page = { limit?: number; offset?: number };
type Range = { start: Date; end: Date };

@Injectable()
export class DailyExpensesRepository {
  constructor(private prisma: PrismaService) {}

  async create(data: Prisma.DailyExpenseUncheckedCreateInput): Promise<DailyExpense> {
    return this.prisma.dailyExpense.create({
      data,
      include: { driver: { select: DRIVER_SELECT }, truck: { select: TRUCK_SELECT } },
    });
  }

  async findById(id: string): Promise<DailyExpense | null> {
    return this.prisma.dailyExpense.findUnique({ where: { id } });
  }

  async findByCompany(companyId: string, range?: Range, page?: Page) {
    return this.prisma.dailyExpense.findMany({
      where: { companyId, ...(range ? { date: { gte: range.start, lt: range.end } } : {}) },
      orderBy: { date: 'desc' },
      ...(page?.limit !== undefined ? { take: page.limit } : {}),
      ...(page?.offset ? { skip: page.offset } : {}),
      include: { driver: { select: DRIVER_SELECT }, truck: { select: TRUCK_SELECT } },
    });
  }

  async findByCompanyAndDriver(companyId: string, driverId: string, range?: Range, page?: Page) {
    return this.prisma.dailyExpense.findMany({
      where: { companyId, driverId, ...(range ? { date: { gte: range.start, lt: range.end } } : {}) },
      orderBy: { date: 'desc' },
      ...(page?.limit !== undefined ? { take: page.limit } : {}),
      ...(page?.offset ? { skip: page.offset } : {}),
      include: { driver: { select: DRIVER_SELECT }, truck: { select: TRUCK_SELECT } },
    });
  }

  async update(id: string, data: Prisma.DailyExpenseUncheckedUpdateInput): Promise<DailyExpense> {
    return this.prisma.dailyExpense.update({ where: { id }, data });
  }

  async delete(id: string): Promise<DailyExpense> {
    return this.prisma.dailyExpense.delete({ where: { id } });
  }

  async findForExport(companyId: string, driverId?: string, range?: Range) {
    return this.prisma.dailyExpense.findMany({
      where: {
        companyId,
        ...(driverId ? { driverId } : {}),
        ...(range ? { date: { gte: range.start, lt: range.end } } : {}),
      },
      orderBy: [{ date: 'asc' }, { driverId: 'asc' }],
      include: { driver: { select: DRIVER_SELECT }, truck: { select: TRUCK_SELECT } },
    });
  }
}
