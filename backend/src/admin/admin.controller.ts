import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, Query, Req, UseGuards } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { UsersRepo } from '../users/users.repo';
import { toPublicUser } from '../users/user.model';
import { HttpError } from '../common/http-error';
import { AdminCatalogService } from './admin-catalog.service';
import { AdminOpsService } from './admin-ops.service';
import { AdminSlotsService } from './admin-slots.service';
import { AdminGuard } from './admin.guard';

/** Admin login (no token needed). */
@Controller('admin/auth')
export class AdminAuthController {
  constructor(private readonly auth: AuthService) {}

  /** Body: {email, password} -> {accessToken, user}. Only accounts with role "admin" can log in here. */
  @Post('login')
  @HttpCode(200)
  login(@Body() body: unknown) {
    return this.auth.adminLogin(body);
  }
}

type Q = Record<string, string>;

/** Everything below needs  Authorization: Bearer <admin accessToken> */
@Controller('admin')
@UseGuards(AdminGuard)
export class AdminController {
  constructor(
    private readonly users: UsersRepo,
    private readonly catalog: AdminCatalogService,
    private readonly slots: AdminSlotsService,
    private readonly ops: AdminOpsService,
  ) {}

  @Get('me')
  async me(@Req() req: { userId: string }) {
    const u = await this.users.findById(req.userId);
    if (!u) throw new HttpError(401, 'Account no longer exists');
    return toPublicUser(u);
  }

  /* ---- dashboard ---- */
  @Get('dashboard')
  dashboard() { return this.ops.dashboard(); }

  /* ---- sports ---- */
  @Get('sports') listSports() { return this.catalog.listSports(); }
  @Post('sports') createSport(@Body() b: unknown) { return this.catalog.createSport(b); }
  @Put('sports/:name') updateSport(@Param('name') name: string, @Body() b: unknown) { return this.catalog.updateSport(name, b); }
  @Delete('sports/:name') deleteSport(@Param('name') name: string) { return this.catalog.deleteSport(name); }

  /* ---- facilities (venues) ---- */
  @Get('venues') listVenues(@Query() q: Q) { return this.catalog.listVenues(q); }
  @Post('venues') createVenue(@Body() b: unknown) { return this.catalog.createVenue(b); }
  @Get('venues/:id') getVenue(@Param('id') id: string) { return this.catalog.getVenue(id); }
  @Put('venues/:id') updateVenue(@Param('id') id: string, @Body() b: unknown) { return this.catalog.updateVenue(id, b); }
  @Delete('venues/:id') deleteVenue(@Param('id') id: string) { return this.catalog.deleteVenue(id); }

  /* ---- courts ---- */
  @Get('courts') listCourts(@Query() q: Q) { return this.catalog.listCourts(q); }
  @Post('venues/:venueId/courts') createCourt(@Param('venueId') venueId: string, @Body() b: unknown) { return this.catalog.createCourt(venueId, b); }
  @Get('courts/:id') getCourt(@Param('id') id: string) { return this.catalog.getCourt(id); }
  @Put('courts/:id') updateCourt(@Param('id') id: string, @Body() b: unknown) { return this.catalog.updateCourt(id, b); }
  @Delete('courts/:id') deleteCourt(@Param('id') id: string) { return this.catalog.deleteCourt(id); }

  /* ---- slots (time + price) ---- */
  @Get('slots') listSlots(@Query() q: Q) { return this.slots.list(q); }
  @Post('courts/:courtId/slots') createSlot(@Param('courtId') courtId: string, @Body() b: unknown) { return this.slots.create(courtId, b); }
  @Post('courts/:courtId/slots/bulk') bulkSlots(@Param('courtId') courtId: string, @Body() b: unknown) { return this.slots.bulk(courtId, b); }
  @Put('slots/:id') updateSlot(@Param('id') id: string, @Body() b: unknown) { return this.slots.update(id, b); }
  @Delete('slots/:id') deleteSlot(@Param('id') id: string) { return this.slots.remove(id); }

  /* ---- bookings ---- */
  @Get('bookings') listBookings(@Query() q: Q) { return this.ops.listBookings(q); }
  @Get('bookings/:id') getBooking(@Param('id') id: string) { return this.ops.getBooking(id); }
  @Post('bookings/:id/cancel') @HttpCode(200) cancelBooking(@Param('id') id: string) { return this.ops.cancelBooking(id); }

  /* ---- customers ---- */
  @Get('users') listUsers(@Query() q: Q) { return this.ops.listUsers(q); }
}
