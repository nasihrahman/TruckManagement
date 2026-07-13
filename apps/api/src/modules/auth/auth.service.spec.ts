import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
  let service: AuthService;
  let usersService: Partial<UsersService>;
  let jwtService: Partial<JwtService>;
  let configService: Partial<ConfigService>;

  beforeEach(async () => {
    usersService = {
      findByEmail: jest.fn(),
      findById: jest.fn(),
      createOwner: jest.fn(),
      setCurrentRefreshToken: jest.fn(),
    };

    jwtService = {
      signAsync: jest.fn().mockResolvedValue('signed-token'),
      verify: jest.fn(),
    };

    configService = {
      get: jest.fn((key: string) => {
        if (key === 'JWT_ACCESS_SECRET') return 'access-secret';
        if (key === 'JWT_REFRESH_SECRET') return 'refresh-secret';
        if (key === 'JWT_ACCESS_EXPIRATION') return '15m';
        if (key === 'JWT_REFRESH_EXPIRATION') return '7d';
        return undefined;
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: usersService },
        { provide: JwtService, useValue: jwtService },
        { provide: ConfigService, useValue: configService },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  it('should register and store refresh token', async () => {
    const user = {
      id: 'user-1',
      email: 'owner@example.com',
      role: 'OWNER',
      companyId: 'company-1',
    } as any;

    (usersService.findByEmail as jest.Mock).mockResolvedValue(null);
    (usersService.createOwner as jest.Mock).mockResolvedValue(user);
    (usersService.setCurrentRefreshToken as jest.Mock).mockResolvedValue(user);

    const result = await service.register({
      email: 'owner@example.com',
      password: 'securepassword',
      phone: '+1234567890',
      companyName: 'Acme Fleet',
    });

    expect(result.accessToken).toBe('signed-token');
    expect(result.refreshToken).toBe('signed-token');
    expect(usersService.setCurrentRefreshToken).toHaveBeenCalled();
  });

  it('should login with valid credentials', async () => {
    const hashedPassword = await bcrypt.hash('securepassword', 10);
    const user = {
      id: 'user-1',
      email: 'owner@example.com',
      role: 'OWNER',
      companyId: 'company-1',
      password: hashedPassword,
      isActive: true,
    } as any;

    (usersService.findByEmail as jest.Mock).mockResolvedValue(user);
    (usersService.setCurrentRefreshToken as jest.Mock).mockResolvedValue(user);

    const result = await service.login('owner@example.com', 'securepassword');

    expect(result.accessToken).toBe('signed-token');
    expect(result.refreshToken).toBe('signed-token');
    expect(usersService.setCurrentRefreshToken).toHaveBeenCalled();
  });

  it('should refresh tokens when refresh token is valid', async () => {
    const hashedRefreshToken = await bcrypt.hash('existing-refresh-token', 10);
    const user = {
      id: 'user-1',
      email: 'owner@example.com',
      role: 'OWNER',
      companyId: 'company-1',
      currentHashedRefreshToken: hashedRefreshToken,
    } as any;

    (jwtService.verify as jest.Mock).mockReturnValue({
      sub: 'user-1',
      email: 'owner@example.com',
      role: 'OWNER',
      companyId: 'company-1',
    });
    (usersService.findById as jest.Mock).mockResolvedValue(user);
    (usersService.setCurrentRefreshToken as jest.Mock).mockResolvedValue(user);

    const result = await service.refresh('existing-refresh-token');

    expect(result.accessToken).toBe('signed-token');
    expect(result.refreshToken).toBe('signed-token');
    expect(usersService.setCurrentRefreshToken).toHaveBeenCalled();
  });
});
