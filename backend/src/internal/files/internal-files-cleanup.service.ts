import { readdir, stat, unlink } from 'node:fs/promises';
import { join } from 'node:path';

import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../../prisma/prisma.service';

import { ensurePrivateDir, isPrivateFileName } from './internal-files.util';

/** A file must be at least this old before it can be judged an orphan —
 *  covers upload→attach in-flight windows and every delivery retry. */
const GRACE_MS = 24 * 3600_000;

/**
 * Daily sweep of `uploads-private/`: deletes files no DB row references any
 * more (evidence removed, or upload succeeded but attach failed). Complements
 * the inline unlink in removeEvidence — that one is best-effort only.
 */
@Injectable()
export class InternalFilesCleanupService {
  private readonly logger = new Logger(InternalFilesCleanupService.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async sweepOrphans(): Promise<void> {
    try {
      const removed = await this.removeOrphanFiles(new Date());
      if (removed > 0) this.logger.log(`Removed ${removed} orphaned private file(s)`);
    } catch (err) {
      this.logger.error(`Orphan sweep failed: ${(err as Error).message}`);
    }
  }

  /** Returns how many files were deleted. Split out for tests. */
  async removeOrphanFiles(now: Date): Promise<number> {
    const dir = ensurePrivateDir();
    const names = await readdir(dir);
    const candidates: string[] = [];
    for (const name of names) {
      if (!isPrivateFileName(name)) continue; // never touch foreign files
      const info = await stat(join(dir, name));
      if (now.getTime() - info.mtimeMs >= GRACE_MS) candidates.push(name);
    }
    if (candidates.length === 0) return 0;

    const [qc, ms, training] = await Promise.all([
      this.prisma.qcEvidence.findMany({
        where: { url: { in: candidates } },
        select: { url: true },
      }),
      this.prisma.msEvidence.findMany({
        where: { url: { in: candidates } },
        select: { url: true },
      }),
      this.prisma.trainingMaterial.findMany({
        where: { url: { in: candidates } },
        select: { url: true },
      }),
    ]);
    const referenced = new Set(
      [...qc, ...ms, ...training].map((r) => r.url).filter((u): u is string => u != null),
    );

    let removed = 0;
    for (const name of candidates) {
      if (referenced.has(name)) continue;
      try {
        await unlink(join(dir, name));
        removed++;
      } catch (err) {
        this.logger.warn(`Could not remove orphan ${name}: ${(err as Error).message}`);
      }
    }
    return removed;
  }
}
