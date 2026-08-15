import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

const SAFE_OWNER_SELECT = {
  id: true,
  companyId: true,
  email: true,
  phone: true,
  role: true,
  firstName: true,
  lastName: true,
  isActive: true,
  mustChangePassword: true,
  createdAt: true,
} as const;

export type SafeOwner = {
  id: string;
  companyId: string;
  email: string | null;
  phone: string;
  role: 'OWNER' | 'DRIVER';
  firstName: string | null;
  lastName: string | null;
  isActive: boolean;
  mustChangePassword: boolean;
  createdAt: Date;
};

@Injectable()
export class OwnersRepository {
  constructor(private prisma: PrismaService) {}

  async createOwner(input: {
    companyId: string;
    name: string;
    phone: string;
    email?: string;
    hashedPassword: string;
  }): Promise<SafeOwner> {
    return this.prisma.user.create({
      data: {
        companyId: input.companyId,
        email: input.email,
        phone: input.phone,
        password: input.hashedPassword,
        role: 'OWNER',
        firstName: input.name,
        mustChangePassword: true,
        isActive: true,
      },
      select: SAFE_OWNER_SELECT,
    });
  }

  async findByCompany(companyId: string): Promise<SafeOwner[]> {
    return this.prisma.user.findMany({
      where: { companyId, role: 'OWNER' },
      select: SAFE_OWNER_SELECT,
      orderBy: { createdAt: 'asc' },
    });
  }
}
