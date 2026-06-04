import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StoresService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Public listing — every store the chain operates. Customers use this to
   * pick a pickup location and to view contact details / opening hours.
   * `isPaused` + `pauseReason` are exposed so the customer site can display
   * a "Đang tạm nghỉ" banner before the user starts an order.
   */
  findAll() {
    return this.prisma.store.findMany({
      orderBy: { name: 'asc' },
      select: {
        id: true,
        name: true,
        slug: true,
        address: true,
        phone: true,
        lat: true,
        lng: true,
        openingHours: true,
        isPaused: true,
        isPickupPaused: true,
        isDeliveryPaused: true,
        pauseReason: true,
      },
    });
  }

  // ─── Merchant settings ───────────────────────────────────────────────────

  getSettings(storeId: string) {
    return this.prisma.store
      .findUniqueOrThrow({
        where: { id: storeId },
        select: {
          id: true,
          name: true,
          openingHours: true,
          isPaused: true,
          isPickupPaused: true,
          isDeliveryPaused: true,
          pauseReason: true,
          minOrderVnd: true,
          defaultLeadHours: true,
          preparationLeadMinutes: true,
        },
      })
      .catch(() => {
        throw new NotFoundException({ code: 'STORE_NOT_FOUND' });
      });
  }

  async updateSettings(
    storeId: string,
    dto: {
      isPaused?: boolean;
      isPickupPaused?: boolean;
      isDeliveryPaused?: boolean;
      pauseReason?: string;
      minOrderVnd?: number;
      defaultLeadHours?: number;
      openingHours?: Record<string, [string, string][]>;
    },
  ) {
    if (dto.openingHours) {
      this.validateOpeningHours(dto.openingHours);
    }
    const updated = await this.prisma.store.update({
      where: { id: storeId },
      data: {
        isPaused: dto.isPaused,
        isPickupPaused: dto.isPickupPaused,
        isDeliveryPaused: dto.isDeliveryPaused,
        // Allow clearing the reason by passing an empty string.
        pauseReason: dto.pauseReason === undefined
          ? undefined
          : dto.pauseReason.trim().length === 0
            ? null
            : dto.pauseReason.trim(),
        minOrderVnd: dto.minOrderVnd,
        defaultLeadHours: dto.defaultLeadHours,
        openingHours: dto.openingHours as Prisma.InputJsonValue | undefined,
      },
      select: {
        id: true,
        name: true,
        openingHours: true,
        isPaused: true,
        isPickupPaused: true,
        isDeliveryPaused: true,
        pauseReason: true,
        minOrderVnd: true,
        defaultLeadHours: true,
        preparationLeadMinutes: true,
      },
    });
    return updated;
  }

  // ─── Blackout dates ──────────────────────────────────────────────────────

  listBlackouts(storeId: string) {
    return this.prisma.storeBlackoutDate.findMany({
      where: { storeId },
      orderBy: { date: 'asc' },
      select: { id: true, date: true, reason: true },
    });
  }

  async addBlackout(storeId: string, isoDate: string, reason?: string) {
    const date = this.toUtcDate(isoDate);
    try {
      return await this.prisma.storeBlackoutDate.create({
        data: { storeId, date, reason: reason?.trim() || null },
        select: { id: true, date: true, reason: true },
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        // Duplicate is not an error — fetch the existing row and return it.
        return this.prisma.storeBlackoutDate.findFirstOrThrow({
          where: { storeId, date },
          select: { id: true, date: true, reason: true },
        });
      }
      throw e;
    }
  }

  /// Inserts many blackouts in one go, skipping duplicates.
  async addBlackoutsBulk(
    storeId: string,
    dates: { date: string; reason?: string }[],
  ) {
    if (dates.length === 0) return { added: 0 };
    const rows = dates.map((d) => ({
      storeId,
      date: this.toUtcDate(d.date),
      reason: d.reason?.trim() || null,
    }));
    const res = await this.prisma.storeBlackoutDate.createMany({
      data: rows,
      skipDuplicates: true,
    });
    return { added: res.count };
  }

  async removeBlackout(storeId: string, id: string) {
    const found = await this.prisma.storeBlackoutDate.findUnique({
      where: { id },
      select: { storeId: true },
    });
    if (!found || found.storeId !== storeId) {
      throw new NotFoundException({ code: 'BLACKOUT_NOT_FOUND' });
    }
    await this.prisma.storeBlackoutDate.delete({ where: { id } });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Throws BadRequest with a friendly code if the hours map is malformed.
  /// Empty map / null is allowed and treated as "24/7" by order checks.
  private validateOpeningHours(hours: Record<string, [string, string][]>) {
    const validDays = new Set(['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']);
    const hhmm = /^([01]\d|2[0-3]):[0-5]\d$/;
    for (const [day, windows] of Object.entries(hours)) {
      if (!validDays.has(day)) {
        throw new BadRequestException({
          code: 'INVALID_DAY',
          message: `Day "${day}" is not one of mon..sun.`,
        });
      }
      if (!Array.isArray(windows)) {
        throw new BadRequestException({
          code: 'INVALID_HOURS',
          message: `Hours for "${day}" must be an array of [open,close] pairs.`,
        });
      }
      for (const w of windows) {
        if (
          !Array.isArray(w) ||
          w.length !== 2 ||
          typeof w[0] !== 'string' ||
          typeof w[1] !== 'string' ||
          !hhmm.test(w[0]) ||
          !hhmm.test(w[1])
        ) {
          throw new BadRequestException({
            code: 'INVALID_HOURS',
            message: `Each window must be ["HH:MM","HH:MM"]; got ${JSON.stringify(w)}.`,
          });
        }
        const [oh, om] = w[0].split(':').map(Number);
        const [ch, cm] = w[1].split(':').map(Number);
        if (oh * 60 + om >= ch * 60 + cm) {
          throw new BadRequestException({
            code: 'INVALID_HOURS',
            message: `Close (${w[1]}) must be after open (${w[0]}) on ${day}.`,
          });
        }
      }
    }
  }

  /// Parse "YYYY-MM-DD" → UTC-midnight Date so the @db.Date column stores
  /// exactly that calendar day, independent of server timezone.
  private toUtcDate(iso: string): Date {
    const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
    if (!m) {
      throw new BadRequestException({
        code: 'INVALID_DATE',
        message: `Date must be YYYY-MM-DD; got "${iso}".`,
      });
    }
    const [, y, mo, d] = m;
    return new Date(Date.UTC(Number(y), Number(mo) - 1, Number(d)));
  }
}
