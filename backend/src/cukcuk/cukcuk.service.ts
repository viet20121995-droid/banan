import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Prisma } from '@prisma/client';

import { LOYALTY_CONFIG, LoyaltyService } from '../loyalty/loyalty.service';
import { PrismaService } from '../prisma/prisma.service';

import { CUKCUK_KINDS, CukcukKind, normalizePhone, normalizeRecord } from './cukcuk-normalize';
import { CukcukClient } from './cukcuk.client';

export const CUKCUK_KIND_LABEL: Record<CukcukKind, string> = {
  branches: 'Chi nhánh',
  categories: 'Nhóm món',
  items: 'Món / hàng hoá',
  customers: 'Khách hàng',
  invoices: 'Hoá đơn bán',
  orders: 'Đơn đang phục vụ',
};

/// Lower-cased string fields of a row, joined — what the list search matches.
function searchText(row: Record<string, unknown>): string {
  return Object.values(row)
    .filter((v): v is string | number => typeof v === 'string' || typeof v === 'number')
    .map((v) => String(v).toLowerCase())
    .join(' ')
    .slice(0, 2000);
}

/// Datasets that support `LastSyncDate` — after the first full pull only
/// rows changed since the previous successful sync are fetched.
const INCREMENTAL: ReadonlySet<CukcukKind> = new Set(['items', 'customers', 'invoices', 'orders']);

@Injectable()
export class CukcukService {
  private readonly logger = new Logger(CukcukService.name);
  private running = new Set<CukcukKind>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly client: CukcukClient,
    private readonly loyalty: LoyaltyService,
  ) {}

  // ── status ──────────────────────────────────────────────────────────

  async status() {
    const [counts, syncs] = await Promise.all([
      this.prisma.cukcukRecord.groupBy({ by: ['kind'], _count: { _all: true } }),
      this.prisma.cukcukSync.findMany({ orderBy: { startedAt: 'desc' }, take: 60 }),
    ]);
    const countOf = new Map(counts.map((c) => [c.kind, c._count._all]));
    return {
      configured: this.client.configured,
      domain: this.client.domain,
      kinds: CUKCUK_KINDS.map((kind) => {
        const lastOk = syncs.find((s) => s.kind === kind && s.ok === true);
        const last = syncs.find((s) => s.kind === kind);
        return {
          kind,
          label: CUKCUK_KIND_LABEL[kind],
          count: countOf.get(kind) ?? 0,
          running: this.running.has(kind),
          lastSyncAt: lastOk?.finishedAt ?? null,
          lastFetched: lastOk?.fetched ?? 0,
          lastError: last && last.ok === false ? last.error : null,
          lastErrorAt: last && last.ok === false ? last.finishedAt : null,
        };
      }),
    };
  }

  // ── sync ────────────────────────────────────────────────────────────

  async syncAll(startedBy?: string, full = false) {
    const results: { kind: CukcukKind; fetched: number; error: string | null }[] = [];
    for (const kind of CUKCUK_KINDS) {
      try {
        results.push({ kind, fetched: await this.sync(kind, startedBy, full), error: null });
      } catch (err) {
        results.push({ kind, fetched: 0, error: (err as Error).message });
      }
    }
    return results;
  }

  /// Pull one dataset and upsert its rows. Returns how many rows came back.
  /// `full` ignores the last sync date and re-reads everything.
  async sync(kind: CukcukKind, startedBy?: string, full = false): Promise<number> {
    if (this.running.has(kind)) {
      throw new BadRequestException({
        code: 'CUKCUK_SYNC_RUNNING',
        message: `Đang đồng bộ ${CUKCUK_KIND_LABEL[kind]}, chờ xong rồi thử lại.`,
      });
    }
    this.running.add(kind);
    const log = await this.prisma.cukcukSync.create({
      data: { kind, startedBy: startedBy ?? null },
    });
    try {
      const lastOk =
        INCREMENTAL.has(kind) && !full
          ? await this.prisma.cukcukSync.findFirst({
              where: { kind, ok: true },
              orderBy: { finishedAt: 'desc' },
              select: { startedAt: true },
            })
          : null;
      // Overlap by 1h so a clock skew or a row saved mid-sync is not missed.
      const since = lastOk ? new Date(lastOk.startedAt.getTime() - 60 * 60 * 1000) : null;
      const fetched = await this.pull(kind, since);
      await this.prisma.cukcukSync.update({
        where: { id: log.id },
        data: { finishedAt: new Date(), ok: true, fetched },
      });
      this.logger.log(
        `CukCuk ${kind}: ${fetched} rows${since ? ` since ${since.toISOString()}` : ''}`,
      );
      // Fresh counter data → push it onto matching website accounts at once.
      if (kind === 'customers' && fetched > 0) {
        void this.applyCustomers().catch((e: Error) =>
          this.logger.warn(`applyCustomers after sync: ${e.message}`),
        );
      }
      return fetched;
    } catch (err) {
      const message =
        (err as { message?: string; response?: { message?: string } }).response?.message ??
        (err as Error).message;
      await this.prisma.cukcukSync.update({
        where: { id: log.id },
        data: { finishedAt: new Date(), ok: false, error: message.slice(0, 1000) },
      });
      this.logger.warn(`CukCuk ${kind} failed: ${message}`);
      throw err;
    } finally {
      this.running.delete(kind);
    }
  }

  private async pull(kind: CukcukKind, since: Date | null): Promise<number> {
    const save = (rows: Record<string, unknown>[]) => this.upsertRows(kind, rows);
    const lastSync = since ? { LastSyncDate: since.toISOString() } : {};
    switch (kind) {
      case 'branches': {
        const rows = await this.client.get<Record<string, unknown>[]>(
          '/api/v1/branchs/all?includeInactive=true',
        );
        await save(rows ?? []);
        return rows?.length ?? 0;
      }
      case 'categories': {
        const rows = await this.client.get<Record<string, unknown>[]>(
          '/api/v1/categories/list?includeInactive=true',
        );
        await save(rows ?? []);
        return rows?.length ?? 0;
      }
      case 'items':
        return this.client.pageAll(
          '/api/v1/inventoryitems/paging',
          { IncludeInactive: true, ...lastSync },
          save,
        );
      case 'customers':
        return this.client.pageAll(
          '/api/v1/customers/paging',
          { IncludeInactive: true, ...lastSync },
          save,
        );
      case 'invoices':
        return this.client.pageAll(
          '/api/v1/sainvoices/paging',
          { HaveCustomer: false, ...lastSync },
          save,
        );
      case 'orders':
        return this.client.pageAll('/api/v1/orders/paging', { ...lastSync }, save);
    }
  }

  private async upsertRows(kind: CukcukKind, rows: Record<string, unknown>[]): Promise<void> {
    if (rows.length === 0) return;
    await this.prisma.$transaction(
      rows.map((row) => {
        const n = normalizeRecord(kind, row);
        const data = row as Prisma.InputJsonValue;
        const search = searchText(row);
        return this.prisma.cukcukRecord.upsert({
          where: { kind_externalId: { kind, externalId: n.externalId } },
          create: {
            kind,
            externalId: n.externalId,
            label: n.label,
            branchId: n.branchId,
            modifiedAt: n.modifiedAt,
            search,
            data,
          },
          update: { label: n.label, branchId: n.branchId, modifiedAt: n.modifiedAt, search, data },
        });
      }),
    );
  }

  /// Every 30 minutes, when configured. Skips silently when a manual sync of
  /// the same dataset is already running.
  @Cron('*/30 * * * *')
  async scheduledSync(): Promise<void> {
    if (!this.client.configured) return;
    for (const kind of CUKCUK_KINDS) {
      if (this.running.has(kind)) continue;
      try {
        await this.sync(kind, 'cron');
      } catch {
        /* logged in sync() */
      }
    }
  }

  // ── records ─────────────────────────────────────────────────────────

  async list(kind: CukcukKind, q: string | undefined, page: number, perPage: number) {
    const where: Prisma.CukcukRecordWhereInput = {
      kind,
      ...(q && {
        OR: [
          { label: { contains: q, mode: 'insensitive' } },
          { externalId: { contains: q, mode: 'insensitive' } },
          // Phone / code / customer name inside the raw row.
          { search: { contains: q, mode: 'insensitive' } },
        ],
      }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.cukcukRecord.findMany({
        where,
        orderBy: [{ modifiedAt: 'desc' }, { label: 'asc' }],
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.cukcukRecord.count({ where }),
    ]);
    const linked = kind === 'customers' ? await this.linkedUsers(items) : new Map<string, string>();
    return {
      items: items.map((r) => ({
        id: r.id,
        kind: r.kind,
        externalId: r.externalId,
        label: r.label,
        branchId: r.branchId,
        modifiedAt: r.modifiedAt,
        syncedAt: r.syncedAt,
        data: r.data,
        linkedUserId: linked.get(r.id) ?? null,
      })),
      meta: { page, perPage, total },
    };
  }

  async detail(kind: CukcukKind, externalId: string) {
    const rec = await this.prisma.cukcukRecord.findUnique({
      where: { kind_externalId: { kind, externalId } },
    });
    if (!rec) throw new BadRequestException({ code: 'CUKCUK_RECORD_NOT_FOUND' });
    const data = rec.data as Record<string, unknown>;
    // Invoice lines are not in the paging payload — fetch once and cache.
    if (kind === 'invoices' && !data.__detail) {
      try {
        const detail = await this.client.get<unknown>(`/api/v1/sainvoices/detail/${externalId}`);
        const merged = { ...data, __detail: detail } as Prisma.InputJsonValue;
        await this.prisma.cukcukRecord.update({ where: { id: rec.id }, data: { data: merged } });
        return { ...rec, data: merged };
      } catch (err) {
        this.logger.warn(`invoice detail ${externalId}: ${(err as Error).message}`);
      }
    }
    return rec;
  }

  // ── customers → website users ───────────────────────────────────────

  /// Website users (by normalised phone) for a page of CukCuk customers.
  private async linkedUsers(records: { id: string; data: Prisma.JsonValue }[]) {
    const phones = new Map<string, string>(); // phone → record id
    for (const r of records) {
      const p = normalizePhone((r.data as Record<string, unknown>).Tel);
      if (p) phones.set(p, r.id);
    }
    if (phones.size === 0) return new Map<string, string>();
    const users = await this.prisma.user.findMany({
      where: { phone: { in: [...phones.keys()] } },
      select: { id: true, phone: true },
    });
    const out = new Map<string, string>();
    for (const u of users) {
      const rid = u.phone && phones.get(u.phone);
      if (rid) out.set(rid, u.id);
    }
    return out;
  }

  /**
   * Counter customers (by normalised phone) → website accounts. Runs after
   * every customers sync and when a customer registers:
   *   - fills profile gaps (placeholder name, empty birthday / gender / email);
   *   - converts counter spend into Micho at the site's earn rate, crediting
   *     only the growth since the last run (`User.cukcukSpendVnd`), so the
   *     "over 5,000,000 ₫ → 5 % off" rule applies to counter regulars too.
   * Never lowers a balance and never touches the tier directly (the loyalty
   * service derives it from the balance).
   */
  async applyCustomers() {
    const byPhone = await this.customersByPhone();
    if (byPhone.size === 0) return { matched: 0, updated: 0, michoCredited: 0 };
    const users = await this.prisma.user.findMany({
      where: { phone: { in: [...byPhone.keys()] }, role: 'CUSTOMER' },
      select: this.userSelect,
    });
    let updated = 0;
    let michoCredited = 0;
    for (const u of users) {
      const row = byPhone.get(u.phone as string);
      if (!row) continue;
      const r = await this.applyToUser(u, row);
      if (r.updated) updated += 1;
      michoCredited += r.micho;
    }
    return { matched: users.length, updated, michoCredited };
  }

  /// One account (e.g. right after registration).
  async linkUser(userId: string): Promise<void> {
    const u = await this.prisma.user.findUnique({ where: { id: userId }, select: this.userSelect });
    if (!u || u.role !== 'CUSTOMER' || !u.phone) return;
    const rows = await this.customerRows(normalizePhone(u.phone));
    if (rows.length === 0) return;
    await this.applyToUser(u, mergeCustomerRows(rows));
  }

  private readonly userSelect = {
    id: true,
    role: true,
    phone: true,
    fullName: true,
    email: true,
    birthday: true,
    gender: true,
    cukcukSpendVnd: true,
  } as const;

  private async applyToUser(
    u: {
      id: string;
      fullName: string;
      email: string;
      birthday: Date | null;
      gender: string | null;
      cukcukSpendVnd: number;
    },
    row: Record<string, unknown>,
  ): Promise<{ updated: boolean; micho: number }> {
    const patch: Prisma.UserUpdateInput = {};
    const name = typeof row.Name === 'string' ? row.Name.trim() : '';
    if (name && (!u.fullName || /^(khách|guest)/i.test(u.fullName))) patch.fullName = name;
    const bday = typeof row.Birthday === 'string' ? new Date(row.Birthday) : null;
    if (!u.birthday && bday && !Number.isNaN(bday.getTime())) patch.birthday = bday;
    if (!u.gender && (row.Gender === 1 || row.Gender === 0)) {
      patch.gender = row.Gender === 1 ? 'MALE' : 'FEMALE';
    }
    const email = typeof row.Email === 'string' ? row.Email.trim().toLowerCase() : '';
    if (email && u.email.endsWith('@banan.local') && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      const taken = await this.prisma.user.findUnique({ where: { email }, select: { id: true } });
      if (!taken) patch.email = email;
    }
    // Micho for counter spend: whole-Micho growth since the last credit.
    const total = Math.max(0, Math.floor(Number(row.TotalAmount) || 0));
    const rate = LOYALTY_CONFIG.earnRatePerVnd;
    const delta = Math.floor(total / rate) - Math.floor(u.cukcukSpendVnd / rate);
    let micho = 0;
    if (total > u.cukcukSpendVnd) {
      if (delta > 0) {
        await this.loyalty.adminAdjust({
          userId: u.id,
          delta,
          reason: `Chi tiêu tại quầy ${total.toLocaleString('vi-VN')}₫ (CukCuk)`,
        });
        micho = delta;
      }
      patch.cukcukSpendVnd = total;
    }
    if (Object.keys(patch).length === 0) return { updated: false, micho };
    await this.prisma.user.update({ where: { id: u.id }, data: patch });
    return { updated: true, micho };
  }

  /// All synced counter customers keyed by normalised phone; duplicates of
  /// the same phone are merged (spend summed) so nobody is short-changed.
  private async customersByPhone(): Promise<Map<string, Record<string, unknown>>> {
    const records = await this.prisma.cukcukRecord.findMany({
      where: { kind: 'customers' },
      select: { data: true },
    });
    const groups = new Map<string, Record<string, unknown>[]>();
    for (const r of records) {
      const row = r.data as Record<string, unknown>;
      const p = normalizePhone(row.Tel) ?? normalizePhone(row.NormalizedTel);
      if (!p) continue;
      (groups.get(p) ?? groups.set(p, []).get(p)!).push(row);
    }
    return new Map([...groups].map(([p, rows]) => [p, mergeCustomerRows(rows)]));
  }

  private async customerRows(phone: string | null): Promise<Record<string, unknown>[]> {
    if (!phone) return [];
    const intl = `84${phone.slice(1)}`;
    const records = await this.prisma.cukcukRecord.findMany({
      where: {
        kind: 'customers',
        OR: [
          { data: { path: ['Tel'], equals: phone } },
          { data: { path: ['NormalizedTel'], equals: intl } },
          { data: { path: ['Tel'], equals: `+${intl}` } },
        ],
      },
      select: { data: true },
    });
    return records.map((r) => r.data as Record<string, unknown>);
  }

  /// Public "Tra cứu chi tiêu" — totals only, masked name.
  async lookupByPhone(phone: string) {
    const rows = await this.customerRows(phone);
    const account = await this.prisma.user.findFirst({
      where: { phone, role: 'CUSTOMER' },
      select: { id: true },
    });
    const rate = LOYALTY_CONFIG.earnRatePerVnd;
    const thresholdVnd = LOYALTY_CONFIG.michoDiscountThreshold * rate;
    if (rows.length === 0) {
      return {
        found: false,
        hasAccount: Boolean(account),
        totalSpendVnd: 0,
        micho: 0,
        discountEligible: false,
        discountRate: LOYALTY_CONFIG.michoDiscountRate,
        discountThresholdVnd: thresholdVnd,
        earnRatePerVnd: rate,
        invoiceCount: 0,
        lastVisitAt: null,
      };
    }
    const merged = mergeCustomerRows(rows);
    const total = Math.max(0, Math.floor(Number(merged.TotalAmount) || 0));
    const micho = Math.floor(total / rate);
    const intl = `84${phone.slice(1)}`;
    const invoiceWhere: Prisma.CukcukRecordWhereInput = {
      kind: 'invoices',
      OR: [
        { data: { path: ['CustomerTel'], equals: phone } },
        { data: { path: ['CustomerTel'], equals: intl } },
      ],
    };
    const [invoiceCount, last] = await Promise.all([
      this.prisma.cukcukRecord.count({ where: invoiceWhere }),
      this.prisma.cukcukRecord.findFirst({
        where: invoiceWhere,
        orderBy: { modifiedAt: 'desc' },
        select: { data: true },
      }),
    ]);
    const lastRaw = (last?.data as Record<string, unknown> | undefined)?.RefDate;
    return {
      found: true,
      hasAccount: Boolean(account),
      name: maskName(typeof merged.Name === 'string' ? merged.Name : ''),
      totalSpendVnd: total,
      micho,
      discountEligible: micho >= LOYALTY_CONFIG.michoDiscountThreshold,
      discountRate: LOYALTY_CONFIG.michoDiscountRate,
      discountThresholdVnd: thresholdVnd,
      earnRatePerVnd: rate,
      invoiceCount,
      lastVisitAt: typeof lastRaw === 'string' ? lastRaw : null,
    };
  }
}

/// Several CukCuk rows can share a phone (re-created customers): keep the
/// most complete profile and sum the spend.
export function mergeCustomerRows(rows: Record<string, unknown>[]): Record<string, unknown> {
  if (rows.length === 1) return rows[0];
  const base = { ...rows[0] };
  let total = 0;
  for (const r of rows) {
    total += Number(r.TotalAmount) || 0;
    for (const k of ['Name', 'Email', 'Birthday', 'Gender', 'Address']) {
      const v = r[k];
      if ((base[k] === undefined || base[k] === null || base[k] === '') && v) base[k] = v;
    }
  }
  base.TotalAmount = total;
  return base;
}

/// "Nguyễn Văn An" → "Ng*** V** A*" — enough to recognise yourself, not
/// enough for a stranger holding just the phone number.
export function maskName(name: string): string | null {
  const t = name.trim();
  if (!t) return null;
  return t
    .split(/\s+/)
    .map((w) =>
      w.length <= 1
        ? w
        : w.slice(0, w.length > 3 ? 2 : 1) +
          '*'.repeat(Math.max(1, w.length - (w.length > 3 ? 2 : 1))),
    )
    .join(' ');
}
