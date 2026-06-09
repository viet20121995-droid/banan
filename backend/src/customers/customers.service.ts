import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CouponType, Prisma, Role } from '@prisma/client';
import bcrypt from 'bcrypt';
import { randomBytes } from 'node:crypto';

import { LoyaltyService } from '../loyalty/loyalty.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

interface ListOpts {
  q?: string;
  page: number;
  perPage: number;
}

@Injectable()
export class CustomersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly loyalty: LoyaltyService,
  ) {}

  /**
   * Customers a store has served. A merchant only sees shoppers who ordered
   * at their store, and only that store's order figures. Admin (storeId null)
   * sees everyone.
   */
  async list(storeId: string | null, opts: ListOpts) {
    const orderScope: Prisma.OrderWhereInput | undefined = storeId
      ? { storeId }
      : undefined;

    const where: Prisma.UserWhereInput = {
      role: Role.CUSTOMER,
      orders: orderScope ? { some: orderScope } : { some: {} },
    };
    const q = opts.q?.trim();
    if (q) {
      where.OR = [
        { fullName: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q } },
      ];
    }

    const total = await this.prisma.user.count({ where });
    const users = await this.prisma.user.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: (opts.page - 1) * opts.perPage,
      take: opts.perPage,
      include: {
        orders: {
          where: orderScope,
          select: { total: true, createdAt: true },
        },
      },
    });

    const items = users.map((u) => {
      const spent = u.orders.reduce((sum, o) => sum + Number(o.total), 0);
      const last = u.orders.reduce<Date | null>(
        (acc, o) => (acc && acc > o.createdAt ? acc : o.createdAt),
        null,
      );
      return {
        id: u.id,
        fullName: u.fullName,
        email: u.email,
        phone: u.phone,
        avatarUrl: u.avatarUrl,
        membershipTier: u.membershipTier,
        pointsBalance: u.pointsBalance,
        merchantTags: u.merchantTags,
        orderCount: u.orders.length,
        totalSpentVnd: spent,
        lastOrderAt: last?.toISOString() ?? null,
      };
    });

    return {
      items,
      meta: { page: opts.page, perPage: opts.perPage, total },
    };
  }

  /** Full customer card: profile, address book, and this store's order
   *  history (all stores for admin). */
  /**
   * Merchant-created customer (typically for phone orders). Auto-generates
   * an email + password so the account can co-exist with the email-login
   * system; merchant doesn't need to manage credentials. Phone is the
   * dedupe key — re-creating with the same phone surfaces a clear error
   * instead of silently overwriting.
   */
  async createCustomer(input: {
    fullName: string;
    phone: string;
    email?: string;
    notes?: string;
  }) {
    const fullName = input.fullName.trim();
    const phone = input.phone.trim();
    if (fullName.length < 2) {
      throw new BadRequestException({
        code: 'NAME_REQUIRED',
        message: 'Tên đầy đủ tối thiểu 2 ký tự.',
      });
    }
    // Synth email when none supplied — `<digits>@guest.banan.local`.
    const emailRaw = (input.email ?? `${phone.replace(/\D/g, '')}@guest.banan.local`)
      .toLowerCase()
      .trim();
    // Random temp password the merchant won't need to know — the customer
    // can later request a reset link if they want to log into the customer
    // app themselves.
    const tempPassword = randomBytes(12).toString('base64url');
    const passwordHash = await bcrypt.hash(tempPassword, 10);
    try {
      const user = await this.prisma.user.create({
        data: {
          email: emailRaw,
          phone,
          passwordHash,
          fullName,
          role: Role.CUSTOMER,
          merchantNotes: input.notes,
        },
      });
      return {
        id: user.id,
        email: user.email,
        phone: user.phone,
        fullName: user.fullName,
        role: user.role,
        createdAt: user.createdAt,
      };
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        const target = (e.meta?.target as string[] | undefined)?.join(',');
        throw new ConflictException({
          code: 'CUSTOMER_EXISTS',
          message: target?.includes('phone')
            ? 'Số điện thoại này đã tồn tại trong hệ thống.'
            : 'Email này đã tồn tại trong hệ thống.',
        });
      }
      throw e;
    }
  }

  async detail(storeId: string | null, customerId: string) {
    const { user, orders } = await this.loadServed(storeId, customerId);

    const totalSpentVnd = orders.reduce(
      (sum, o) => sum + Number(o.total),
      0,
    );

    return {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      phone: user.phone,
      avatarUrl: user.avatarUrl,
      birthday: user.birthday?.toISOString() ?? null,
      membershipTier: user.membershipTier,
      pointsBalance: user.pointsBalance,
      merchantNotes: user.merchantNotes,
      merchantTags: user.merchantTags,
      createdAt: user.createdAt.toISOString(),
      orderCount: orders.length,
      totalSpentVnd,
      addresses: user.addresses.map((a) => ({
        id: a.id,
        label: a.label,
        recipient: a.recipient,
        phone: a.phone,
        line1: a.line1,
        line2: a.line2,
        city: a.city,
        district: a.district,
        postalCode: a.postalCode,
        isDefault: a.isDefault,
      })),
      orders: orders.map((o) => ({
        id: o.id,
        code: o.code,
        status: o.status,
        fulfillmentType: o.fulfillmentType,
        totalVnd: Number(o.total),
        storeName: o.store.name,
        createdAt: o.createdAt.toISOString(),
      })),
    };
  }

  // ───────────────────────── Merchant interactions ─────────────────────────

  /** Send a free-text message to the customer's in-app inbox + email. */
  async notify(
    storeId: string | null,
    customerId: string,
    title: string,
    body: string,
  ): Promise<void> {
    await this.loadServed(storeId, customerId);
    await this.notifications.sendToUser(customerId, {
      type: 'merchant.message',
      title,
      body,
    });
  }

  /**
   * Broadcast an announcement to many customers at once. Scope mirrors
   * the directory: a merchant reaches every customer their store has
   * served; admin reaches every CUSTOMER. An optional [tag] narrows to
   * the staff-tagged segment (vd "VIP").
   */
  async broadcast(
    storeId: string | null,
    title: string,
    body: string,
    tag?: string,
  ): Promise<{ sent: number }> {
    const orderScope: Prisma.OrderWhereInput | undefined = storeId
      ? { storeId }
      : undefined;
    const where: Prisma.UserWhereInput = {
      role: Role.CUSTOMER,
      orders: orderScope ? { some: orderScope } : { some: {} },
    };
    if (tag && tag.trim().length > 0) {
      where.merchantTags = { has: tag.trim() };
    }
    const recipients = await this.prisma.user.findMany({
      where,
      select: { id: true },
      take: 1000, // safety cap — broadcasts are not unbounded marketing.
    });
    for (const r of recipients) {
      await this.notifications.sendToUser(r.id, {
        type: 'merchant.broadcast',
        title,
        body,
      });
    }
    return { sent: recipients.length };
  }

  /** Manual Micho adjustment (gift / compensation). Notifies the customer. */
  async adjustPoints(
    storeId: string | null,
    customerId: string,
    delta: number,
    reason: string,
  ): Promise<{ balance: number }> {
    await this.loadServed(storeId, customerId);
    const event = await this.loyalty.adminAdjust({
      userId: customerId,
      delta,
      reason,
    });
    await this.notifications.sendToUser(customerId, {
      type: 'loyalty.adjustment',
      title: delta > 0 ? 'Bạn được tặng Micho!' : 'Điều chỉnh Micho',
      body:
        (delta > 0 ? `+${delta}` : `${delta}`) +
        ` Micho — ${reason}. Số dư mới: ${event.balanceAfter}.`,
    });
    return { balance: event.balanceAfter };
  }

  /** Private staff CRM: notes + tags. */
  async updateNotes(
    storeId: string | null,
    customerId: string,
    notes: string | undefined,
    tags: string[] | undefined,
  ) {
    await this.loadServed(storeId, customerId);
    const updated = await this.prisma.user.update({
      where: { id: customerId },
      data: {
        ...(notes !== undefined
          ? { merchantNotes: notes.trim() || null }
          : {}),
        ...(tags !== undefined
          ? {
              merchantTags: Array.from(
                new Set(
                  tags
                    .map((t) => t.trim())
                    .filter((t) => t.length > 0)
                    .slice(0, 20),
                ),
              ),
            }
          : {}),
      },
      select: { merchantNotes: true, merchantTags: true },
    });
    return updated;
  }

  /** Edit a customer's core profile (name / phone / email / birthday). */
  async updateProfile(
    storeId: string | null,
    customerId: string,
    input: {
      fullName?: string;
      phone?: string;
      email?: string;
      birthday?: string;
    },
  ) {
    await this.loadServed(storeId, customerId);

    const data: Prisma.UserUpdateInput = {};
    if (input.fullName !== undefined) {
      const name = input.fullName.trim();
      if (name.length < 2) {
        throw new BadRequestException({
          code: 'NAME_REQUIRED',
          message: 'Tên đầy đủ tối thiểu 2 ký tự.',
        });
      }
      data.fullName = name;
    }
    if (input.phone !== undefined) {
      data.phone = input.phone.trim() || null;
    }
    if (input.email !== undefined) {
      const email = input.email.trim().toLowerCase();
      if (email.length > 0) data.email = email;
    }
    if (input.birthday !== undefined) {
      const raw = input.birthday.trim();
      data.birthday = raw.length === 0 ? null : new Date(raw);
    }

    try {
      const u = await this.prisma.user.update({
        where: { id: customerId },
        data,
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
          birthday: true,
        },
      });
      return {
        id: u.id,
        fullName: u.fullName,
        email: u.email,
        phone: u.phone,
        birthday: u.birthday?.toISOString() ?? null,
      };
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        const target = (e.meta?.target as string[] | undefined)?.join(',');
        throw new ConflictException({
          code: 'CUSTOMER_EXISTS',
          message: target?.includes('phone')
            ? 'Số điện thoại này đã được dùng cho tài khoản khác.'
            : 'Email này đã được dùng cho tài khoản khác.',
        });
      }
      throw e;
    }
  }

  /**
   * Export the (scoped) customer directory as a CSV string. Mirrors the
   * list query but without pagination, capped for safety. Admin gets every
   * customer; a store merchant gets only those they've served.
   */
  async exportCsv(storeId: string | null, q?: string): Promise<string> {
    const orderScope: Prisma.OrderWhereInput | undefined = storeId
      ? { storeId }
      : undefined;
    const where: Prisma.UserWhereInput = {
      role: Role.CUSTOMER,
      orders: orderScope ? { some: orderScope } : { some: {} },
    };
    const term = q?.trim();
    if (term) {
      where.OR = [
        { fullName: { contains: term, mode: 'insensitive' } },
        { email: { contains: term, mode: 'insensitive' } },
        { phone: { contains: term } },
      ];
    }

    const users = await this.prisma.user.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 5000, // safety cap
      include: {
        orders: {
          where: orderScope,
          select: { total: true, createdAt: true },
        },
      },
    });

    const headers = [
      'Họ tên',
      'Email',
      'Số điện thoại',
      'Hạng',
      'Điểm Micho',
      'Số đơn',
      'Tổng chi tiêu (VND)',
      'Đơn gần nhất',
      'Ngày sinh',
      'Nhãn',
      'Tham gia',
    ];
    const esc = (v: unknown): string => {
      const s = v === null || v === undefined ? '' : String(v);
      // Quote always — simplest correct CSV; double internal quotes.
      return `"${s.replace(/"/g, '""')}"`;
    };
    const ymd = (d: Date | null): string =>
      d ? d.toISOString().slice(0, 10) : '';

    const rows = users.map((u) => {
      const spent = u.orders.reduce((sum, o) => sum + Number(o.total), 0);
      const last = u.orders.reduce<Date | null>(
        (acc, o) => (acc && acc > o.createdAt ? acc : o.createdAt),
        null,
      );
      return [
        u.fullName,
        u.email,
        u.phone ?? '',
        u.membershipTier,
        u.pointsBalance,
        u.orders.length,
        spent,
        ymd(last),
        ymd(u.birthday),
        (u.merchantTags ?? []).join('; '),
        ymd(u.createdAt),
      ]
        .map(esc)
        .join(',');
    });

    // BOM so Excel opens UTF-8 (Vietnamese) correctly.
    return '﻿' + [headers.map(esc).join(','), ...rows].join('\r\n');
  }

  /** Issue a single-use personal coupon and notify the customer. */
  async issueCoupon(
    storeId: string | null,
    customerId: string,
    args: {
      type: CouponType;
      value: number;
      minSubtotalVnd?: number;
      days: number;
    },
  ) {
    const { user } = await this.loadServed(storeId, customerId);
    const code = `BANAN-${randomBytes(4).toString('hex').toUpperCase()}`;
    const now = new Date();
    const endsAt = new Date(
      now.getTime() + args.days * 24 * 60 * 60 * 1000,
    );
    const coupon = await this.prisma.coupon.create({
      data: {
        code,
        type: args.type,
        value: new Prisma.Decimal(args.value),
        minSubtotal:
          args.minSubtotalVnd && args.minSubtotalVnd > 0
            ? new Prisma.Decimal(args.minSubtotalVnd)
            : null,
        startsAt: now,
        endsAt,
        maxRedemptions: 1,
        perUserLimit: 1,
        isActive: true,
      },
    });

    const desc =
      args.type === 'PERCENT'
        ? `giảm ${args.value}%`
        : args.type === 'FIXED'
          ? `giảm ${args.value.toLocaleString('vi-VN')}₫`
          : 'miễn phí giao hàng';
    await this.notifications.sendToUser(customerId, {
      type: 'coupon.gift',
      title: 'Quà tặng cho bạn 🎁',
      body:
        `Dùng mã ${code} để ${desc} cho đơn hàng tiếp theo. ` +
        `Có hiệu lực đến ${endsAt.toLocaleDateString('vi-VN')}.`,
    });

    return { code: coupon.code, endsAt: endsAt.toISOString(), customer: user.id };
  }

  // ──────────────────────────────── internals ────────────────────────────────

  /**
   * Loads the customer + their orders within scope, enforcing that a store
   * merchant has actually served this customer (admins bypass the check).
   */
  private async loadServed(storeId: string | null, customerId: string) {
    const orderScope: Prisma.OrderWhereInput = storeId
      ? { customerId, storeId }
      : { customerId };

    const user = await this.prisma.user.findFirst({
      where: { id: customerId, role: Role.CUSTOMER },
      include: {
        addresses: { orderBy: [{ isDefault: 'desc' }, { id: 'desc' }] },
      },
    });
    if (!user) {
      throw new NotFoundException({ code: 'CUSTOMER_NOT_FOUND' });
    }

    const orders = await this.prisma.order.findMany({
      where: orderScope,
      orderBy: { createdAt: 'desc' },
      take: 30,
      select: {
        id: true,
        code: true,
        status: true,
        fulfillmentType: true,
        total: true,
        createdAt: true,
        store: { select: { id: true, name: true } },
      },
    });
    if (storeId && orders.length === 0) {
      throw new NotFoundException({ code: 'CUSTOMER_NOT_FOUND' });
    }
    return { user, orders };
  }
}
