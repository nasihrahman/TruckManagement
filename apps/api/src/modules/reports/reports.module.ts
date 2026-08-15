import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { ReportsRepository } from './reports.repository';
import { ReportsService } from './reports.service';
import { ReportsController } from './reports.controller';

@Module({
  imports: [PrismaModule],
  providers: [ReportsRepository, ReportsService],
  controllers: [ReportsController],
})
export class ReportsModule {}
