import { Body, Controller, Get, Param, Patch, Post, Request, UseGuards, NotFoundException } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { TripsService } from './trips.service';
import { CreateTripDto } from './dto/create-trip.dto';
import { AssignTripDto } from './dto/assign-trip.dto';
import { UpdateStatusDto } from './dto/update-status.dto';

@Controller('trips')
@UseGuards(JwtAuthGuard)
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

  @Patch(':id/assign')
  @Roles(Role.OWNER)
  async assign(@Request() req: any, @Param('id') id: string, @Body() body: AssignTripDto) {
    return this.tripsService.assign(id, req.user.companyId, body as any);
  }

  @Patch(':id/status')
  async updateStatus(@Request() req: any, @Param('id') id: string, @Body() body: UpdateStatusDto) {
    return this.tripsService.updateStatus(id, req.user, body.status);
  }
}
