import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import * as ExcelJS from 'exceljs';
import { DailyExpensesRepository } from './daily-expenses.repository';
import { CreateDailyExpenseDto } from './dto/create-daily-expense.dto';
import { UpdateDailyExpenseDto } from './dto/update-daily-expense.dto';
import { DailyExpense } from '@prisma/client';
import { ReportPeriod, resolvePeriodRange } from '../reports/period.util';

type RequestUser = { userId: string; role: string; companyId: string };

function driverName(driver: { firstName: string | null; lastName: string | null } | null): string {
  if (!driver) return 'Unknown';
  return [driver.firstName, driver.lastName].filter(Boolean).join(' ') || 'Driver';
}

@Injectable()
export class DailyExpensesService {
  constructor(private readonly repository: DailyExpensesRepository) {}

  async create(user: RequestUser, dto: CreateDailyExpenseDto): Promise<DailyExpense> {
    let driverId: string;
    if (user.role === 'DRIVER') {
      driverId = user.userId;
    } else if (user.role === 'OWNER') {
      if (!dto.driverId) {
        throw new BadRequestException('Pick which driver this expense is for');
      }
      driverId = dto.driverId;
    } else {
      throw new ForbiddenException('Not allowed to log daily expenses');
    }

    return this.repository.create({
      companyId: user.companyId,
      driverId,
      date: new Date(dto.date),
      category: dto.category,
      amount: dto.amount,
      reason: dto.reason,
      notes: dto.notes,
      photoUrl: dto.photoUrl,
    });
  }

  async findByCompany(user: RequestUser, period?: ReportPeriod, dateStr?: string, page?: { limit?: number; offset?: number }) {
    const range = period ? resolvePeriodRange(period, dateStr ? new Date(dateStr) : new Date()) : undefined;
    if (user.role === 'DRIVER') {
      return this.repository.findByCompanyAndDriver(user.companyId, user.userId, range, page);
    }
    return this.repository.findByCompany(user.companyId, range, page);
  }

  private async getOwned(id: string, user: RequestUser): Promise<DailyExpense> {
    const entry = await this.repository.findById(id);
    if (!entry || entry.companyId !== user.companyId) throw new NotFoundException('Daily expense not found');
    if (user.role === 'DRIVER' && entry.driverId !== user.userId) {
      throw new ForbiddenException('Not allowed to access this entry');
    }
    return entry;
  }

  async update(id: string, user: RequestUser, dto: UpdateDailyExpenseDto): Promise<DailyExpense> {
    await this.getOwned(id, user);
    return this.repository.update(id, {
      ...(dto.date ? { date: new Date(dto.date) } : {}),
      category: dto.category,
      amount: dto.amount,
      reason: dto.reason,
      notes: dto.notes,
      photoUrl: dto.photoUrl,
    });
  }

  async remove(id: string, user: RequestUser): Promise<DailyExpense> {
    await this.getOwned(id, user);
    return this.repository.delete(id);
  }

  async exportToExcel(companyId: string, period?: ReportPeriod, dateStr?: string, driverId?: string): Promise<Buffer> {
    const range = period ? resolvePeriodRange(period, dateStr ? new Date(dateStr) : new Date()) : undefined;
    const entries = await this.repository.findForExport(companyId, driverId, range);

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Daily Expenses');
    sheet.columns = [
      { header: 'Date', key: 'date', width: 14 },
      { header: 'Driver', key: 'driver', width: 22 },
      { header: 'Category', key: 'category', width: 12 },
      { header: 'Amount', key: 'amount', width: 12 },
      { header: 'Reason', key: 'reason', width: 24 },
      { header: 'Notes', key: 'notes', width: 24 },
    ];
    sheet.getRow(1).font = { bold: true };

    let total = 0;
    for (const entry of entries) {
      total += Number(entry.amount);
      sheet.addRow({
        date: entry.date.toISOString().slice(0, 10),
        driver: driverName(entry.driver),
        category: entry.category,
        amount: Number(entry.amount),
        reason: entry.reason ?? '',
        notes: entry.notes ?? '',
      });
    }
    sheet.addRow({});
    const totalRow = sheet.addRow({ driver: 'Total', amount: total });
    totalRow.font = { bold: true };

    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }
}
