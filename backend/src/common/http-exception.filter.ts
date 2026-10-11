import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from '@nestjs/common';
import { HttpError } from './http-error';

/** Every error leaves the API as JSON: { statusCode, message, ...extra } */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse();

    if (exception instanceof HttpError) {
      res
        .status(exception.status)
        .json({ statusCode: exception.status, message: exception.message, ...exception.extra });
      return;
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const body = exception.getResponse();
      res.status(status).json(typeof body === 'string' ? { statusCode: status, message: body } : body);
      return;
    }

    // Express/body-parser errors (malformed JSON, payload too large ...) carry their own 4xx status
    const e = exception as { status?: unknown; type?: string; message?: string };
    if (typeof e?.status === 'number' && e.status >= 400 && e.status < 500) {
      const message = e.type === 'entity.parse.failed' ? 'Request body is not valid JSON'
        : e.type === 'entity.too.large' ? 'Request body is too large' : e.message || 'Bad request';
      res.status(e.status).json({ statusCode: e.status, message });
      return;
    }

    console.error('[unhandled]', exception);
    res.status(500).json({ statusCode: 500, message: 'Internal server error' });
  }
}
