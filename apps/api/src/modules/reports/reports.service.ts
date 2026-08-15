import { Injectable } from '@nestjs/common';
import * as ExcelJS from 'exceljs';
import { ReportsRepository } from './reports.repository';
import { ReportPeriod, resolvePeriodRange } from './period.util';

function driverName(driver: { firstName: string | null; lastName: string | null } | null): string {
  if (!driver) return 'Unassigned';
  return [driver.firstName, driver.lastName].filter(Boolean).join(' ') || 'Driver';
}

interface TripDriverStat {
  driverId: string;
  name: string;
  delivered: number;
  failed: number;
}

interface ExpenseDriverStat {
  driverId: string;
  name: string;
  total: number;
}

export interface OperationsReport {
  period: ReportPeriod;
  rangeStart: string;
  rangeEnd: string;
  trips: {
    createdTotal: number;
    completedTotal: number;
    delivered: number;
    failed: number;
    completionRate: number;
    byDriver: TripDriverStat[];
  };
  expenses: {
    total: number;
    byCategory: Record<string, number>;
    byDriver: ExpenseDriverStat[];
  };
}

@Injectable()
export class ReportsService {
  constructor(private reportsRepository: ReportsRepository) {}

  async getOperationsReport(companyId: string, period: ReportPeriod, dateStr?: string): Promise<OperationsReport> {
    const anchor = dateStr ? new Date(dateStr) : new Date();
    const { start, end } = resolvePeriodRange(period, anchor);

    const [createdTrips, completedTrips, expenses] = await Promise.all([
      this.reportsRepository.findTripsCreatedInRange(companyId, start, end),
      this.reportsRepository.findTripsCompletedInRange(companyId, start, end),
      this.reportsRepository.findExpensesInRange(companyId, start, end),
    ]);

    const tripsByDriver = new Map<string, TripDriverStat>();
    let delivered = 0;
    let failed = 0;
    for (const trip of completedTrips) {
      if (trip.status === 'DELIVERED') delivered++;
      else if (trip.status === 'FAILED') failed++;
      else continue;

      const driverId = trip.driverId ?? 'unassigned';
      const stat = tripsByDriver.get(driverId) ?? {
        driverId,
        name: driverName(trip.driver),
        delivered: 0,
        failed: 0,
      };
      if (trip.status === 'DELIVERED') stat.delivered++;
      else stat.failed++;
      tripsByDriver.set(driverId, stat);
    }
    const completedTotal = delivered + failed;

    const expensesByDriver = new Map<string, ExpenseDriverStat>();
    const byCategory: Record<string, number> = {};
    let expenseTotal = 0;
    for (const expense of expenses) {
      const amount = Number(expense.amount);
      expenseTotal += amount;
      byCategory[expense.category] = (byCategory[expense.category] ?? 0) + amount;

      const driverId = expense.driverId;
      const stat = expensesByDriver.get(driverId) ?? {
        driverId,
        name: driverName(expense.driver),
        total: 0,
      };
      stat.total += amount;
      expensesByDriver.set(driverId, stat);
    }

    return {
      period,
      rangeStart: start.toISOString(),
      rangeEnd: end.toISOString(),
      trips: {
        createdTotal: createdTrips.length,
        completedTotal,
        delivered,
        failed,
        completionRate: completedTotal > 0 ? delivered / completedTotal : 0,
        byDriver: [...tripsByDriver.values()].sort((a, b) => b.delivered + b.failed - (a.delivered + a.failed)),
      },
      expenses: {
        total: expenseTotal,
        byCategory,
        byDriver: [...expensesByDriver.values()].sort((a, b) => b.total - a.total),
      },
    };
  }

  async exportOperationsReport(companyId: string, period: ReportPeriod, dateStr?: string): Promise<Buffer> {
    const report = await this.getOperationsReport(companyId, period, dateStr);
    const workbook = new ExcelJS.Workbook();

    const summary = workbook.addWorksheet('Summary');
    summary.columns = [
      { header: 'Metric', key: 'metric', width: 28 },
      { header: 'Value', key: 'value', width: 20 },
    ];
    summary.getRow(1).font = { bold: true };
    summary.addRows([
      { metric: 'Period', value: report.period },
      { metric: 'Range Start', value: report.rangeStart.slice(0, 10) },
      { metric: 'Range End', value: report.rangeEnd.slice(0, 10) },
      { metric: 'Trips Created', value: report.trips.createdTotal },
      { metric: 'Trips Completed', value: report.trips.completedTotal },
      { metric: 'Delivered', value: report.trips.delivered },
      { metric: 'Failed', value: report.trips.failed },
      { metric: 'Completion Rate', value: `${(report.trips.completionRate * 100).toFixed(1)}%` },
      { metric: 'Total Expenses', value: report.expenses.total },
      { metric: 'Fuel', value: report.expenses.byCategory.FUEL ?? 0 },
      { metric: 'Fines', value: report.expenses.byCategory.FINE ?? 0 },
      { metric: 'Other', value: report.expenses.byCategory.OTHER ?? 0 },
    ]);

    const tripsSheet = workbook.addWorksheet('Trips by Driver');
    tripsSheet.columns = [
      { header: 'Driver', key: 'name', width: 24 },
      { header: 'Delivered', key: 'delivered', width: 14 },
      { header: 'Failed', key: 'failed', width: 14 },
    ];
    tripsSheet.getRow(1).font = { bold: true };
    for (const row of report.trips.byDriver) {
      tripsSheet.addRow(row);
    }

    const expensesSheet = workbook.addWorksheet('Expenses by Driver');
    expensesSheet.columns = [
      { header: 'Driver', key: 'name', width: 24 },
      { header: 'Total', key: 'total', width: 16 },
    ];
    expensesSheet.getRow(1).font = { bold: true };
    for (const row of report.expenses.byDriver) {
      expensesSheet.addRow(row);
    }

    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }
}
