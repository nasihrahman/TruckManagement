import { Body, Controller, Delete, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { MaterialsService } from './materials.service';
import { CreateMaterialDto, UpdateMaterialDto } from './dto/material.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller('materials')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.OWNER)
export class MaterialsController {
  constructor(private readonly materialsService: MaterialsService) {}

  @Post()
  async create(@Request() req: any, @Body() dto: CreateMaterialDto) {
    return this.materialsService.create(req.user.companyId, dto);
  }

  @Get()
  @Roles(Role.OWNER, Role.DRIVER)
  async findAll(@Request() req: any) {
    return this.materialsService.findAll(req.user.companyId);
  }

  @Patch(':id')
  async update(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateMaterialDto) {
    return this.materialsService.update(id, req.user.companyId, dto);
  }

  @Delete(':id')
  async remove(@Request() req: any, @Param('id') id: string) {
    return this.materialsService.remove(id, req.user.companyId);
  }
}
