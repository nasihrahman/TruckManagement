import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Material } from '@prisma/client';

@Injectable()
export class MaterialsRepository {
  constructor(private prisma: PrismaService) {}

  async create(companyId: string, name: string): Promise<Material> {
    return this.prisma.material.create({
      data: { companyId, name },
    });
  }

  async findAll(companyId: string): Promise<Material[]> {
    return this.prisma.material.findMany({
      where: { companyId },
      orderBy: { name: 'asc' },
    });
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
