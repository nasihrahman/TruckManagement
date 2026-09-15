import { Module } from '@nestjs/common';
import { DailyExpensesService } from './daily-expenses.service';
import { DailyExpensesController } from './daily-expenses.controller';
import { DailyExpensesRepository } from './daily-expenses.repository';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [DailyExpensesController],
  providers: [DailyExpensesService, DailyExpensesRepository],
  exports: [DailyExpensesService],
})
export class DailyExpensesModule {}
