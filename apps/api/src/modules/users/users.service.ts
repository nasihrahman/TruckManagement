import { Injectable } from '@nestjs/common';
import { UsersRepository } from './users.repository';
import { User } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private usersRepository: UsersRepository) {}

  async findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findByEmail(email);
  }

  async findById(id: string): Promise<User | null> {
    return this.usersRepository.findById(id);
  }

  async createOwner(data: {
    companyName: string;
    email: string;
    password: string;
    firstName?: string;
    lastName?: string;
  }): Promise<User> {
    return this.usersRepository.createOwner(data);
  }

  async setCurrentRefreshToken(userId: string, hashedToken: string): Promise<User> {
    return this.usersRepository.updateRefreshToken(userId, hashedToken);
  }

  async removeRefreshToken(userId: string): Promise<User> {
    return this.usersRepository.removeRefreshToken(userId);
  }
}
