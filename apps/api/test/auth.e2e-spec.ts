import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe, VersioningType } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { GenericContainer } from 'testcontainers';
import { execSync } from 'child_process';
import path from 'path';

describe('AuthController (e2e)', () => {
  let app: INestApplication;
  let postgresContainer: any;

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
    process.env.JWT_ACCESS_EXPIRATION = '15m';
    process.env.JWT_REFRESH_EXPIRATION = '7d';

    execSync('npx prisma db push', {
      cwd: path.join(__dirname, '..'),
      stdio: 'inherit',
      env: { ...process.env },
    });

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api');
    app.enableVersioning({
        type: VersioningType.URI,
        defaultVersion: '1',
    });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }),
    );
    await app.init();
  }, 60000);

  afterAll(async () => {
    if (app) await app.close();
    if (postgresContainer) await postgresContainer.stop();
  });

  it('registers, logs in, and refreshes tokens', async () => {
    const testUser = {
      email: 'owner@example.com',
      password: 'SecurePass123!',
      companyName: 'Test Fleet',
    };

    // Correct path mapping matching global prefix setup
    const registerResponse = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send(testUser)
        .expect(201);

    expect(registerResponse.body).toHaveProperty('accessToken');
    expect(registerResponse.body).toHaveProperty('refreshToken');

    const loginResponse = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
        .send({ email: testUser.email, password: testUser.password })
        .expect(201);
    expect(loginResponse.body).toHaveProperty('accessToken');
    expect(loginResponse.body).toHaveProperty('refreshToken');

    const refreshResponse = await request(app.getHttpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: loginResponse.body.refreshToken })
      .expect(201);

    expect(refreshResponse.body).toHaveProperty('accessToken');
    expect(refreshResponse.body).toHaveProperty('refreshToken');
  });
});