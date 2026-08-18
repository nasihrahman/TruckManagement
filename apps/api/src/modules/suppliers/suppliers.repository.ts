import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Supplier } from '@prisma/client';

@Injectable()
export class SuppliersRepository {
  constructor(private prisma: PrismaService) {}

  async create(companyId: string, name: string): Promise<Supplier> {
    return this.prisma.supplier.create({
      data: { companyId, name },
    });
  }

  async findAll(companyId: string): Promise<Supplier[]> {
    return this.prisma.supplier.findMany({
      where: { companyId },
      orderBy: { name: 'asc' },
    });
  }

  async findById(id: string, companyId: string): Promise<Supplier | null> {
    return this.prisma.supplier.findFirst({
      where: { id, companyId },
    });
  }

  async update(id: string, name: string): Promise<Supplier> {
    return this.prisma.supplier.update({
      where: { id },
      data: { name },
    });
  }

  async delete(id: string): Promise<Supplier> {
    return this.prisma.supplier.delete({
      where: { id },
    });
  }
}
