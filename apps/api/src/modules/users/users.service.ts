import { Injectable } from '@nestjs/common';
import { UsersRepository } from './users.repository';
import { User } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private usersRepository: UsersRepository) {}

  async findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findByEmail(email);
  }

  async findByPhone(phone: string): Promise<User | null> {
    return this.usersRepository.findByPhone(phone);
  }

  async findById(id: string): Promise<User | null> {
    return this.usersRepository.findById(id);
  }

  async createOwner(data: {
    companyName: string;
    email: string;
    password: string;
    phone: string;
    firstName?: string;
    lastName?: string;
  }): Promise<User> {
    return this.usersRepository.createOwner(data);
  }

  async setCurrentRefreshToken(userId: string, hashedToken: string): Promise<User> {
    return this.usersRepository.updateRefreshToken(userId, hashedToken);
  }

  async updatePassword(userId: string, hashedPassword: string): Promise<User> {
    return this.usersRepository.updatePassword(userId, hashedPassword);
  }
}
