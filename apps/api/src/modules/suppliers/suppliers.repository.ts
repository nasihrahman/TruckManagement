import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Supplier } from '@prisma/client';

@Injectable()
export class SuppliersRepository {
  constructor(private prisma: PrismaService) {}

  async create(companyId: string, name: string): Promise<Supplier> {
    const count = await this.prisma.supplier.count({ where: { companyId } });
    return this.prisma.supplier.create({
      data: { companyId, name, sortOrder: count },
    });
  }

  async findAll(companyId: string): Promise<Supplier[]> {
    return this.prisma.supplier.findMany({
      where: { companyId },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  async reorder(companyId: string, ids: string[]): Promise<void> {
    await this.prisma.$transaction(
      ids.map((id, index) =>
        this.prisma.supplier.updateMany({
          where: { id, companyId },
          data: { sortOrder: index },
        }),
      ),
    );
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
