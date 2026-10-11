import { Controller, HttpCode, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PaymentOtpService } from './payment-otp.service';

@Controller('payments')
@UseGuards(JwtAuthGuard)
export class PaymentsController {
  constructor(private readonly otp: PaymentOtpService) {}

  /** Sends a 6-digit payment code to the user's mobile (printed in the terminal in dev mode). */
  @Post('otp')
  @HttpCode(200)
  send(@Req() req: { userId: string }) {
    return this.otp.issue(req.userId);
  }
}
