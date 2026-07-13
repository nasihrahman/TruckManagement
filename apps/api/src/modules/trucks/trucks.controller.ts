import { Body, Controller, Get, Param, Patch, Post, Delete, Request, UseGuards } from '@nestjs/common';
import { TrucksService } from './trucks.service';
import { CreateTruckDto } from './dto/truck.dto';
import { UpdateTruckDto } from './dto/truck.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller('trucks')
@UseGuards(JwtAuthGuard)
@Roles(Role.OWNER)
export class TrucksController {
  constructor(private readonly trucksService: TrucksService) {}

  @Post()
  async create(@Request() req: any, @Body() dto: CreateTruckDto) {
    return this.trucksService.create(req.user.companyId, dto);
  }

  @Get()
  async findAll(@Request() req: any) {
    return this.trucksService.findAll(req.user.companyId);
  }

  @Get(':id')
  async findOne(@Request() req: any, @Param('id') id: string) {
    return this.trucksService.findOne(id, req.user.companyId);
  }

  @Patch(':id')
  async update(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateTruckDto) {
    return this.trucksService.update(id, req.user.companyId, dto);
  }

  @Delete(':id')
  async remove(@Request() req: any, @Param('id') id: string) {
    return this.trucksService.remove(id, req.user.companyId);
  }
}
