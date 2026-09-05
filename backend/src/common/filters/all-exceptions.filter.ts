import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  Optional,
} from '@nestjs/common';
import { Request, Response } from 'express';

import type { AuthPrincipal } from '../../auth/types/jwt-payload';
import { OpsAlertService } from '../../ops/ops-alert.service';

interface ErrorBody {
  error: { code: string; message: string; details?: unknown };
}

@Catch()
@Injectable()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  constructor(@Optional() private readonly ops?: OpsAlertService) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    if (host.getType() !== 'http') {
      // Socket / cron errors have no HTTP response to write; just record.
      this.logger.error(
        exception instanceof Error ? exception.message : String(exception),
        exception instanceof Error ? exception.stack : undefined,
      );
      return;
    }
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let body: ErrorBody = {
      error: { code: 'INTERNAL', message: 'Internal server error' },
    };

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        body = { error: { code: exception.name, message: res } };
      } else if (typeof res === 'object' && res !== null) {
        const obj = res as { code?: string; message?: string | string[]; details?: unknown };
        body = {
          error: {
            code: obj.code ?? exception.name,
            message: Array.isArray(obj.message)
              ? obj.message.join('; ')
              : (obj.message ?? exception.message),
            details: obj.details,
          },
        };
      }
    } else if (exception instanceof Error) {
      // Log the full error server-side, but never leak internal details
      // (Prisma/provider/runtime messages) to the client — keep the generic
      // INTERNAL body initialised above.
      this.logger.error(exception.message, exception.stack);
    } else {
      this.logger.error('Unknown exception type', String(exception));
    }

    if (status >= 500) this.notifyOps(exception, request, status);

    response.status(status).json({
      ...body,
      // Echo a request id later (M0+1) once we wire pino-http reqId binding.
      path: request.url,
    });
  }

  /** Mail ops about a 5xx — deduped in OpsAlertService, never throws. */
  private notifyOps(exception: unknown, request: Request, status: number): void {
    if (!this.ops) return;
    const req = request as Request & { user?: AuthPrincipal; id?: string };
    const err = exception instanceof Error ? exception : new Error(String(exception));
    const route = `${request.method} ${request.url.split('?')[0]}`;
    const stack = (err.stack ?? '').split('\n').slice(0, 8).join('\n');
    void this.ops
      .alert(`5xx:${route}:${err.message}`, `API ${status} · ${route}`, [
        `Lỗi: ${err.message}`,
        `Request: ${request.method} ${request.url}`,
        `Request id: ${req.id ?? '-'}`,
        `Người dùng: ${req.user ? `${req.user.email} (${req.user.role})` : 'ẩn danh'}`,
        `Thời điểm: ${new Date().toISOString()}`,
        '',
        stack,
      ])
      .catch(() => undefined);
  }
}
