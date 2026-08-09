import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { TripsModule } from '../trips/trips.module';
import { ExpensesRepository } from './expenses.repository';
import { ExpensesService } from './expenses.service';
import { ExpensesController } from './expenses.controller';

@Module({
  imports: [PrismaModule, TripsModule],
  providers: [ExpensesRepository, ExpensesService],
  controllers: [ExpensesController],
})
export class ExpensesModule {}
