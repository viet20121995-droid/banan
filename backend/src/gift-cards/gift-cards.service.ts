import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomInt } from 'node:crypto';

import { PrismaService } from '../prisma/prisma.service';

// Unambiguous charset (no 0/O/1/I) for human-readable codes.
const ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

function randomChunk(n: number): string {
  let s = '';
  for (let i = 0; i < n; i++) s += ALPHABET[randomInt(ALPHABET.length)];
  return s;
}

@Injectable()
export class GiftCardsService {
  constructor(private readonly prisma: PrismaService) {}

  private async uniqueCode(): Promise<string> {
    for (let attempt = 0; attempt < 6; attempt++) {
      const code = `BNGC-${randomChunk(4)}-${randomChunk(4)}`;
      const clash = await this.prisma.giftCard.findUnique({ where: { code } });
      if (!clash) return code;
    }
    throw new BadRequestException({ code: 'GIFT_CARD_CODE_CLASH' });
  }

  /** Admin issues a card with a starting value. */
  async issue(args: { valueVnd: number; expiresAt?: string; note?: string; issuedById?: string }) {
    if (!args.valueVnd || args.valueVnd < 1000) {
      throw new BadRequestException({
        code: 'GIFT_CARD_VALUE_INVALID',
        message: 'Mệnh giá tối thiểu 1.000₫.',
      });
    }
    const code = await this.uniqueCode();
    return this.prisma.giftCard.create({
      data: {
        code,
        initialVnd: Math.round(args.valueVnd),
        balanceVnd: Math.round(args.valueVnd),
        expiresAt: args.expiresAt ? new Date(args.expiresAt) : null,
        note: args.note?.trim() || null,
        issuedById: args.issuedById ?? null,
      },
    });
  }

  async list() {
    return this.prisma.giftCard.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async deactivate(id: string) {
    const card = await this.prisma.giftCard.findUnique({ where: { id } });
    if (!card) throw new NotFoundException({ code: 'GIFT_CARD_NOT_FOUND' });
    return this.prisma.giftCard.update({
      where: { id },
      data: { isActive: !card.isActive },
    });
  }

  /** Public — checked before checkout so the customer sees the live balance. */
  async validate(rawCode: string) {
    const code = rawCode.trim().toUpperCase();
    const card = await this.prisma.giftCard.findUnique({ where: { code } });
    if (!card) {
      return { valid: false, reason: 'NOT_FOUND' as const };
    }
    const expired = card.expiresAt != null && card.expiresAt.getTime() < Date.now();
    if (!card.isActive) return { valid: false, reason: 'INACTIVE' as const };
    if (expired) return { valid: false, reason: 'EXPIRED' as const };
    if (card.balanceVnd <= 0) return { valid: false, reason: 'EMPTY' as const };
    return {
      valid: true as const,
      code: card.code,
      balanceVnd: card.balanceVnd,
      expiresAt: card.expiresAt?.toISOString() ?? null,
    };
  }
}
