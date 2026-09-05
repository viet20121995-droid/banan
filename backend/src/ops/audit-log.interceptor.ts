import {
  CallHandler,
  ExecutionContext,
  HttpException,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import type { Request, Response } from 'express';
import { Observable, throwError } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';

import type { AuthPrincipal } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Staff action trail. One admin login is shared, so the log is what says
 * who did what: every mutating request (POST/PATCH/PUT/DELETE) by a
 * non-customer user is written with time, account, IP, browser, path,
 * status and a redacted copy of the body. Logins are recorded too (the
 * request has no user yet — the email comes from the body). Writes are
 * fire-and-forget: the log never slows or fails a request.
 */
const MUTATING = new Set(['POST', 'PATCH', 'PUT', 'DELETE']);
const SKIP = [/\/me\/notifications\//, /\/me\/devices/, /\/auth\/refresh/, /\/auth\/logout/];
const LOGIN = /\/auth\/login$/;
const SECRET_KEY = /pass|token|secret|otp|checksum|authorization/i;
const BODY_LIMIT = 4000;

export function redactBody(value: unknown, depth = 0): unknown {
  if (depth > 6) return '[deep]';
  if (Array.isArray(value)) return value.slice(0, 50).map((v) => redactBody(v, depth + 1));
  if (value && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = SECRET_KEY.test(k) ? '[redacted]' : redactBody(v, depth + 1);
    }
    return out;
  }
  if (typeof value === 'string' && value.length > 500) return `${value.slice(0, 500)}…`;
  return value;
}

type AuditReq = Request & { user?: AuthPrincipal; id?: string };

@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AuditLogInterceptor.name);

  constructor(private readonly prisma: PrismaService) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (ctx.getType() !== 'http') return next.handle();
    const req = ctx.switchToHttp().getRequest<AuditReq>();
    if (!MUTATING.has(req.method)) return next.handle();
    // Query strings are dropped: a token or key in the URL must not end up
    // in the trail.
    const path = (req.originalUrl ?? req.url).split('?')[0];
    const user = req.user;
    const login = !user && LOGIN.test(path);
    if (!login && (!user || user.role === 'CUSTOMER')) return next.handle();
    if (SKIP.some((re) => re.test(path))) return next.handle();

    const started = Date.now();
    const body = req.body as Record<string, unknown> | undefined;
    const write = (status: number) => {
      const redacted = redactBody(body);
      const text = JSON.stringify(redacted ?? null);
      const data: Prisma.AuditLogCreateInput = {
        userId: user?.sub ?? null,
        email: user?.email ?? (typeof body?.email === 'string' ? body.email : null),
        role: user?.role ?? (login ? 'LOGIN' : null),
        method: req.method,
        path: path.slice(0, 500),
        status,
        ip: clientIp(req),
        userAgent: (req.headers['user-agent'] ?? '').toString().slice(0, 300) || null,
        requestId: req.id ?? null,
        durationMs: Date.now() - started,
        body:
          text.length > BODY_LIMIT
            ? ({ truncated: true, head: text.slice(0, BODY_LIMIT) } as Prisma.InputJsonValue)
            : (redacted as Prisma.InputJsonValue),
      };
      void this.prisma.auditLog
        .create({ data })
        .catch((e: unknown) => this.logger.warn(`audit write failed: ${(e as Error).message}`));
    };

    return next.handle().pipe(
      tap(() => write(ctx.switchToHttp().getResponse<Response>().statusCode)),
      catchError((err: unknown) => {
        write(err instanceof HttpException ? err.getStatus() : 500);
        return throwError(() => err);
      }),
    );
  }
}

function clientIp(req: Request): string | null {
  const fwd = req.headers['x-forwarded-for'];
  const first = (Array.isArray(fwd) ? fwd[0] : fwd)?.split(',')[0]?.trim();
  return first || req.ip || null;
}
