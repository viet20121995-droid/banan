import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

/**
 * Wraps every successful response in `{ data, meta? }`. Errors are wrapped by
 * AllExceptionsFilter into `{ error: { code, message, details? } }`.
 */
@Injectable()
export class EnvelopeInterceptor implements NestInterceptor {
  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      map((value) => {
        if (value && typeof value === 'object' && 'data' in value) {
          return value;
        }
        if (value && typeof value === 'object' && 'meta' in value && 'items' in value) {
          // Preserve any extra top-level keys (e.g. `summary` from reviews
          // listing) so callers can rely on them.
          const { items, meta, ...rest } = value as {
            items: unknown;
            meta: unknown;
            [k: string]: unknown;
          };
          return { data: items, meta, ...rest };
        }
        return { data: value };
      }),
    );
  }
}
