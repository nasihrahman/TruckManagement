import { Injectable, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { Prisma } from '@prisma/client';
import { OwnersRepository, SafeOwner } from './owners.repository';
import { CreateOwnerDto } from './dto/create-owner.dto';

@Injectable()
export class OwnersService {
  constructor(private ownersRepository: OwnersRepository) {}

  async createOwner(companyId: string, dto: CreateOwnerDto): Promise<{ user: SafeOwner; tempPassword: string }> {
    const tempPassword = dto.initialPassword || dto.phone;
    const hashedPassword = await bcrypt.hash(tempPassword, 10);

    try {
      const user = await this.ownersRepository.createOwner({
        companyId,
        name: dto.name,
        phone: dto.phone,
        email: dto.email,
        hashedPassword,
      });
      return { user, tempPassword };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const target = (error.meta?.target as string[]) || [];
        if (target.includes('phone')) {
          throw new BadRequestException('An account with this phone number already exists');
        }
        if (target.includes('email')) {
          throw new BadRequestException('An account with this email address already exists');
        }
      }
      throw error;
    }
  }

  async getOwners(companyId: string): Promise<SafeOwner[]> {
    return this.ownersRepository.findByCompany(companyId);
  }
}
