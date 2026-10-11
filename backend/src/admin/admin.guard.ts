import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { HttpError } from '../common/http-error';
import { UsersRepo } from '../users/users.repo';

/** @UseGuards(AdminGuard): valid token AND users.role = 'admin' (checked in the database on every call). */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private readonly auth: AuthService, private readonly users: UsersRepo) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    const id = this.auth.userIdFromHeader(req.headers['authorization']);
    const user = await this.users.findById(id);
    if (!user || user.role !== 'admin') throw new HttpError(403, 'Admin access only');
    req.userId = id;
    return true;
  }
}
