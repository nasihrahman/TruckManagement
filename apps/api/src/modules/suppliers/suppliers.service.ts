import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { Prisma, Supplier } from '@prisma/client';
import { SuppliersRepository } from './suppliers.repository';
import { CreateSupplierDto, UpdateSupplierDto } from './dto/supplier.dto';

@Injectable()
export class SuppliersService {
  constructor(private suppliersRepository: SuppliersRepository) {}

  async create(companyId: string, dto: CreateSupplierDto): Promise<Supplier> {
    try {
      return await this.suppliersRepository.create(companyId, dto.name);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new BadRequestException('A supplier with this name already exists');
      }
      throw error;
    }
  }

  async findAll(companyId: string): Promise<Supplier[]> {
    return this.suppliersRepository.findAll(companyId);
  }

  async findOne(id: string, companyId: string): Promise<Supplier> {
    const supplier = await this.suppliersRepository.findById(id, companyId);
    if (!supplier) {
      throw new NotFoundException(`Supplier with ID ${id} not found`);
    }
    return supplier;
  }

  async update(id: string, companyId: string, dto: UpdateSupplierDto): Promise<Supplier> {
    await this.findOne(id, companyId);
    try {
      return await this.suppliersRepository.update(id, dto.name!);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new BadRequestException('A supplier with this name already exists');
      }
      throw error;
    }
  }
}
