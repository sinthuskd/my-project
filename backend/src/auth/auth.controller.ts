import { Body, Controller, Get, HttpCode, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() body: unknown) {
    return this.auth.register(body);
  }

  @Post('verify-otp')
  @HttpCode(200)
  verifyOtp(@Body() body: unknown) {
    return this.auth.verifyOtp(body);
  }

  @Post('resend-otp')
  @HttpCode(200)
  resendOtp(@Body() body: unknown) {
    return this.auth.resendOtp(body);
  }

  @Post('login')
  @HttpCode(200)
  login(@Body() body: unknown) {
    return this.auth.login(body);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@Req() req: { userId: string }) {
    return this.auth.getProfile(req.userId);
  }
}
