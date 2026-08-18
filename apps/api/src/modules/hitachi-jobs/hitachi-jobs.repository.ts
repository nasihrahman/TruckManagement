import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { HitachiJob, Prisma } from '@prisma/client';

const includeRelations = {
  driver: { select: { id: true, firstName: true, lastName: true } },
  truck: { select: { id: true, plate: true, brand: true } },
};

@Injectable()
export class HitachiJobsRepository {
  constructor(private prisma: PrismaService) {}

  async create(data: Prisma.HitachiJobUncheckedCreateInput): Promise<HitachiJob> {
    return this.prisma.hitachiJob.create({ data, include: includeRelations });
  }

  async findById(id: string) {
    return this.prisma.hitachiJob.findUnique({ where: { id }, include: includeRelations });
  }

  async findByCompany(companyId: string) {
    return this.prisma.hitachiJob.findMany({
      where: { companyId },
      orderBy: { date: 'desc' },
      include: includeRelations,
    });
  }

  async findByCompanyAndDriver(companyId: string, driverId: string) {
    return this.prisma.hitachiJob.findMany({
      where: { companyId, driverId },
      orderBy: { date: 'desc' },
      include: includeRelations,
    });
  }

  async findForExport(companyId: string, driverId?: string, range?: { start: Date; end: Date }) {
    return this.prisma.hitachiJob.findMany({
      where: {
        companyId,
        ...(driverId ? { driverId } : {}),
        ...(range ? { date: { gte: range.start, lt: range.end } } : {}),
      },
      orderBy: { date: 'asc' },
      include: includeRelations,
    });
  }

  async update(id: string, data: Prisma.HitachiJobUncheckedUpdateInput): Promise<HitachiJob> {
    return this.prisma.hitachiJob.update({ where: { id }, data, include: includeRelations });
  }

  async delete(id: string): Promise<HitachiJob> {
    return this.prisma.hitachiJob.delete({ where: { id } });
  }
}
