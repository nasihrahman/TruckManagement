import { Module } from '@nestjs/common';
import { HitachiJobsService } from './hitachi-jobs.service';
import { HitachiJobsController } from './hitachi-jobs.controller';
import { HitachiJobsRepository } from './hitachi-jobs.repository';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [HitachiJobsController],
  providers: [HitachiJobsService, HitachiJobsRepository],
  exports: [HitachiJobsService],
})
export class HitachiJobsModule {}
