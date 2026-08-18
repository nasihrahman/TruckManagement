import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Request, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { HitachiJobsService } from './hitachi-jobs.service';
import { CreateHitachiJobDto, UpdateHitachiJobDto } from './dto/hitachi-job.dto';
import { HitachiJobExportQueryDto } from './dto/hitachi-job-export-query.dto';

@Controller('hitachi-jobs')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.OWNER, Role.DRIVER)
export class HitachiJobsController {
  constructor(private readonly hitachiJobsService: HitachiJobsService) {}

  @Post()
  async create(@Request() req: any, @Body() dto: CreateHitachiJobDto) {
    return this.hitachiJobsService.create(req.user, dto);
  }

  @Get()
  async list(@Request() req: any) {
    return this.hitachiJobsService.findByCompany(req.user.companyId, req.user.userId, req.user.role);
  }

  @Get('export.xlsx')
  async exportXlsx(@Request() req: any, @Query() query: HitachiJobExportQueryDto, @Res() res: Response) {
    const buffer = await this.hitachiJobsService.exportToExcel(req.user, query.period, query.date);
    const suffix = query.period ? `-${query.period}` : '';
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="hitachi-jobs-export${suffix}.xlsx"`,
    });
    res.send(buffer);
  }

  @Get(':id')
  async get(@Request() req: any, @Param('id') id: string) {
    return this.hitachiJobsService.findOne(id, req.user);
  }

  @Patch(':id')
  async update(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateHitachiJobDto) {
    return this.hitachiJobsService.update(id, req.user, dto);
  }

  @Delete(':id')
  async remove(@Request() req: any, @Param('id') id: string) {
    return this.hitachiJobsService.remove(id, req.user);
  }
}
