import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Request, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { DailyExpensesService } from './daily-expenses.service';
import { CreateDailyExpenseDto } from './dto/create-daily-expense.dto';
import { UpdateDailyExpenseDto } from './dto/update-daily-expense.dto';
import { ListDailyExpensesQueryDto } from './dto/list-daily-expenses-query.dto';
import { DailyExpenseExportQueryDto } from './dto/daily-expense-export-query.dto';

@Controller('daily-expenses')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.OWNER, Role.DRIVER)
export class DailyExpensesController {
  constructor(private readonly service: DailyExpensesService) {}

  @Post()
  async create(@Request() req: any, @Body() dto: CreateDailyExpenseDto) {
    return this.service.create(req.user, dto);
  }

  @Get()
  async list(@Request() req: any, @Query() query: ListDailyExpensesQueryDto) {
    return this.service.findByCompany(req.user, query.period, query.date, {
      limit: query.limit,
      offset: query.offset,
    });
  }

  @Get('export.xlsx')
  @Roles(Role.OWNER)
  async exportXlsx(@Request() req: any, @Query() query: DailyExpenseExportQueryDto, @Res() res: Response) {
    const buffer = await this.service.exportToExcel(req.user.companyId, query.period, query.date);
    const suffix = query.period ? `-${query.period}` : '';
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="daily-expenses${suffix}.xlsx"`,
    });
    res.send(buffer);
  }

  @Patch(':id')
  async update(@Request() req: any, @Param('id') id: string, @Body() dto: UpdateDailyExpenseDto) {
    return this.service.update(id, req.user, dto);
  }

  @Delete(':id')
  async remove(@Request() req: any, @Param('id') id: string) {
    await this.service.remove(id, req.user);
    return { success: true };
  }
}
