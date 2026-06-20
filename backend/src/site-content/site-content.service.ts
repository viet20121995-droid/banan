import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import { defaultFor, SITE_CONTENT_KEYS, type SiteContentKey } from './defaults';

@Injectable()
export class SiteContentService {
  constructor(private readonly prisma: PrismaService) {}

  private assertKey(key: string): SiteContentKey {
    if (!(SITE_CONTENT_KEYS as readonly string[]).includes(key)) {
      throw new BadRequestException({
        code: 'UNKNOWN_CONTENT_KEY',
        message: `Unknown content key: ${key}`,
      });
    }
    return key as SiteContentKey;
  }

  /**
   * Returns the stored content, or the built-in default when none exists.
   * The payload field is named `content` (not `data`) so the response goes
   * through the standard `{ data: … }` envelope instead of being passed
   * through verbatim (the interceptor short-circuits on a top-level `data`).
   */
  async get(
    rawKey: string,
  ): Promise<{ key: string; content: unknown; isDefault: boolean; updatedAt: Date | null }> {
    const key = this.assertKey(rawKey);
    const row = await this.prisma.siteContent.findUnique({ where: { key } });
    if (!row) {
      return { key, content: defaultFor(key), isDefault: true, updatedAt: null };
    }
    return {
      key,
      content: row.data,
      isDefault: false,
      updatedAt: row.updatedAt,
    };
  }

  /** Upsert merchant-edited content after light shape validation. */
  async update(rawKey: string, data: unknown) {
    const key = this.assertKey(rawKey);
    const clean = this.validateShape(key, data);
    const row = await this.prisma.siteContent.upsert({
      where: { key },
      create: { key, data: clean as Prisma.InputJsonValue },
      update: { data: clean as Prisma.InputJsonValue },
    });
    return {
      key,
      content: row.data,
      isDefault: false,
      updatedAt: row.updatedAt,
    };
  }

  /** Normalises + validates the payload per key; throws on bad shape. */
  private validateShape(key: SiteContentKey, data: unknown): unknown {
    if (typeof data !== 'object' || data === null) {
      throw new BadRequestException({ code: 'INVALID_CONTENT' });
    }
    const d = data as Record<string, unknown>;
    if (key === 'faq') {
      const items = Array.isArray(d.items) ? d.items : [];
      const clean = items
        .map((it) => {
          const o = (it ?? {}) as Record<string, unknown>;
          return {
            q: String(o.q ?? '').trim(),
            a: String(o.a ?? '').trim(),
          };
        })
        .filter((it) => it.q.length > 0 || it.a.length > 0);
      return { items: clean };
    }
    // about
    const sections = Array.isArray(d.sections) ? d.sections : [];
    const cleanSections = sections
      .map((s) => {
        const o = (s ?? {}) as Record<string, unknown>;
        return {
          heading: String(o.heading ?? '').trim(),
          body: String(o.body ?? '').trim(),
        };
      })
      .filter((s) => s.heading.length > 0 || s.body.length > 0);
    return {
      intro: String(d.intro ?? '').trim(),
      sections: cleanSections,
    };
  }
}
