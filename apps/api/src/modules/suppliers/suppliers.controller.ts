import { Body, Controller, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { SuppliersService } from './suppliers.service';
import { CreateSupplierDto, UpdateSupplierDto } from './dto/supplier.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller('suppliers')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.OWNER)
export class SuppliersController {
  constructor(private readonly suppliersService: SuppliersService) {}

  @Post()
  async create(@Request() req: any, @Body() dto: CreateSupplierDto) {
    return this.suppliersService.create(req.user.companyId, dto);
  }

  @Get()
  @Roles(Role.OWNER, Role.DRIVER)
  async findAll(@Request() req: any) {
    return this.suppliersService.findAll(req.user.companyId);
  }

  @Patch(':id')
  async update(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateSupplierDto) {
    return this.suppliersService.update(id, req.user.companyId, dto);
  }
}
