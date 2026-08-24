import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Request, Res, UseGuards, NotFoundException } from '@nestjs/common';
import { Response } from 'express';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { TripsService } from './trips.service';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';
import { UpdateStatusDto } from './dto/update-status.dto';
import { TruckExportQueryDto } from './dto/truck-export-query.dto';
import { ListTripsQueryDto } from './dto/list-trips-query.dto';

@Controller('trips')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TripsController {
  constructor(private readonly tripsService: TripsService) {}

  @Post()
  @Roles(Role.OWNER, Role.DRIVER)
  async create(@Request() req: any, @Body() body: CreateTripDto) {
    return this.tripsService.create(req.user, body as any);
  }

  @Get()
  async list(@Request() req: any, @Query() query: ListTripsQueryDto) {
    const companyId = req.user.companyId;
    return this.tripsService.findByCompany(companyId, req.user.userId, req.user.role, {
      limit: query.limit,
      offset: query.offset,
    });
  }

  @Get('customer-names')
  @Roles(Role.OWNER, Role.DRIVER)
  async customerNames(@Request() req: any) {
    return this.tripsService.findDistinctCustomerNames(req.user.companyId);
  }

  @Get('export.xlsx')
  @Roles(Role.OWNER)
  async exportXlsx(@Request() req: any, @Res() res: Response) {
    const buffer = await this.tripsService.exportToExcel(req.user.companyId);
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': 'attachment; filename="trips-export.xlsx"',
    });
    res.send(buffer);
  }

  @Get('export-by-truck.xlsx')
  @Roles(Role.OWNER)
  async exportByTruckXlsx(@Request() req: any, @Query() query: TruckExportQueryDto, @Res() res: Response) {
    const buffer = await this.tripsService.exportByTruckToExcel(req.user.companyId, query.period, query.date);
    const suffix = query.period ? `-${query.period}` : '';
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="trips-by-truck-export${suffix}.xlsx"`,
    });
    res.send(buffer);
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

  @Delete(':id')
  async remove(@Request() req: any, @Param('id') id: string) {
    await this.tripsService.remove(id, req.user);
    return { success: true };
  }
}
