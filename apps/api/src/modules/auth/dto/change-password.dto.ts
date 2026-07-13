import { IsNotEmpty, Length, IsString } from 'class-validator';

export class ChangePasswordDto {
  @IsNotEmpty()
  @IsString()
  @Length(8, 128)
  newPassword!: string;
}
