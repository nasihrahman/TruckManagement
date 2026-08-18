import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { HitachiJob, HitachiPayer } from '@prisma/client';
import * as ExcelJS from 'exceljs';
import { HitachiJobsRepository } from './hitachi-jobs.repository';
import { CreateHitachiJobDto, UpdateHitachiJobDto } from './dto/hitachi-job.dto';
import { ReportPeriod, resolvePeriodRange } from '../reports/period.util';

type RequestUser = { userId: string; role: string; companyId: string };

const PAYER_LABEL: Record<HitachiPayer, string> = { M: 'Muthu', J: 'Jamal' };

function balanceJ(job: {
  paymentReceived: unknown;
  paymentReceivedBy: HitachiPayer | null;
  salaryAdvance: unknown;
  nDieselExpense: unknown;
  nDieselPaidBy: HitachiPayer | null;
  hDieselExpense: unknown;
  hDieselPaidBy: HitachiPayer | null;
  opBata: unknown;
  opBataPaidBy: HitachiPayer | null;
  otherExpenseJ: unknown;
}): number {
  const num = (v: unknown) => (v == null ? 0 : Number(v));
  const ifJ = (amount: unknown, paidBy: HitachiPayer | null) => (paidBy === 'J' ? num(amount) : 0);
  const receivedByJ = job.paymentReceivedBy === 'J' ? num(job.paymentReceived) : 0;
  return (
    receivedByJ +
    num(job.salaryAdvance) -
    ifJ(job.nDieselExpense, job.nDieselPaidBy) -
    ifJ(job.hDieselExpense, job.hDieselPaidBy) -
    ifJ(job.opBata, job.opBataPaidBy) -
    num(job.otherExpenseJ)
  );
}

@Injectable()
export class HitachiJobsService {
  constructor(private readonly hitachiJobsRepository: HitachiJobsRepository) {}

  async create(user: RequestUser, dto: CreateHitachiJobDto): Promise<HitachiJob> {
    // Owner logging their own entry (not on a driver's behalf) simply omits
    // driverId and defaults to self, same as a Driver always does.
    const driverId = user.role === 'DRIVER' ? user.userId : dto.driverId ?? user.userId;

    return this.hitachiJobsRepository.create({
      ...dto,
      driverId,
      companyId: user.companyId,
    });
  }

  async findByCompany(companyId: string, userId?: string, role?: string) {
    if (role === 'DRIVER' && userId) {
      return this.hitachiJobsRepository.findByCompanyAndDriver(companyId, userId);
    }
    return this.hitachiJobsRepository.findByCompany(companyId);
  }

  async findOne(id: string, user: RequestUser): Promise<HitachiJob> {
    const job = await this.hitachiJobsRepository.findById(id);
    if (!job || job.companyId !== user.companyId) {
      throw new NotFoundException('Hitachi job not found');
    }
    if (user.role === 'DRIVER' && job.driverId !== user.userId) {
      throw new ForbiddenException('Not allowed to view this entry');
    }
    return job;
  }

  async update(id: string, user: RequestUser, dto: UpdateHitachiJobDto): Promise<HitachiJob> {
    const job = await this.findOne(id, user);
    if (user.role === 'DRIVER' && job.driverId !== user.userId) {
      throw new ForbiddenException('Not allowed to edit this entry');
    }
    return this.hitachiJobsRepository.update(job.id, dto);
  }

  async remove(id: string, user: RequestUser): Promise<HitachiJob> {
    const job = await this.findOne(id, user);
    if (user.role === 'DRIVER' && job.driverId !== user.userId) {
      throw new ForbiddenException('Not allowed to delete this entry');
    }
    return this.hitachiJobsRepository.delete(job.id);
  }

  async exportToExcel(user: RequestUser, period?: ReportPeriod, dateStr?: string): Promise<Buffer> {
    const range = period ? resolvePeriodRange(period, dateStr ? new Date(dateStr) : new Date()) : undefined;
    const driverId = user.role === 'DRIVER' ? user.userId : undefined;
    const jobs = await this.hitachiJobsRepository.findForExport(user.companyId, driverId, range);

    // One sheet per Hitachi vehicle, same pattern as the per-truck trips
    // export — jobs without a truck picked land in an "Unassigned" sheet.
    const groups = new Map<string, { name: string; jobs: typeof jobs }>();
    for (const job of jobs) {
      const key = job.truck?.id ?? 'unassigned';
      const name = job.truck ? job.truck.plate : 'Unassigned';
      if (!groups.has(key)) groups.set(key, { name, jobs: [] });
      groups.get(key)!.jobs.push(job);
    }

    const workbook = new ExcelJS.Workbook();
    const columns = [
      { header: 'Date', key: 'date', width: 12 },
      { header: 'Driver', key: 'driver', width: 18 },
      { header: 'Customer', key: 'customerName', width: 18 },
      { header: 'Place', key: 'place', width: 16 },
      { header: 'Total Hours', key: 'totalHours', width: 12 },
      { header: 'Payment Received', key: 'paymentReceived', width: 16 },
      { header: 'Received By', key: 'paymentReceivedBy', width: 12 },
      { header: 'N Diesel', key: 'nDiesel', width: 12 },
      { header: 'N Diesel Paid By', key: 'nDieselPaidBy', width: 14 },
      { header: 'H Diesel', key: 'hDiesel', width: 12 },
      { header: 'H Diesel Paid By', key: 'hDieselPaidBy', width: 14 },
      { header: 'OP Bata', key: 'opBata', width: 12 },
      { header: 'OP Bata Paid By', key: 'opBataPaidBy', width: 14 },
      { header: 'Other Exp (Muthu)', key: 'otherExpenseM', width: 16 },
      { header: 'Other Exp (Jamal)', key: 'otherExpenseJ', width: 16 },
      { header: 'Salary Advance', key: 'salaryAdvance', width: 14 },
      { header: 'Bal Amt (Jamal)', key: 'balanceJ', width: 14 },
      { header: 'Photo', key: 'photoUrl', width: 30 },
    ];

    const usedNames = new Set<string>();
    for (const { name, jobs: vehicleJobs } of groups.values()) {
      let sheetName = name.replace(/[*?:/\\[\]]/g, ' ').trim().slice(0, 31) || 'Vehicle';
      let suffix = 2;
      while (usedNames.has(sheetName)) {
        sheetName = `${sheetName.slice(0, 28)} (${suffix++})`;
      }
      usedNames.add(sheetName);

      const sheet = workbook.addWorksheet(sheetName);
      sheet.columns = columns;
      sheet.getRow(1).font = { bold: true };

      for (const job of vehicleJobs) {
        sheet.addRow({
          date: job.date.toISOString().slice(0, 10),
          driver: job.driver
            ? [job.driver.firstName, job.driver.lastName].filter(Boolean).join(' ') || 'Driver'
            : '',
          customerName: job.customerName ?? '',
          place: job.place ?? '',
          totalHours: job.totalHours ? Number(job.totalHours) : '',
          paymentReceived: job.paymentReceived ? Number(job.paymentReceived) : '',
          paymentReceivedBy: job.paymentReceivedBy ? PAYER_LABEL[job.paymentReceivedBy] : '',
          nDiesel: job.nDieselExpense ? Number(job.nDieselExpense) : '',
          nDieselPaidBy: job.nDieselPaidBy ? PAYER_LABEL[job.nDieselPaidBy] : '',
          hDiesel: job.hDieselExpense ? Number(job.hDieselExpense) : '',
          hDieselPaidBy: job.hDieselPaidBy ? PAYER_LABEL[job.hDieselPaidBy] : '',
          opBata: job.opBata ? Number(job.opBata) : '',
          opBataPaidBy: job.opBataPaidBy ? PAYER_LABEL[job.opBataPaidBy] : '',
          otherExpenseM: job.otherExpenseM ? Number(job.otherExpenseM) : '',
          otherExpenseJ: job.otherExpenseJ ? Number(job.otherExpenseJ) : '',
          salaryAdvance: job.salaryAdvance ? Number(job.salaryAdvance) : '',
          balanceJ: balanceJ(job),
          photoUrl: job.photoUrl ?? '',
        });
      }
    }

    if (workbook.worksheets.length === 0) {
      const sheet = workbook.addWorksheet('Hitachi Jobs');
      sheet.columns = columns;
    }

    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
  }
}
