import { Body, Controller, Delete, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { SuppliersService } from './suppliers.service';
import { CreateSupplierDto, UpdateSupplierDto } from './dto/supplier.dto';
import { ReorderSuppliersDto } from './dto/reorder-suppliers.dto';
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

  // Must come before @Patch(':id') — see MaterialsController for why.
  @Patch('reorder')
  async reorder(@Request() req: any, @Body() dto: ReorderSuppliersDto) {
    return this.suppliersService.reorder(req.user.companyId, dto.ids);
  }

  @Patch(':id')
  async update(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateSupplierDto) {
    return this.suppliersService.update(id, req.user.companyId, dto);
  }

  @Delete(':id')
  async remove(@Request() req: any, @Param('id') id: string) {
    return this.suppliersService.remove(id, req.user.companyId);
  }
}
