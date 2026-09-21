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
import { PrismaService } from '../../prisma/prisma.service';

interface ErrorBody {
  error: { code: string; message: string; details?: unknown };
}

@Catch()
@Injectable()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  /** Recent checkout rejections per client IP — drives the "customer is stuck" alert. */
  private readonly rejections = new Map<string, number[]>();

  constructor(
    @Optional() private readonly ops?: OpsAlertService,
    @Optional() private readonly prisma?: PrismaService,
  ) {}

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
    // Rejected writes (a checkout that won't go through, a refused coupon…):
    // the access log only has the status, so record WHY. 401/404/429 are noise.
    else if (request.method !== 'GET' && ![401, 404, 429].includes(status)) {
      const who = (request as Request & { user?: AuthPrincipal }).user?.sub ?? 'guest';
      this.logger.warn(
        `${request.method} ${request.url.split('?')[0]} → ${status} ${body.error.code}: ` +
          `${body.error.message} (user ${who})`,
      );
      if (request.method === 'POST' && /\/orders\/?$/.test(request.url.split('?')[0])) {
        this.recordOrderRejection(request, status, body.error, who);
      }
    }

    response.status(status).json({
      ...body,
      // Echo a request id later (M0+1) once we wire pino-http reqId binding.
      path: request.url,
    });
  }

  /**
   * A refused checkout: keep the reason (logs die with the container) and mail
   * ops when one client is refused 3× within 10 minutes — a customer who keeps
   * pressing "Đặt hàng" is a customer about to leave.
   */
  private recordOrderRejection(
    request: Request,
    status: number,
    error: { code: string; message: string },
    userId: string,
  ): void {
    const ip = request.ip ?? 'unknown';
    const userAgent = String(request.headers['user-agent'] ?? '').slice(0, 300);
    void this.prisma?.orderRejection
      .create({
        data: {
          status,
          code: error.code,
          message: error.message.slice(0, 1000),
          userId: userId === 'guest' ? null : userId,
          ip,
          userAgent,
        },
      })
      .catch(() => undefined);

    const now = Date.now();
    const recent = [...(this.rejections.get(ip) ?? []), now].filter((t) => now - t < 10 * 60_000);
    this.rejections.set(ip, recent);
    if (this.rejections.size > 500) this.rejections.clear(); // bounded memory
    if (recent.length >= 3) {
      void this.ops
        ?.alert(`order-reject:${ip}`, 'Khách đang không đặt được hàng', [
          `${recent.length} lần bị từ chối trong 10 phút.`,
          `Lý do gần nhất: ${error.code} — ${error.message}`,
          `Tài khoản: ${userId}`,
          `IP: ${ip}`,
          `Thiết bị: ${userAgent}`,
        ])
        .catch(() => undefined);
    }
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
