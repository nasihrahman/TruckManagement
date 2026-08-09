import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Expense, Prisma } from '@prisma/client';

@Injectable()
export class ExpensesRepository {
  constructor(private prisma: PrismaService) {}

  async create(data: Prisma.ExpenseUncheckedCreateInput): Promise<Expense> {
    return this.prisma.expense.create({ data });
  }

  async findById(id: string): Promise<Expense | null> {
    return this.prisma.expense.findUnique({ where: { id } });
  }

  async findByTrip(tripId: string): Promise<Expense[]> {
    return this.prisma.expense.findMany({ where: { tripId }, orderBy: { createdAt: 'desc' } });
  }

  async update(id: string, data: Prisma.ExpenseUncheckedUpdateInput): Promise<Expense> {
    return this.prisma.expense.update({ where: { id }, data });
  }

  async delete(id: string): Promise<Expense> {
    return this.prisma.expense.delete({ where: { id } });
  }
}
