import { Body, Controller, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { DriversService } from './drivers.service';
import { CreateDriverDto } from './dto/create-driver.dto';

@Controller('drivers')
@UseGuards(JwtAuthGuard)
@Roles(Role.OWNER)
export class DriversController {
  constructor(private readonly driversService: DriversService) {}

  @Post()
  async create(@Request() req: any, @Body() dto: CreateDriverDto) {
    const result = await this.driversService.createDriver(req.user.companyId, dto);
    return {
      driver: result.user,
      tempPassword: result.tempPassword,
      message: 'Driver created successfully. Share the temp password with the driver.',
    };
  }

  @Get()
  async list(@Request() req: any) {
    return this.driversService.getDrivers(req.user.companyId);
  }

  @Get(':id')
  async get(@Request() req: any, @Param('id') id: string) {
    return this.driversService.getDriver(id, req.user.companyId);
  }

  @Patch(':id/deactivate')
  async deactivate(@Request() req: any, @Param('id') id: string) {
    return this.driversService.deactivateDriver(id, req.user.companyId);
  }

  @Patch(':id/reactivate')
  async reactivate(@Request() req: any, @Param('id') id: string) {
    return this.driversService.reactivateDriver(id, req.user.companyId);
  }
}
