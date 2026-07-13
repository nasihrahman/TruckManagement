import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Drivers (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let ownerToken: string;
  let ownerUserId: string;
  let companyId: string;

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = 'test-access-secret';
    process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';
    process.env.JWT_ACCESS_EXPIRATION = '15m';
    process.env.JWT_REFRESH_EXPIRATION = '7d';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }),
    );
    await app.init();

    prisma = moduleFixture.get<PrismaService>(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    // Clean up database in correct order to avoid foreign key violations
    await prisma.driverProfile.deleteMany({});
    await prisma.fuelReceipt.deleteMany({});
    await prisma.expense.deleteMany({});
    await prisma.issue.deleteMany({});
    await prisma.notification.deleteMany({});
    await prisma.report.deleteMany({});
    await prisma.document.deleteMany({});
    await prisma.maintenanceRecord.deleteMany({});
    await prisma.trip.deleteMany({});
    await prisma.truck.deleteMany({});
    await prisma.user.deleteMany({});
    await prisma.company.deleteMany({});

    // Create an owner account
    const registerRes = await request(app.getHttpServer()).post('/api/v1/auth/register').send({
      email: 'owner@test.com',
      password: 'Password123!',
      phone: '+1234567890',
      firstName: 'Owner',
      lastName: 'Test',
      companyName: 'Test Company',
    });

    expect(registerRes.status).toBe(201);
    ownerToken = registerRes.body.accessToken;

    // Get owner info
    const ownerData = await prisma.user.findUnique({
      where: { email: 'owner@test.com' },
    });
    ownerUserId = ownerData!.id;
    companyId = ownerData!.companyId!;
  });

  describe('POST /api/v1/drivers', () => {
    it('should create a driver with phone as default password', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'John Doe',
          phone: '+9876543210',
          email: 'driver@test.com',
          licenseNumber: 'DL123456',
        });

      expect(res.status).toBe(201);
      expect(res.body.driver.phone).toBe('+9876543210');
      expect(res.body.driver.mustChangePassword).toBe(true);
      expect(res.body.tempPassword).toBe('+9876543210');
      expect(res.body.message).toContain('Share the temp password');
    });

    it('should create a driver with custom initialPassword', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Jane Doe',
          phone: '+1111111111',
          initialPassword: 'CustomTemp123!',
        });

      expect(res.status).toBe(201);
      expect(res.body.tempPassword).toBe('CustomTemp123!');
    });

    it('should reject request without authorization', async () => {
      const res = await request(app.getHttpServer()).post('/api/v1/drivers').send({
        name: 'John Doe',
        phone: '+9876543210',
      });

      expect(res.status).toBe(401);
    });

    it('should reject request with duplicate phone', async () => {
      // Create first driver
      await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Driver One',
          phone: '+1111111111',
        });

      // Try to create second driver with same phone
      const res = await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Driver Two',
          phone: '+1111111111',
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('already exists');
    });

    it('should reject request with duplicate email', async () => {
      // Create first driver
      await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Driver One',
          phone: '+1111111111',
          email: 'duplicate@test.com',
        });

      // Try to create second driver with same email
      const res = await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Driver Two',
          phone: '+2222222222',
          email: 'duplicate@test.com',
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('already exists');
    });
  });

  describe('GET /api/v1/drivers', () => {
    it('should list drivers for the company', async () => {
      // Create a driver first
      await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Driver One',
          phone: '+1111111111',
        });

      const res = await request(app.getHttpServer())
        .get('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      expect(res.body[0].phone).toBe('+1111111111');
    });
  });

  describe('PATCH /api/v1/drivers/:id/deactivate', () => {
    it('should deactivate an active driver', async () => {
      // Create a driver first
      const createRes = await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Driver One',
          phone: '+1111111111',
        });

      const driverId = createRes.body.driver.id;

      const res = await request(app.getHttpServer())
        .patch(`/api/v1/drivers/${driverId}/deactivate`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.isActive).toBe(false);
    });

    it('should reject deactivating an already inactive driver', async () => {
      // Create and deactivate a driver
      const createRes = await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Driver One',
          phone: '+1111111111',
        });

      const driverId = createRes.body.driver.id;

      await request(app.getHttpServer())
        .patch(`/api/v1/drivers/${driverId}/deactivate`)
        .set('Authorization', `Bearer ${ownerToken}`);

      const res = await request(app.getHttpServer())
        .patch(`/api/v1/drivers/${driverId}/deactivate`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(400);
    });
  });

  describe('PATCH /api/v1/drivers/:id/reactivate', () => {
    it('should reactivate an inactive driver', async () => {
      // Create and deactivate a driver
      const createRes = await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Driver One',
          phone: '+1111111111',
        });

      const driverId = createRes.body.driver.id;

      await request(app.getHttpServer())
        .patch(`/api/v1/drivers/${driverId}/deactivate`)
        .set('Authorization', `Bearer ${ownerToken}`);

      const res = await request(app.getHttpServer())
        .patch(`/api/v1/drivers/${driverId}/reactivate`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.isActive).toBe(true);
    });

    it('should reject reactivating an already active driver', async () => {
      // Create a driver (starts active)
      const createRes = await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Driver One',
          phone: '+1111111111',
        });

      const driverId = createRes.body.driver.id;

      const res = await request(app.getHttpServer())
        .patch(`/api/v1/drivers/${driverId}/reactivate`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(400);
    });
  });

  describe('Driver password change', () => {
    it('should allow a driver to change their password', async () => {
      // Create a driver via API to ensure password is hashed
      const createRes = await request(app.getHttpServer())
        .post('/api/v1/drivers')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          name: 'Password Change Driver',
          phone: '+999888777',
          email: 'driver_pw@test.com',
        });
      
      const tempPassword = createRes.body.tempPassword;

      // Login as driver to get token
      const loginRes = await request(app.getHttpServer()).post('/api/v1/auth/login').send({
        emailOrPhone: '+999888777',
        password: tempPassword,
      });
      const token = loginRes.body.accessToken;

      // Change password
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/change-password')
        .set('Authorization', `Bearer ${token}`)
        .send({
          newPassword: 'NewSecurePassword123!',
        });

      expect(res.status).toBe(201);

      // Try logging in with new password
      const loginNewRes = await request(app.getHttpServer()).post('/api/v1/auth/login').send({
        emailOrPhone: '+999888777',
        password: 'NewSecurePassword123!',
      });
      expect(loginNewRes.status).toBe(201);
    });
  });
});
