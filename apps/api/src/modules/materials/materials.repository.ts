import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Material } from '@prisma/client';

@Injectable()
export class MaterialsRepository {
  constructor(private prisma: PrismaService) {}

  async create(companyId: string, name: string): Promise<Material> {
    // New entries go to the end of the list, not position 0 (the column's
    // default) — otherwise every newly added material would jump ahead of
    // the company's whole existing, manually-arranged order.
    const count = await this.prisma.material.count({ where: { companyId } });
    return this.prisma.material.create({
      data: { companyId, name, sortOrder: count },
    });
  }

  async findAll(companyId: string): Promise<Material[]> {
    return this.prisma.material.findMany({
      where: { companyId },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  /// Sets sortOrder to each id's index in the given array. Runs as one
  /// transaction so a reorder can't be observed half-applied.
  async reorder(companyId: string, ids: string[]): Promise<void> {
    await this.prisma.$transaction(
      ids.map((id, index) =>
        this.prisma.material.updateMany({
          where: { id, companyId },
          data: { sortOrder: index },
        }),
      ),
    );
  }

  async findById(id: string, companyId: string): Promise<Material | null> {
    return this.prisma.material.findFirst({
      where: { id, companyId },
    });
  }

  async update(id: string, name: string): Promise<Material> {
    return this.prisma.material.update({
      where: { id },
      data: { name },
    });
  }

  async delete(id: string): Promise<Material> {
    return this.prisma.material.delete({
      where: { id },
    });
  }
}
