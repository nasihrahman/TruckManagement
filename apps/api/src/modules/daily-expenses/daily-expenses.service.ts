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
      truckId: dto.truckId,
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
      truckId: dto.truckId,
    });
  }

  async remove(id: string, user: RequestUser): Promise<DailyExpense> {
    await this.getOwned(id, user);
    return this.repository.delete(id);
  }

  /// Used by TripsService's per-truck export to match trips against the
  /// lump daily totals a driver actually logs (Fuel/Fine/Other) — drivers
  /// don't split fuel per trip, so this is the real expense signal, not the
  /// per-trip Expense model. Keyed by truckId, 'unassigned' for entries with
  /// no truck; the caller decides whether to render 'unassigned' or drop it.
  async findTotalsByTruckInRange(
    companyId: string,
    range?: { start: Date; end: Date },
  ): Promise<Map<string, { truckPlate: string; fuel: number; fine: number; other: number }>> {
    const entries = await this.repository.findForExport(companyId, undefined, range);
    const totals = new Map<string, { truckPlate: string; fuel: number; fine: number; other: number }>();
    for (const entry of entries) {
      const key = entry.truck?.id ?? 'unassigned';
      const truckPlate = entry.truck?.plate ?? 'Unassigned';
      if (!totals.has(key)) totals.set(key, { truckPlate, fuel: 0, fine: 0, other: 0 });
      const bucket = totals.get(key)!;
      const amount = Number(entry.amount);
      if (entry.category === 'FUEL') bucket.fuel += amount;
      else if (entry.category === 'FINE') bucket.fine += amount;
      else bucket.other += amount;
    }
    return totals;
  }

  /// One sheet per truck (mirrors trips.service.ts's exportByTruckToExcel —
  /// same grouping/sheet-naming approach), since the client wants this
  /// consolidated the same way as the per-truck trips export. Entries with
  /// no truck (logged before this field existed, or a driver with none
  /// assigned) land on an "Unassigned" sheet rather than being dropped.
  async exportToExcel(companyId: string, period?: ReportPeriod, dateStr?: string, driverId?: string): Promise<Buffer> {
    const range = period ? resolvePeriodRange(period, dateStr ? new Date(dateStr) : new Date()) : undefined;
    const entries = await this.repository.findForExport(companyId, driverId, range);

    const groups = new Map<string, { name: string; entries: typeof entries }>();
    for (const entry of entries) {
      const key = entry.truck?.id ?? 'unassigned';
      const name = entry.truck ? entry.truck.plate : 'Unassigned';
      if (!groups.has(key)) groups.set(key, { name, entries: [] });
      groups.get(key)!.entries.push(entry);
    }

    const workbook = new ExcelJS.Workbook();
    const columns = [
      { header: 'Date', key: 'date', width: 14 },
      { header: 'Driver', key: 'driver', width: 22 },
      { header: 'Category', key: 'category', width: 12 },
      { header: 'Amount', key: 'amount', width: 12 },
      { header: 'Reason', key: 'reason', width: 24 },
      { header: 'Notes', key: 'notes', width: 24 },
    ];

    // Added before the per-truck sheets so it lands as the first tab.
    if (groups.size > 1) {
      const summary = workbook.addWorksheet('Summary');
      summary.columns = [
        { header: 'Truck', key: 'truck', width: 22 },
        { header: 'Total', key: 'total', width: 14 },
      ];
      summary.getRow(1).font = { bold: true };
      let grandTotal = 0;
      for (const { name, entries: truckEntries } of groups.values()) {
        const truckTotal = truckEntries.reduce((sum, e) => sum + Number(e.amount), 0);
        grandTotal += truckTotal;
        summary.addRow({ truck: name, total: truckTotal });
      }
      summary.addRow({});
      const grandTotalRow = summary.addRow({ truck: 'Grand Total', total: grandTotal });
      grandTotalRow.font = { bold: true };
    }

    const usedNames = new Set<string>();
    for (const { name, entries: truckEntries } of groups.values()) {
      let sheetName = name.replace(/[*?:/\\[\]]/g, ' ').trim().slice(0, 31) || 'Truck';
      let suffix = 2;
      while (usedNames.has(sheetName)) {
        sheetName = `${sheetName.slice(0, 28)} (${suffix++})`;
      }
      usedNames.add(sheetName);

      const sheet = workbook.addWorksheet(sheetName);
      sheet.columns = columns;
      sheet.getRow(1).font = { bold: true };

      let total = 0;
      for (const entry of truckEntries) {
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
    }

    if (workbook.worksheets.length === 0) {
      const sheet = workbook.addWorksheet('Daily Expenses');
      sheet.columns = columns;
    }

    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }
}
