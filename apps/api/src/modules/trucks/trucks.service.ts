import { Injectable, NotFoundException } from '@nestjs/common';
import { TrucksRepository } from './trucks.repository';
import { CreateTruckDto } from './dto/truck.dto';
import { UpdateTruckDto } from './dto/truck.dto';
import { Truck } from '@prisma/client';

@Injectable()
export class TrucksService {
  constructor(private trucksRepository: TrucksRepository) {}

  async create(companyId: string, dto: CreateTruckDto): Promise<Truck> {
    return this.trucksRepository.create(companyId, dto);
  }

  async findAll(companyId: string): Promise<Truck[]> {
    return this.trucksRepository.findAll(companyId);
  }

  async findOne(id: string, companyId: string): Promise<Truck> {
    const truck = await this.trucksRepository.findById(id, companyId);
    if (!truck) {
      throw new NotFoundException(`Truck with ID ${id} not found`);
    }
    return truck;
  }

  async update(id: string, companyId: string, dto: UpdateTruckDto): Promise<Truck> {
    const truck = await this.findOne(id, companyId);
    return this.trucksRepository.update(truck.id, companyId, dto);
  }

  async remove(id: string, companyId: string): Promise<Truck> {
    const truck = await this.findOne(id, companyId);
    return this.trucksRepository.delete(truck.id, companyId);
  }
}
