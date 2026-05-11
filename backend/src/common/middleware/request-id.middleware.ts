import { Injectable, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'node:crypto';

// We tag the Express Request with our own request id. Express types are
// loose enough that we just cast at the use sites — augmenting the
// `express-serve-static-core` module type isn't reachable here without a
// direct dep, so we keep the typing local and unobtrusive.
type WithId = { id?: string };

/**
 * Reads `x-request-id` from the inbound headers (or generates one), exposes
 * it back on the response, and stores it on `req.id` so pino's `genReqId`
 * picks it up and every log line for that request can be correlated.
 */
@Injectable()
export class RequestIdMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction): void {
    const incoming = req.headers['x-request-id'];
    const id = (Array.isArray(incoming) ? incoming[0] : incoming) ?? randomUUID();
    (req as Request & WithId).id = id;
    res.setHeader('x-request-id', id);
    next();
  }
}
