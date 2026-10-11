import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { BeaconsService } from './beacons.service';
import { ClubsService } from './clubs.service';
import { FriendsService } from './friends.service';

type R = { userId: string };
type Q = Record<string, string>;

/** Partners tab: match beacons, friends, clubs. Needs  Authorization: Bearer <accessToken> */
@Controller('partners')
@UseGuards(JwtAuthGuard)
export class PartnersController {
  constructor(
    private readonly beacons: BeaconsService,
    private readonly friends: FriendsService,
    private readonly clubs: ClubsService,
  ) {}

  /* ---- match beacons ---- */
  @Post('beacons') createBeacon(@Req() r: R, @Body() b: unknown) { return this.beacons.create(r.userId, b); }
  @Get('beacons') openBeacons(@Req() r: R, @Query() q: Q) { return this.beacons.listOpen(r.userId, q); }
  @Get('beacons/mine') myBeacons(@Req() r: R, @Query('status') s?: string) { return this.beacons.listMine(r.userId, s ?? 'all'); }
  @Get('beacons/joined') joinedBeacons(@Req() r: R) { return this.beacons.listJoined(r.userId); }
  @Get('beacons/:id') getBeacon(@Req() r: R, @Param('id') id: string) { return this.beacons.get(r.userId, id); }
  @Put('beacons/:id') updateBeacon(@Req() r: R, @Param('id') id: string, @Body() b: unknown) { return this.beacons.update(r.userId, id, b); }
  @Delete('beacons/:id') deleteBeacon(@Req() r: R, @Param('id') id: string) { return this.beacons.remove(r.userId, id); }
  @Post('beacons/:id/join') @HttpCode(200) joinBeacon(@Req() r: R, @Param('id') id: string) { return this.beacons.join(r.userId, id); }
  @Post('beacons/:id/leave') @HttpCode(200) leaveBeacon(@Req() r: R, @Param('id') id: string) { return this.beacons.leave(r.userId, id); }

  /* ---- friends ---- */
  @Get('friends') listFriends(@Req() r: R, @Query('q') q?: string) { return this.friends.list(r.userId, q); }
  @Post('friends') addFriend(@Req() r: R, @Body() b: unknown) { return this.friends.add(r.userId, b); }
  @Delete('friends/:id') removeFriend(@Req() r: R, @Param('id') id: string) { return this.friends.remove(r.userId, id); }

  /* ---- clubs ---- */
  @Post('clubs') createClub(@Req() r: R, @Body() b: unknown) { return this.clubs.create(r.userId, b); }
  @Get('clubs') listClubs(@Req() r: R, @Query() q: Q) { return this.clubs.list(r.userId, q); }
  @Get('clubs/:id') getClub(@Req() r: R, @Param('id') id: string) { return this.clubs.get(r.userId, id); }
  @Put('clubs/:id') updateClub(@Req() r: R, @Param('id') id: string, @Body() b: unknown) { return this.clubs.update(r.userId, id, b); }
  @Delete('clubs/:id') deleteClub(@Req() r: R, @Param('id') id: string) { return this.clubs.remove(r.userId, id); }
  @Post('clubs/:id/join') @HttpCode(200) joinClub(@Req() r: R, @Param('id') id: string) { return this.clubs.join(r.userId, id); }
  @Post('clubs/:id/leave') @HttpCode(200) leaveClub(@Req() r: R, @Param('id') id: string) { return this.clubs.leave(r.userId, id); }
}
