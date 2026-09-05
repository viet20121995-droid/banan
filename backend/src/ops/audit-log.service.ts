import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

const RETAIN_DAYS = 180;

@Injectable()
export class AuditLogService {
  private readonly logger = new Logger(AuditLogService.name);

  constructor(private readonly prisma: PrismaService) {}

  async list(opts: {
    q?: string;
    userId?: string;
    from?: string;
    to?: string;
    page: number;
    perPage: number;
  }) {
    const where: Prisma.AuditLogWhereInput = {};
    if (opts.userId) where.userId = opts.userId;
    const q = opts.q?.trim();
    if (q) {
      where.OR = [
        { email: { contains: q, mode: 'insensitive' } },
        { path: { contains: q, mode: 'insensitive' } },
        { ip: { contains: q } },
      ];
    }
    // Dates are VN calendar days: "2026-09-05" covers 00:00–24:00 VN.
    const day = (d: string, endOfDay: boolean) =>
      new Date(`${d}T${endOfDay ? '23:59:59.999' : '00:00:00.000'}+07:00`);
    if (opts.from || opts.to) {
      where.at = {
        ...(opts.from && { gte: day(opts.from, false) }),
        ...(opts.to && { lte: day(opts.to, true) }),
      };
    }
    const [total, items] = await Promise.all([
      this.prisma.auditLog.count({ where }),
      this.prisma.auditLog.findMany({
        where,
        orderBy: { at: 'desc' },
        skip: (opts.page - 1) * opts.perPage,
        take: opts.perPage,
      }),
    ]);
    return { items, meta: { page: opts.page, perPage: opts.perPage, total } };
  }

  /** Half a year of trail is plenty; older rows go at 03:40 every night. */
  @Cron('0 40 3 * * *', { timeZone: 'Asia/Ho_Chi_Minh' })
  async prune(): Promise<void> {
    const cutoff = new Date(Date.now() - RETAIN_DAYS * 86_400_000);
    const res = await this.prisma.auditLog.deleteMany({ where: { at: { lt: cutoff } } });
    if (res.count > 0) this.logger.log(`pruned ${res.count} audit rows older than ${RETAIN_DAYS}d`);
  }
}
