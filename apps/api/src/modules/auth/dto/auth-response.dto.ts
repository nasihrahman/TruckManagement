export class AuthResponseDto {
  accessToken!: string;
  refreshToken!: string;
  mustChangePassword?: boolean;
  role?: string;
}
