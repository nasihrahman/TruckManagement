import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { TripsRepository } from './trips.repository';
import { TripsService } from './trips.service';
import { TripsController } from './trips.controller';
import { DailyExpensesModule } from '../daily-expenses/daily-expenses.module';

@Module({
  imports: [PrismaModule, DailyExpensesModule],
  providers: [TripsRepository, TripsService],
  controllers: [TripsController],
  exports: [TripsRepository],
})
export class TripsModule {}
