import { Body, Controller, Delete, Get, HttpCode, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PaymentOtpService } from '../payments/payment-otp.service';
import { BookingsService } from './bookings.service';

type Req_ = { userId: string };

@Controller()
@UseGuards(JwtAuthGuard)
export class BookingsController {
  constructor(
    private readonly bookings: BookingsService,
    private readonly payOtp: PaymentOtpService,
  ) {}

  /**
   * Book an admin-created slot.
   * Body: {slotId, paymentMethod:"wallet"|"pay_at_venue", maxPlayers?, otp?}
   * A wallet payment needs the 6-digit `otp` from POST /payments/otp (turn off with PAYMENT_OTP=false).
   */
  @Post('bookings')
  async create(@Req() req: Req_, @Body() body: unknown) {
    const b = (typeof body === 'object' && body !== null ? body : {}) as Record<string, unknown>;
    const needOtp = this.payOtp.required && (b.paymentMethod ?? 'wallet') === 'wallet';
    if (needOtp) await this.payOtp.check(req.userId, b.otp);
    const booking = await this.bookings.create(req.userId, body);
    if (needOtp) this.payOtp.consume(req.userId);
    return booking;
  }

  /** ?status=upcoming|past|all (default all) */
  @Get('bookings')
  list(@Req() req: Req_, @Query('status') status?: string) {
    return this.bookings.list(req.userId, status ?? 'all');
  }

  @Get('bookings/:id')
  get(@Req() req: Req_, @Param('id') id: string) {
    return this.bookings.get(req.userId, id);
  }

  @Post('bookings/:id/cancel')
  @HttpCode(200)
  cancel(@Req() req: Req_, @Param('id') id: string) {
    return this.bookings.cancel(req.userId, id);
  }

  /** Add a teammate (name only). Body: {name, ready?} */
  @Post('bookings/:id/players')
  addPlayer(@Req() req: Req_, @Param('id') id: string, @Body() body: unknown) {
    return this.bookings.addPlayer(req.userId, id, body);
  }

  @Delete('bookings/:id/players/:playerId')
  removePlayer(@Req() req: Req_, @Param('id') id: string, @Param('playerId') playerId: string) {
    return this.bookings.removePlayer(req.userId, id, playerId);
  }

  /** Digital Match Pass of one booking */
  @Get('bookings/:id/pass')
  pass(@Req() req: Req_, @Param('id') id: string) {
    return this.bookings.pass(req.userId, id);
  }

  /** Digital Match Pass of the next upcoming booking (404 if none) */
  @Get('match-pass')
  nextPass(@Req() req: Req_) {
    return this.bookings.nextPass(req.userId);
  }
}
