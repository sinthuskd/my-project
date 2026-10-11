import { Module } from '@nestjs/common';
import { AdminCatalogService } from './admin/admin-catalog.service';
import { AdminOpsService } from './admin/admin-ops.service';
import { AdminSlotsService } from './admin/admin-slots.service';
import { AdminAuthController, AdminController } from './admin/admin.controller';
import { AdminGuard } from './admin/admin.guard';
import { AuthController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { JwtAuthGuard } from './auth/jwt-auth.guard';
import { BookingsController } from './bookings/bookings.controller';
import { BookingsService } from './bookings/bookings.service';
import { AvailabilityService } from './catalog/availability.service';
import { CatalogController } from './catalog/catalog.controller';
import { CatalogService } from './catalog/catalog.service';
import { Db } from './db/db.service';
import { HealthController } from './health.controller';
import { BeaconsService } from './partners/beacons.service';
import { ClubsService } from './partners/clubs.service';
import { FriendsService } from './partners/friends.service';
import { PartnersController } from './partners/partners.controller';
import { PaymentOtpService } from './payments/payment-otp.service';
import { PaymentsController } from './payments/payments.controller';
import { ConsoleSmsSender, SMS_SENDER } from './sms/sms.sender';
import { UsersRepo } from './users/users.repo';
import { WalletController } from './wallet/wallet.controller';
import { WalletService } from './wallet/wallet.service';

@Module({
  controllers: [AuthController, AdminAuthController, AdminController, CatalogController, BookingsController, WalletController, PaymentsController, PartnersController, HealthController],
  providers: [
    Db,
    UsersRepo,
    AuthService,
    JwtAuthGuard,
    AdminGuard,
    AdminCatalogService,
    AdminSlotsService,
    AdminOpsService,
    AvailabilityService,
    CatalogService,
    BookingsService,
    WalletService,
    PaymentOtpService,
    BeaconsService,
    FriendsService,
    ClubsService,
    // To send real SMS, replace ConsoleSmsSender with your own class (see src/sms/sms.sender.ts)
    { provide: SMS_SENDER, useClass: ConsoleSmsSender },
  ],
})
export class AppModule {}
