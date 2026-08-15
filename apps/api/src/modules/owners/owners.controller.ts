import { Body, Controller, Get, Post, Request, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { OwnersService } from './owners.service';
import { CreateOwnerDto } from './dto/create-owner.dto';

@Controller('owners')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OwnersController {
  constructor(private readonly ownersService: OwnersService) {}

  @Get()
  @Roles(Role.OWNER)
  async list(@Request() req: any) {
    return this.ownersService.getOwners(req.user.companyId);
  }

  @Post()
  @Roles(Role.OWNER)
  async create(@Request() req: any, @Body() dto: CreateOwnerDto) {
    const result = await this.ownersService.createOwner(req.user.companyId, dto);
    return {
      owner: result.user,
      tempPassword: result.tempPassword,
      message: 'Owner created successfully. Share the temp password with them.',
    };
  }
}
