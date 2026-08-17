import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { TripsModule } from './modules/trips/trips.module';
import { DriversModule } from './modules/drivers/drivers.module';
import { TrucksModule } from './modules/trucks/trucks.module';
import { ExpensesModule } from './modules/expenses/expenses.module';
import { OwnersModule } from './modules/owners/owners.module';
import { ReportsModule } from './modules/reports/reports.module';
import { MaterialsModule } from './modules/materials/materials.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
    TripsModule,
    DriversModule,
    TrucksModule,
    ExpensesModule,
    OwnersModule,
    ReportsModule,
    MaterialsModule,
  ],
})
export class AppModule {}
