import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import type { Request } from 'express';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

import { RealtimeGateway } from '../../realtime/realtime.gateway';

const MUTATING = new Set(['POST', 'PATCH', 'PUT', 'DELETE']);

// Path substrings whose successful mutations affect what customers browse.
const CATALOG_PATHS = [
  '/products',
  '/merchant/collections',
  '/merchant/banners',
  '/merchant/bundles',
  '/categories',
];
// Chain-wide config the customer app renders (fees, popup, display flags,
// marketing programs, store hours/pause, editable pages).
const CONFIG_PATHS = [
  '/geo/delivery-config',
  '/promo-popup',
  '/display-config',
  '/merchant/marketing',
  '/merchant/store',
  '/merchant/site-content',
];

/**
 * Realtime catalog sync (M11). After any successful merchant write that
 * changes what customers see, broadcast a lightweight event to the `public`
 * room. Every connected client (guest or logged-in, web or mobile) then
 * invalidates the matching providers and refetches — no manual refresh.
 *
 * One interceptor instead of wiring 10 services; non-mutating reads and
 * unrelated paths (orders, auth, …) are ignored.
 */
@Injectable()
export class CatalogBroadcastInterceptor implements NestInterceptor {
  constructor(private readonly realtime: RealtimeGateway) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<Request>();
    const method = req.method;
    const url = req.originalUrl || req.url || '';

    return next.handle().pipe(
      tap(() => {
        if (!MUTATING.has(method)) return;
        if (CATALOG_PATHS.some((p) => url.includes(p))) {
          this.realtime.emit(['public'], 'catalog.changed', {
            at: new Date().toISOString(),
          });
        } else if (CONFIG_PATHS.some((p) => url.includes(p))) {
          this.realtime.emit(['public'], 'config.changed', {
            at: new Date().toISOString(),
          });
        }
      }),
    );
  }
}
