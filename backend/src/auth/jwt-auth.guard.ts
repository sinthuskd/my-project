import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { AuthService } from './auth.service';

/** @UseGuards(JwtAuthGuard) on any route that needs a logged-in user. Sets req.userId. */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    req.userId = this.auth.userIdFromHeader(req.headers['authorization']);
    return true;
  }
}
