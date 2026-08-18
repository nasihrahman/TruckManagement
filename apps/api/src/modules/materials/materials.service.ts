import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { Prisma, Material } from '@prisma/client';
import { MaterialsRepository } from './materials.repository';
import { CreateMaterialDto, UpdateMaterialDto } from './dto/material.dto';

@Injectable()
export class MaterialsService {
  constructor(private materialsRepository: MaterialsRepository) {}

  async create(companyId: string, dto: CreateMaterialDto): Promise<Material> {
    try {
      return await this.materialsRepository.create(companyId, dto.name);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new BadRequestException('A material with this name already exists');
      }
      throw error;
    }
  }

  async findAll(companyId: string): Promise<Material[]> {
    return this.materialsRepository.findAll(companyId);
  }

  async findOne(id: string, companyId: string): Promise<Material> {
    const material = await this.materialsRepository.findById(id, companyId);
    if (!material) {
      throw new NotFoundException(`Material with ID ${id} not found`);
    }
    return material;
  }

  async update(id: string, companyId: string, dto: UpdateMaterialDto): Promise<Material> {
    await this.findOne(id, companyId);
    try {
      return await this.materialsRepository.update(id, dto.name!);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new BadRequestException('A material with this name already exists');
      }
      throw error;
    }
  }

  async remove(id: string, companyId: string): Promise<Material> {
    const material = await this.findOne(id, companyId);
    return this.materialsRepository.delete(material.id);
  }
}
