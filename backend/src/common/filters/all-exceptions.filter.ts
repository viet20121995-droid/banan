import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

interface ErrorBody {
  error: { code: string; message: string; details?: unknown };
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
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

    response.status(status).json({
      ...body,
      // Echo a request id later (M0+1) once we wire pino-http reqId binding.
      path: request.url,
    });
  }
}
