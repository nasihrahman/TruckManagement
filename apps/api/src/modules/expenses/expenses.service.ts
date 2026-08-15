import { Injectable, ForbiddenException, NotFoundException, BadRequestException } from '@nestjs/common';
import { ExpensesRepository } from './expenses.repository';
import { TripsRepository } from '../trips/trips.repository';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { Expense } from '@prisma/client';

type RequestUser = { userId: string; role: string; companyId: string };

@Injectable()
export class ExpensesService {
  constructor(
    private readonly expensesRepository: ExpensesRepository,
    private readonly tripsRepository: TripsRepository,
  ) {}

  private async getTripForCompany(tripId: string, companyId: string) {
    const trip = await this.tripsRepository.findById(tripId);
    if (!trip || trip.companyId !== companyId) throw new NotFoundException('Trip not found');
    return trip;
  }

  async create(tripId: string, user: RequestUser, dto: CreateExpenseDto): Promise<Expense> {
    const trip = await this.getTripForCompany(tripId, user.companyId);

    let driverId: string;
    if (user.role === 'DRIVER') {
      if (trip.driverId !== user.userId) {
        throw new ForbiddenException('Driver not assigned to this trip');
      }
      driverId = user.userId;
    } else if (user.role === 'OWNER') {
      if (!trip.driverId) {
        throw new BadRequestException('Assign a driver to this trip before logging expenses');
      }
      driverId = trip.driverId;
    } else {
      throw new ForbiddenException('Not allowed to log expenses for this trip');
    }

    if (trip.financiallyClosed) {
      throw new BadRequestException('Trip is financially closed and no longer accepts expenses');
    }

    return this.expensesRepository.create({
      tripId,
      companyId: user.companyId,
      driverId,
      category: dto.category,
      amount: dto.amount,
      photoUrl: dto.photoUrl,
      odometer: dto.odometer,
      reason: dto.reason,
      notes: dto.notes,
    });
  }

  async findByTrip(tripId: string, user: RequestUser): Promise<Expense[]> {
    const trip = await this.getTripForCompany(tripId, user.companyId);

    if (user.role === 'DRIVER' && trip.driverId !== user.userId) {
      throw new ForbiddenException('Driver not assigned to this trip');
    }

    return this.expensesRepository.findByTrip(tripId);
  }

  async update(tripId: string, expenseId: string, user: RequestUser, dto: UpdateExpenseDto): Promise<Expense> {
    const trip = await this.getTripForCompany(tripId, user.companyId);

    const expense = await this.expensesRepository.findById(expenseId);
    if (!expense || expense.tripId !== tripId) throw new NotFoundException('Expense not found');

    const isAssignedDriver = user.role === 'DRIVER' && trip.driverId === user.userId && expense.driverId === user.userId;
    if (user.role !== 'OWNER' && !isAssignedDriver) {
      throw new ForbiddenException('Not allowed to edit this expense');
    }
    if (trip.financiallyClosed) {
      throw new BadRequestException('Trip is financially closed and expenses can no longer be edited');
    }

    return this.expensesRepository.update(expenseId, {
      category: dto.category,
      amount: dto.amount,
      photoUrl: dto.photoUrl,
      odometer: dto.odometer,
      reason: dto.reason,
      notes: dto.notes,
    });
  }

  async delete(tripId: string, expenseId: string, user: RequestUser): Promise<Expense> {
    const trip = await this.getTripForCompany(tripId, user.companyId);

    const expense = await this.expensesRepository.findById(expenseId);
    if (!expense || expense.tripId !== tripId) throw new NotFoundException('Expense not found');

    const isAssignedDriver = user.role === 'DRIVER' && trip.driverId === user.userId && expense.driverId === user.userId;
    if (user.role !== 'OWNER' && !isAssignedDriver) {
      throw new ForbiddenException('Not allowed to delete this expense');
    }
    if (trip.financiallyClosed) {
      throw new BadRequestException('Trip is financially closed and expenses can no longer be deleted');
    }

    return this.expensesRepository.delete(expenseId);
  }
}
