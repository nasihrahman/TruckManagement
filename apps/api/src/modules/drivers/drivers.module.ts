import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { TrucksModule } from '../trucks/trucks.module';
import { TripsModule } from '../trips/trips.module';
import { DriversRepository } from './drivers.repository';
import { DriversService } from './drivers.service';
import { DriversController } from './drivers.controller';

@Module({
  imports: [PrismaModule, TrucksModule, TripsModule],
  providers: [DriversRepository, DriversService],
  controllers: [DriversController],
})
export class DriversModule {}
