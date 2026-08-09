import { Body, Controller, Delete, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ExpensesService } from './expenses.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';

@Controller('trips/:tripId/expenses')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ExpensesController {
  constructor(private readonly expensesService: ExpensesService) {}

  @Post()
  async create(@Request() req: any, @Param('tripId') tripId: string, @Body() dto: CreateExpenseDto) {
    return this.expensesService.create(tripId, req.user, dto);
  }

  @Get()
  async list(@Request() req: any, @Param('tripId') tripId: string) {
    return this.expensesService.findByTrip(tripId, req.user);
  }

  @Patch(':id')
  async update(
    @Request() req: any,
    @Param('tripId') tripId: string,
    @Param('id') id: string,
    @Body() dto: UpdateExpenseDto,
  ) {
    return this.expensesService.update(tripId, id, req.user, dto);
  }

  @Delete(':id')
  async delete(@Request() req: any, @Param('tripId') tripId: string, @Param('id') id: string) {
    return this.expensesService.delete(tripId, id, req.user);
  }
}
