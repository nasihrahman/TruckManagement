import { Body, Controller, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { DriversService } from './drivers.service';
import { CreateDriverDto } from './dto/create-driver.dto';
import { UpdateDriverDto } from './dto/update-driver.dto';
import { LocationPingDto } from './dto/location-ping.dto';

@Controller('drivers')
@UseGuards(JwtAuthGuard, RolesGuard)
export class DriversController {
  constructor(private readonly driversService: DriversService) {}

  @Get('me')
  @Roles(Role.DRIVER)
  async me(@Request() req: any) {
    return this.driversService.getOwnProfile(req.user.userId, req.user.companyId);
  }

  @Post('me/go-online')
  @Roles(Role.DRIVER)
  async goOnline(@Request() req: any) {
    return this.driversService.goOnline(req.user.userId, req.user.companyId);
  }

  @Post('me/go-offline')
  @Roles(Role.DRIVER)
  async goOffline(@Request() req: any) {
    return this.driversService.goOffline(req.user.userId, req.user.companyId);
  }

  @Post('me/location')
  @Roles(Role.DRIVER)
  async pingLocation(@Request() req: any, @Body() dto: LocationPingDto) {
    return this.driversService.recordLocation(req.user.userId, req.user.companyId, dto);
  }

  @Get('online-locations')
  @Roles(Role.OWNER)
  async onlineLocations(@Request() req: any) {
    return this.driversService.getOnlineLocations(req.user.companyId);
  }

  @Get()
  @Roles(Role.OWNER)
  async list(@Request() req: any) {
    return this.driversService.getDrivers(req.user.companyId);
  }

  @Post()
  @Roles(Role.OWNER)
  async create(@Request() req: any, @Body() dto: CreateDriverDto) {
    const result = await this.driversService.createDriver(req.user.companyId, dto);
    return {
      driver: result.user,
      tempPassword: result.tempPassword,
      message: 'Driver created successfully. Share the temp password with the driver.',
    };
  }

  @Get(':id')
  @Roles(Role.OWNER)
  async get(@Request() req: any, @Param('id') id: string) {
    return this.driversService.getDriver(id, req.user.companyId);
  }

  @Patch(':id')
  @Roles(Role.OWNER)
  async update(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateDriverDto) {
    return this.driversService.updateDriver(id, req.user.companyId, dto);
  }

  @Patch(':id/deactivate')
  @Roles(Role.OWNER)
  async deactivate(@Request() req: any, @Param('id') id: string) {
    return this.driversService.deactivateDriver(id, req.user.companyId);
  }

  @Patch(':id/reactivate')
  @Roles(Role.OWNER)
  async reactivate(@Request() req: any, @Param('id') id: string) {
    return this.driversService.reactivateDriver(id, req.user.companyId);
  }

  @Patch(':id/reset-password')
  @Roles(Role.OWNER)
  async resetPassword(@Request() req: any, @Param('id') id: string) {
    const result = await this.driversService.resetPassword(id, req.user.companyId);
    return {
      driver: result.user,
      tempPassword: result.tempPassword,
      message: 'Password reset. Share the new temp password with the driver.',
    };
  }
}
