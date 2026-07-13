import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Truck } from '@prisma/client';
import { CreateTruckDto } from './dto/truck.dto';
import { UpdateTruckDto } from './dto/truck.dto';

@Injectable()
export class TrucksRepository {
  constructor(private prisma: PrismaService) {}

  async create(companyId: string, dto: CreateTruckDto): Promise<Truck> {
    return this.prisma.truck.create({
      data: {
        companyId,
        plate: dto.plate,
        vin: dto.vin,
      },
    });
  }

  async findAll(companyId: string): Promise<Truck[]> {
    return this.prisma.truck.findMany({
      where: { companyId },
    });
  }

  async findById(id: string, companyId: string): Promise<Truck | null> {
    return this.prisma.truck.findFirst({
      where: { id, companyId },
    });
  }

  async update(id: string, companyId: string, dto: UpdateTruckDto): Promise<Truck> {
    return this.prisma.truck.update({
      where: { id },
      data: dto,
    });
  }

  async delete(id: string, companyId: string): Promise<Truck> {
    return this.prisma.truck.delete({
      where: { id },
    });
  }
}
