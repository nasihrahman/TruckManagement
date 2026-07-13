import { Module } from '@nestjs/common';
import { TrucksService } from './trucks.service';
import { TrucksController } from './trucks.controller';
import { TrucksRepository } from './trucks.repository';
import { PrismaService } from '../../prisma/prisma.service';

@Module({
  controllers: [TrucksController],
  providers: [TrucksService, TrucksRepository, PrismaService],
  exports: [TrucksService],
})
export class TrucksModule {}
