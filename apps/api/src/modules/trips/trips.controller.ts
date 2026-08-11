import { Body, Controller, Get, Param, Patch, Post, Request, UseGuards, NotFoundException } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { TripsService } from './trips.service';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';
import { UpdateStatusDto } from './dto/update-status.dto';

@Controller('trips')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TripsController {
  constructor(private readonly tripsService: TripsService) {}

  @Post()
  @Roles(Role.OWNER)
  async create(@Request() req: any, @Body() body: CreateTripDto) {
    const companyId = req.user.companyId;
    return this.tripsService.create(companyId, body as any);
  }

  @Get()
  async list(@Request() req: any) {
    const companyId = req.user.companyId;
    return this.tripsService.findByCompany(companyId, req.user.userId, req.user.role);
  }

  @Get(':id')
  async get(@Request() req: any, @Param('id') id: string) {
    const trip = await this.tripsService.findById(id);
    if (trip.companyId !== req.user.companyId) {
      throw new NotFoundException('Trip not found');
    }
    return trip;
  }

  @Patch(':id')
  @Roles(Role.OWNER)
  async update(@Request() req: any, @Param('id') id: string, @Body() body: UpdateTripDto) {
    return this.tripsService.update(id, req.user.companyId, body);
  }

  @Patch(':id/status')
  async updateStatus(@Request() req: any, @Param('id') id: string, @Body() body: UpdateStatusDto) {
    return this.tripsService.updateStatus(id, req.user, body.status);
  }

  @Patch(':id/financially-close')
  @Roles(Role.OWNER)
  async financiallyClose(@Request() req: any, @Param('id') id: string) {
    return this.tripsService.setFinanciallyClosed(id, req.user.companyId, true);
  }
}
