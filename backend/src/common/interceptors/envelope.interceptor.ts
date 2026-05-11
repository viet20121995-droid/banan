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
          const { items, meta } = value as { items: unknown; meta: unknown };
          return { data: items, meta };
        }
        return { data: value };
      }),
    );
  }
}
