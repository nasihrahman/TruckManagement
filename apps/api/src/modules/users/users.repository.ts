import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Role, User } from '@prisma/client';

@Injectable()
export class UsersRepository {
  constructor(private prisma: PrismaService) {}

  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  async findByPhone(phone: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { phone } });
  }

  async findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async createOwner(input: {
    companyName: string;
    email: string;
    password: string;
    phone: string;
    firstName?: string;
    lastName?: string;
  }): Promise<User> {
    return this.prisma.user.create({
      data: {
        email: input.email,
        password: input.password,
        phone: input.phone,
        role: Role.OWNER,
        firstName: input.firstName,
        lastName: input.lastName,
        company: {
          create: {
            name: input.companyName,
          },
        },
      },
    });
  }

  async updateRefreshToken(userId: string, hashedRefreshToken: string): Promise<User> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { currentHashedRefreshToken: hashedRefreshToken },
    });
  }

  async updatePassword(userId: string, hashedPassword: string): Promise<User> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { password: hashedPassword, mustChangePassword: false },
    });
  }
}
