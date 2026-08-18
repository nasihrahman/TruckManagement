import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { UploadsService } from './uploads.service';

const MAX_FILE_SIZE_BYTES = 8 * 1024 * 1024; // 8MB

@Controller('uploads')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.OWNER, Role.DRIVER)
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_FILE_SIZE_BYTES },
      fileFilter: (_req, file, callback) => {
        if (!file.mimetype.startsWith('image/')) {
          callback(new BadRequestException('Only image files are allowed'), false);
          return;
        }
        callback(null, true);
      },
    }),
  )
  async upload(@UploadedFile() file: Express.Multer.File) {
    const url = await this.uploadsService.uploadImage(file);
    return { url };
  }
}
