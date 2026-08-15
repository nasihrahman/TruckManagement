import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { OwnersRepository } from './owners.repository';
import { OwnersService } from './owners.service';
import { OwnersController } from './owners.controller';

@Module({
  imports: [PrismaModule],
  providers: [OwnersRepository, OwnersService],
  controllers: [OwnersController],
})
export class OwnersModule {}
