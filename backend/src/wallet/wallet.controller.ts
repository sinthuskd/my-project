import { Body, Controller, Get, HttpCode, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { WalletService } from './wallet.service';

@Controller('wallet')
@UseGuards(JwtAuthGuard)
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @Get()
  get(@Req() req: { userId: string }) {
    return this.wallet.get(req.userId);
  }

  /** Body: {amount: 5000}. Dev only, see WalletService.topUp */
  @Post('topup')
  @HttpCode(200)
  topUp(@Req() req: { userId: string }, @Body() body: unknown) {
    return this.wallet.topUp(req.userId, body);
  }
}
