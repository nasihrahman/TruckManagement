import { IsNotEmpty, Length, ValidateIf, IsEmail } from 'class-validator';

export class LoginDto {
  @IsNotEmpty()
  @Length(5, 255)
  emailOrPhone!: string;

  @IsNotEmpty()
  @Length(8, 128)
  password!: string;
}
