import { Controller, Get, Query, Request, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { ReportsService } from './reports.service';
import { OperationsReportQueryDto } from './dto/operations-report-query.dto';

@Controller('reports')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.OWNER)
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('operations')
  async operations(@Request() req: any, @Query() query: OperationsReportQueryDto) {
    return this.reportsService.getOperationsReport(req.user.companyId, query.period, query.date);
  }

  @Get('operations.xlsx')
  async operationsXlsx(@Request() req: any, @Query() query: OperationsReportQueryDto, @Res() res: Response) {
    const buffer = await this.reportsService.exportOperationsReport(req.user.companyId, query.period, query.date);
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="operations-report-${query.period}.xlsx"`,
    });
    res.send(buffer);
  }
}
