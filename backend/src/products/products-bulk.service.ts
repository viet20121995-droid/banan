import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { BundlesService } from '../bundles/bundles.service';
import { lockCatalogBundles } from '../common/catalog-lock';
import { PrismaService } from '../prisma/prisma.service';

import type { BulkImportDto, BulkPriceDto } from './dto/bulk.dto';

/** Vietnamese-aware slugify: strips diacritics → lower-kebab ASCII. */
function slugify(input: string): string {
  return input
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '') // combining diacritical marks
    .replace(/[đĐ]/g, 'd')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

export interface BulkImportResult {
  created: number;
  skipped: number;
  errors: Array<{ row: number; name: string; error: string }>;
}

export interface BulkPriceResult {
  matched: number;
  updated: number;
  dryRun: boolean;
  sample: Array<{ name: string; from: number; to: number }>;
}

@Injectable()
export class ProductsBulkService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly bundles: BundlesService,
  ) {}

  /**
   * CSV product import (create-only). Each row is upserted-by-creation: an
   * existing [storeId, slug] is skipped (not overwritten) so a re-run is
   * safe. Every new product gets a single "Default · Original" variant so
   * the order-item shape stays uniform.
   */
  async bulkImport(storeId: string, dto: BulkImportDto): Promise<BulkImportResult> {
    const cats = await this.prisma.category.findMany({
      select: { id: true, name: true },
    });
    const byId = new Map(cats.map((c) => [c.id, c]));
    const byName = new Map(cats.map((c) => [c.name.toLowerCase().trim(), c]));

    let created = 0;
    let skipped = 0;
    const errors: BulkImportResult['errors'] = [];

    for (let i = 0; i < dto.rows.length; i++) {
      const row = dto.rows[i];
      const rowNo = i + 1;
      const name = row.name?.trim();
      if (!name) {
        errors.push({ row: rowNo, name: '', error: 'NAME_REQUIRED' });
        continue;
      }
      const cat = row.categoryId
        ? byId.get(row.categoryId)
        : row.categoryName
          ? byName.get(row.categoryName.toLowerCase().trim())
          : undefined;
      if (!cat) {
        errors.push({ row: rowNo, name, error: 'CATEGORY_NOT_FOUND' });
        continue;
      }
      const slug = row.slug?.trim() || slugify(name) || `sp-${rowNo}`;

      const existing = await this.prisma.product.findUnique({
        where: { storeId_slug: { storeId, slug } },
        select: { id: true },
      });
      if (existing) {
        skipped++;
        continue;
      }

      // Also skip when a product with this NAME already exists (a different
      // slug for the same cake would otherwise create a same-name duplicate
      // that shows twice on the storefront — Product is unique on slug, not
      // name). Keeps re-imports with renamed slugs idempotent.
      const nameClash = await this.prisma.product.findFirst({
        where: { storeId, name: { equals: name, mode: 'insensitive' } },
        select: { id: true },
      });
      if (nameClash) {
        skipped++;
        continue;
      }

      try {
        await this.prisma.product.create({
          data: {
            storeId,
            categoryId: cat.id,
            name,
            slug,
            description: row.description?.trim() || name,
            basePrice: new Prisma.Decimal(row.basePrice),
            images: row.imageUrl?.trim() ? [row.imageUrl.trim()] : [],
            variants: {
              create: [{ size: 'Default', flavor: 'Original' }],
            },
          },
        });
        created++;
      } catch (e) {
        errors.push({
          row: rowNo,
          name,
          error: e instanceof Error ? e.message : 'CREATE_FAILED',
        });
      }
    }

    return { created, skipped, errors };
  }

  /**
   * Bulk price adjustment over all / a category / a collection. Percent or
   * fixed delta, never below 0, optional rounding. `dryRun` returns the
   * preview without writing.
   */
  async bulkPrice(dto: BulkPriceDto): Promise<BulkPriceResult> {
    const storeId = await this.catalogStoreId();

    let where: Prisma.ProductWhereInput = { storeId };
    if (dto.scope === 'category') {
      if (!dto.categoryId) {
        throw new BadRequestException({ code: 'CATEGORY_REQUIRED' });
      }
      where = { storeId, categoryId: dto.categoryId };
    } else if (dto.scope === 'collection') {
      if (!dto.collectionSlug) {
        throw new BadRequestException({ code: 'COLLECTION_REQUIRED' });
      }
      // Relational filter instead of a pre-resolved id list — membership is
      // evaluated when the query runs (inside the tx for the real run), so a
      // concurrent collection edit can't make us re-price a just-removed product
      // or skip a just-added one.
      where = {
        storeId,
        collectionItems: { some: { collection: { slug: dto.collectionSlug } } },
      };
    }

    const compute = (cur: number): number => {
      let next = dto.mode === 'percent' ? cur * (1 + dto.amount / 100) : cur + dto.amount;
      if (next < 0) next = 0;
      if (dto.roundTo && dto.roundTo > 0) {
        next = Math.round(next / dto.roundTo) * dto.roundTo;
      }
      return Math.round(next * 100) / 100;
    };
    type Row = { id: string; name: string; basePrice: Prisma.Decimal };
    const plan = (products: Row[]) =>
      products.map((p) => ({
        id: p.id,
        name: p.name,
        from: Number(p.basePrice),
        to: compute(Number(p.basePrice)),
      }));
    const result = (planned: ReturnType<typeof plan>, dryRun: boolean): BulkPriceResult => ({
      matched: planned.length,
      updated: dryRun ? 0 : planned.length,
      dryRun,
      sample: planned.slice(0, 10).map((p) => ({
        name: p.name,
        from: p.from,
        to: p.to,
      })),
    });

    if (dto.dryRun === true) {
      const products = await this.prisma.product.findMany({
        where,
        select: { id: true, name: true, basePrice: true },
      });
      return result(plan(products), true);
    }

    // Real run: READ + compute + WRITE inside one locked transaction, so a
    // concurrent product edit can't commit between the read and the write and
    // get overwritten with a price computed from the stale snapshot. An explicit
    // (generous) timeout is set because the coarse lock + a large catalog can
    // exceed Prisma's 5s interactive-tx default.
    return this.prisma.$transaction(
      async (tx) => {
        // Coarse lock vs concurrent product/combo writes; the post-update combo
        // re-validation then sees stable membership.
        await lockCatalogBundles(tx);
        const products = await tx.product.findMany({
          where,
          select: { id: true, name: true, basePrice: true },
        });
        const planned = plan(products);
        // Lock affected combos before writing the product rows.
        const lockedBundles = await this.bundles.lockActiveBundlesForProducts(
          tx,
          planned.map((p) => p.id),
        );
        // Batch the writes: group by target price so the update is a handful of
        // updateMany calls (one per distinct price) instead of one round-trip
        // per product — keeps a large catalog well under the tx timeout.
        const byTarget = new Map<number, string[]>();
        for (const p of planned) {
          const arr = byTarget.get(p.to);
          if (arr) arr.push(p.id);
          else byTarget.set(p.to, [p.id]);
        }
        for (const [to, idsForPrice] of byTarget) {
          await tx.product.updateMany({
            where: { id: { in: idsForPrice } },
            data: { basePrice: new Prisma.Decimal(to) },
          });
        }
        // A price change can push a combo above its à-la-carte sum — deactivate
        // any of the locked combos that no longer validate.
        await this.bundles.deactivateInvalidBundles(tx, lockedBundles);
        return result(planned, false);
      },
      { timeout: 120_000, maxWait: 15_000 },
    );
  }

  private async catalogStoreId(): Promise<string> {
    const primary = await this.prisma.store.findFirst({
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!primary) throw new BadRequestException({ code: 'NO_STORE' });
    return primary.id;
  }
}
