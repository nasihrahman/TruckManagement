import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { GenericContainer } from 'testcontainers';
import { execSync } from 'child_process';
import path from 'path';
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

describe('Trips (e2e)', () => {
  let app: INestApplication;
  let postgresContainer: any;
  let prisma: PrismaClient;

  beforeAll(async () => {
    postgresContainer = await new GenericContainer('postgres:15')
      .withEnvironment({
        POSTGRES_USER: 'postgres',
        POSTGRES_PASSWORD: 'postgres',
        POSTGRES_DB: 'truckmanagement_test',
      })
      .withExposedPorts(5432)
      .start();

    const port = postgresContainer.getMappedPort(5432);
    const host = postgresContainer.getHost();
    process.env.DATABASE_URL = `postgresql://postgres:postgres@${host}:${port}/truckmanagement_test?schema=public`;
    process.env.JWT_ACCESS_SECRET = 'test-access-secret';
    process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';

    execSync('npx prisma db push', { cwd: path.join(__dirname, '..'), stdio: 'inherit', env: { ...process.env } });

    // instantiate PrismaClient after DATABASE_URL is set
    prisma = new PrismaClient();

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    await app.init();
  }, 60000);

  afterAll(async () => {
    if (app) await app.close();
    if (postgresContainer) await postgresContainer.stop();
    await prisma.$disconnect();
  });

  it('owner creates trip and driver updates status', async () => {
    // register owner
    const owner = { email: 'owner2@example.com', password: 'SecurePass123!', companyName: 'FleetX' };
    const reg = await request(app.getHttpServer()).post('/api/v1/auth/register').send(owner).expect(201);
    const ownerToken = reg.body.accessToken;

    // find companyId and create driver and truck
    const ownerUser = await prisma.user.findUnique({ where: { email: owner.email } });
    const companyId = ownerUser!.companyId;

    const hashed = await bcrypt.hash('driverpass', 10);
    const driver = await prisma.user.create({ data: { email: 'driver1@example.com', password: hashed, role: 'DRIVER', companyId } });
    const truck = await prisma.truck.create({ data: { companyId, plate: 'TRUCK-1' } });

    // owner creates trip
    const tripRes = await request(app.getHttpServer())
      .post('/api/v1/trips')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ origin: 'X', destination: 'Y' })
      .expect(201);

    const tripId = tripRes.body.id;

    // owner assigns driver and truck
    await request(app.getHttpServer())
      .patch(`/api/v1/trips/${tripId}/assign`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ driverId: driver.id, truckId: truck.id })
      .expect(200);

    // driver login via direct token creation (signing not needed for test, use JWT with payload)
    // Use auth.login endpoint by creating password match: but easier to generate token via API login
    const login = await request(app.getHttpServer()).post('/api/v1/auth/login').send({ email: driver.email, password: 'driverpass' }).expect(201);
    const driverToken = login.body.accessToken;

    // driver updates status to IN_TRANSIT
    await request(app.getHttpServer())
      .patch(`/api/v1/trips/${tripId}/status`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ status: 'IN_TRANSIT' })
      .expect(200);

    // driver updates status to DELIVERED
    await request(app.getHttpServer())
      .patch(`/api/v1/trips/${tripId}/status`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ status: 'DELIVERED' })
      .expect(200);
  }, 60000);
});
