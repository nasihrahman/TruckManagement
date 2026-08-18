import { Injectable, OnModuleInit, BadRequestException } from '@nestjs/common';
import { v2 as cloudinary } from 'cloudinary';

@Injectable()
export class UploadsService implements OnModuleInit {
  onModuleInit() {
    // Explicit call (not import-time auto-config) so this reliably reads
    // CLOUDINARY_URL after dotenv has populated process.env, regardless of
    // module import order.
    cloudinary.config();
  }

  async uploadImage(file: Express.Multer.File): Promise<string> {
    if (!file) {
      throw new BadRequestException('No file provided');
    }

    return new Promise<string>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder: 'truckmanagement', resource_type: 'image' },
        (error, result) => {
          if (error || !result) {
            reject(new BadRequestException(error?.message ?? 'Image upload failed'));
            return;
          }
          resolve(result.secure_url);
        },
      );
      stream.end(file.buffer);
    });
  }
}
