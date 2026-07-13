import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../users/users.service';
import { AuthResponseDto } from './dto/auth-response.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async register(payload: {
    email: string;
    password: string;
    phone: string;
    firstName?: string;
    lastName?: string;
    companyName?: string;
  }): Promise<AuthResponseDto> {
    const existingUser = await this.usersService.findByEmail(payload.email);
    if (existingUser) {
      throw new BadRequestException('Email already registered');
    }

    const hashedPassword = await bcrypt.hash(payload.password, 10);
    const user = await this.usersService.createOwner({
      email: payload.email,
      password: hashedPassword,
      phone: payload.phone,
      firstName: payload.firstName,
      lastName: payload.lastName,
      companyName: payload.companyName ?? `${payload.email}-company`,
    });

    const tokens = await this.getTokens(user.id, user.email || user.phone, user.role, user.companyId);
    await this.usersService.setCurrentRefreshToken(user.id, await bcrypt.hash(tokens.refreshToken, 10));
    return tokens;
  }

  async login(emailOrPhone: string, password: string): Promise<AuthResponseDto> {
    // Try email first, then phone
    let user = await this.usersService.findByEmail(emailOrPhone);
    if (!user) {
      user = await this.usersService.findByPhone(emailOrPhone);
    }
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const passwordMatches = await bcrypt.compare(password, user.password);
    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const tokens = await this.getTokens(user.id, user.email || user.phone, user.role, user.companyId);
    await this.usersService.setCurrentRefreshToken(user.id, await bcrypt.hash(tokens.refreshToken, 10));

    return { ...tokens, mustChangePassword: user.mustChangePassword, role: user.role };
  }

  async refresh(refreshToken: string): Promise<AuthResponseDto> {
    try {
      const payload = this.jwtService.verify<{ sub: string; email: string; role: string; companyId: string }>(refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      });

      const user = await this.usersService.findById(payload.sub);
      if (!user || !user.currentHashedRefreshToken) {
        throw new UnauthorizedException('Invalid refresh token');
      }

      const refreshTokenMatches = await bcrypt.compare(refreshToken, user.currentHashedRefreshToken);
      if (!refreshTokenMatches) {
        throw new UnauthorizedException('Invalid refresh token');
      }

      const tokens = await this.getTokens(user.id, user.email || user.phone, user.role, user.companyId);
      await this.usersService.setCurrentRefreshToken(user.id, await bcrypt.hash(tokens.refreshToken, 10));
      return tokens;
    } catch (error) {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async changePassword(userId: string, newPassword: string): Promise<void> {
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await this.usersService.updatePassword(userId, hashedPassword);
  }

  private async getTokens(userId: string, email: string, role: string, companyId: string): Promise<AuthResponseDto> {
    const secret = this.configService.get<string>('JWT_ACCESS_SECRET');
    console.log('AuthService signing token with secret:', secret);
    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(
        { sub: userId, email, role, companyId },
        {
          secret: secret,
          expiresIn: this.configService.get<string>('JWT_ACCESS_EXPIRATION', '15m'),
        },
      ),
      this.jwtService.signAsync(
        { sub: userId, email, role, companyId },
        {
          secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
          expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRATION', '7d'),
        },
      ),
    ]);

    return { accessToken, refreshToken };
  }
}
