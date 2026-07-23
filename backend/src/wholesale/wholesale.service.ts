import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OrderStatus, Prisma, Role, WholesaleReceivableStatus } from '@prisma/client';

import { generateOrderCode } from '../orders/order-code';
import { OrdersService } from '../orders/orders.service';
import { PrismaService } from '../prisma/prisma.service';

import type {
  ContractLineDto,
  CreateContractDto,
  CreateWholesaleAccountDto,
  CreateWholesaleOrderDto,
  UpdateContractDto,
  UpdateContractLineDto,
  UpdateWholesaleAccountDto,
} from './dto/wholesale.dto';

const ORDER_LIST_INCLUDE = {
  items: true,
  wholesaleAccount: {
    select: { id: true, companyName: true, deliveryAddress: true },
  },
  receivable: true,
  store: { select: { id: true, name: true } },
} satisfies Prisma.OrderInclude;

// Delivery-schedule rules run on VN local time (UTC+7, no DST) — same
// convention as reports and store opening hours.
const VN_OFFSET_MS = 7 * 3_600_000;
const DAY_MS = 86_400_000;
/** Calendar day count (days since epoch) in VN local time. */
const vnDay = (d: Date) => Math.floor((d.getTime() + VN_OFFSET_MS) / DAY_MS);
const vnMinuteOfDay = (d: Date) => Math.floor(((d.getTime() + VN_OFFSET_MS) % DAY_MS) / 60_000);
/** ISO weekday in VN time: 1 = Thứ 2 … 7 = Chủ nhật (epoch day 0 = Thursday). */
const vnWeekday = (d: Date) => ((vnDay(d) + 3) % 7) + 1;
const WEEKDAY_VI = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
const fmtCutoff = (m: number) =>
  `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;

/**
 * Admin-managed B2B: accounts + contracts define WHO may buy WHAT at WHICH
 * price; orders settle on account (receivables) instead of a gateway; admin
 * confirms each order onto the kitchen board and confirms debts as paid.
 * Merchant owners/staff have no access anywhere in this module by design.
 */
@Injectable()
export class WholesaleService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly orders: OrdersService,
  ) {}

  // ── admin: accounts ───────────────────────────────────────────────────────

  async createAccount(dto: CreateWholesaleAccountDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: dto.userId },
      select: { id: true, role: true },
    });
    if (!user) throw new NotFoundException({ code: 'USER_NOT_FOUND' });
    // Wholesale buyers are ordinary customer logins with an account attached —
    // never a staff/kitchen/admin login.
    if (user.role !== 'CUSTOMER') {
      throw new BadRequestException({
        code: 'WHOLESALE_USER_NOT_CUSTOMER',
        message: 'Tài khoản wholesale phải gắn với một tài khoản khách hàng.',
      });
    }
    try {
      return await this.prisma.wholesaleAccount.create({
        data: {
          userId: dto.userId,
          companyName: dto.companyName.trim(),
          contactName: dto.contactName,
          contactPhone: dto.contactPhone,
          taxId: dto.taxId,
          billingEmail: dto.billingEmail,
          deliveryAddress: dto.deliveryAddress,
          creditLimitVnd: dto.creditLimitVnd ?? 0,
          paymentTermDays: dto.paymentTermDays ?? 30,
        },
      });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new BadRequestException({
          code: 'WHOLESALE_ACCOUNT_EXISTS',
          message: 'Người dùng này đã có tài khoản wholesale.',
        });
      }
      throw e;
    }
  }

  listAccounts() {
    return this.prisma.wholesaleAccount.findMany({
      include: {
        user: { select: { id: true, email: true, phone: true, fullName: true } },
        _count: { select: { contracts: true, orders: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getAccount(id: string) {
    const account = await this.prisma.wholesaleAccount.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, email: true, phone: true, fullName: true } },
        contracts: {
          include: {
            lines: {
              include: {
                product: { select: { id: true, name: true } },
                variant: { select: { id: true, size: true, flavor: true } },
              },
              orderBy: { createdAt: 'asc' },
            },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
    if (!account) throw new NotFoundException({ code: 'WHOLESALE_ACCOUNT_NOT_FOUND' });
    return account;
  }

  async updateAccount(id: string, dto: UpdateWholesaleAccountDto) {
    const account = await this.prisma.wholesaleAccount.findUnique({ where: { id } });
    if (!account) throw new NotFoundException({ code: 'WHOLESALE_ACCOUNT_NOT_FOUND' });
    return this.prisma.wholesaleAccount.update({
      where: { id },
      data: {
        ...(dto.companyName !== undefined ? { companyName: dto.companyName.trim() } : {}),
        ...(dto.contactName !== undefined ? { contactName: dto.contactName } : {}),
        ...(dto.contactPhone !== undefined ? { contactPhone: dto.contactPhone } : {}),
        ...(dto.taxId !== undefined ? { taxId: dto.taxId } : {}),
        ...(dto.billingEmail !== undefined ? { billingEmail: dto.billingEmail } : {}),
        ...(dto.deliveryAddress !== undefined
          ? { deliveryAddress: dto.deliveryAddress.trim() || null }
          : {}),
        ...(dto.active !== undefined ? { active: dto.active } : {}),
        ...(dto.creditLimitVnd !== undefined ? { creditLimitVnd: dto.creditLimitVnd } : {}),
        ...(dto.paymentTermDays !== undefined ? { paymentTermDays: dto.paymentTermDays } : {}),
        ...(dto.blockedReason !== undefined ? { blockedReason: dto.blockedReason || null } : {}),
      },
    });
  }

  // ── admin: contracts + lines ──────────────────────────────────────────────

  async createContract(dto: CreateContractDto) {
    const account = await this.prisma.wholesaleAccount.findUnique({
      where: { id: dto.wholesaleAccountId },
    });
    if (!account) throw new NotFoundException({ code: 'WHOLESALE_ACCOUNT_NOT_FOUND' });
    return this.prisma.wholesaleContract.create({
      data: {
        wholesaleAccountId: dto.wholesaleAccountId,
        name: dto.name.trim(),
        startsAt: new Date(dto.startsAt),
        endsAt: dto.endsAt ? new Date(dto.endsAt) : null,
        minOrderVnd: dto.minOrderVnd,
        defaultDiscountPct: dto.defaultDiscountPct,
        paymentTermDays: dto.paymentTermDays,
        nextDayCutoffMinutes: dto.nextDayCutoffMinutes,
        noDeliveryDays: dto.noDeliveryDays ?? [],
        shipFeeVnd: dto.shipFeeVnd ?? 0,
      },
    });
  }

  async updateContract(id: string, dto: UpdateContractDto) {
    const contract = await this.prisma.wholesaleContract.findUnique({ where: { id } });
    if (!contract) throw new NotFoundException({ code: 'WHOLESALE_CONTRACT_NOT_FOUND' });
    return this.prisma.wholesaleContract.update({
      where: { id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
        ...(dto.startsAt !== undefined ? { startsAt: new Date(dto.startsAt) } : {}),
        ...(dto.endsAt !== undefined ? { endsAt: dto.endsAt ? new Date(dto.endsAt) : null } : {}),
        ...(dto.active !== undefined ? { active: dto.active } : {}),
        ...(dto.minOrderVnd !== undefined ? { minOrderVnd: dto.minOrderVnd } : {}),
        ...(dto.defaultDiscountPct !== undefined
          ? { defaultDiscountPct: dto.defaultDiscountPct }
          : {}),
        ...(dto.paymentTermDays !== undefined ? { paymentTermDays: dto.paymentTermDays } : {}),
        ...(dto.nextDayCutoffMinutes !== undefined
          ? { nextDayCutoffMinutes: dto.nextDayCutoffMinutes }
          : {}),
        ...(dto.noDeliveryDays !== undefined ? { noDeliveryDays: dto.noDeliveryDays } : {}),
        ...(dto.shipFeeVnd !== undefined ? { shipFeeVnd: dto.shipFeeVnd } : {}),
      },
    });
  }

  async addContractLine(contractId: string, dto: ContractLineDto) {
    const contract = await this.prisma.wholesaleContract.findUnique({ where: { id: contractId } });
    if (!contract) throw new NotFoundException({ code: 'WHOLESALE_CONTRACT_NOT_FOUND' });
    const product = await this.prisma.product.findUnique({
      where: { id: dto.productId },
      select: { id: true, variants: { select: { id: true } } },
    });
    if (!product) throw new NotFoundException({ code: 'PRODUCT_NOT_FOUND' });
    if (dto.variantId && !product.variants.some((v) => v.id === dto.variantId)) {
      throw new BadRequestException({ code: 'VARIANT_NOT_FOUND' });
    }
    const duplicate = await this.prisma.wholesaleContractLine.findFirst({
      where: {
        contractId,
        productId: dto.productId,
        ...(dto.variantId ? { OR: [{ variantId: dto.variantId }, { variantId: null }] } : {}),
      },
      select: { id: true },
    });
    if (duplicate) {
      throw new BadRequestException({
        code: 'WHOLESALE_LINE_EXISTS',
        message: 'Sản phẩm/biến thể này đã có trong hợp đồng.',
      });
    }
    if (
      dto.fixedPriceVnd == null &&
      dto.discountPct == null &&
      contract.defaultDiscountPct == null
    ) {
      throw new BadRequestException({
        code: 'WHOLESALE_LINE_NO_PRICE',
        message: 'Dòng hợp đồng cần giá cố định hoặc % chiết khấu (hoặc chiết khấu mặc định).',
      });
    }
    return this.prisma.wholesaleContractLine.create({
      data: {
        contractId,
        productId: dto.productId,
        variantId: dto.variantId,
        fixedPriceVnd: dto.fixedPriceVnd,
        discountPct: dto.discountPct,
        minQty: dto.minQty ?? 1,
        leadTimeHours: dto.leadTimeHours,
        multipleQty: dto.multipleQty ?? 1,
        deliveryDays: dto.deliveryDays ?? [],
        leadTimeDays: dto.leadTimeDays,
      },
    });
  }

  async updateContractLine(contractId: string, lineId: string, dto: UpdateContractLineDto) {
    const line = await this.prisma.wholesaleContractLine.findUnique({ where: { id: lineId } });
    if (!line || line.contractId !== contractId) {
      throw new NotFoundException({ code: 'WHOLESALE_LINE_NOT_FOUND' });
    }
    return this.prisma.wholesaleContractLine.update({
      where: { id: lineId },
      data: {
        ...(dto.fixedPriceVnd !== undefined ? { fixedPriceVnd: dto.fixedPriceVnd } : {}),
        ...(dto.discountPct !== undefined ? { discountPct: dto.discountPct } : {}),
        ...(dto.minQty !== undefined ? { minQty: dto.minQty } : {}),
        ...(dto.active !== undefined ? { active: dto.active } : {}),
        ...(dto.leadTimeHours !== undefined ? { leadTimeHours: dto.leadTimeHours } : {}),
        ...(dto.multipleQty !== undefined ? { multipleQty: dto.multipleQty } : {}),
        ...(dto.deliveryDays !== undefined ? { deliveryDays: dto.deliveryDays } : {}),
        ...(dto.leadTimeDays !== undefined ? { leadTimeDays: dto.leadTimeDays } : {}),
      },
    });
  }

  // ── admin: orders + receivables ───────────────────────────────────────────

  listOrdersAdmin(status?: OrderStatus) {
    return this.prisma.order.findMany({
      where: {
        source: 'WHOLESALE',
        ...(status ? { status } : {}),
      },
      include: ORDER_LIST_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Admin pushes a pending wholesale order onto the kitchen board. Reuses the
   * standard pipeline: PENDING → ACCEPTED (the customer's "Xác nhận"), then
   * the normal transfer (SENT_TO_KITCHEN + PENDING_ACK + kitchen routing).
   */
  confirmOrder(id: string, admin: { sub: string; role: Role }) {
    return this.orders.confirmWholesaleOrder(id, admin);
  }

  async rejectOrder(id: string, admin: { sub: string; role: Role }, reason?: string) {
    const order = await this.prisma.order.findUnique({
      where: { id },
      select: { source: true, status: true },
    });
    if (!order) throw new NotFoundException({ code: 'ORDER_NOT_FOUND' });
    if (order.source !== 'WHOLESALE') {
      throw new BadRequestException({ code: 'NOT_WHOLESALE_ORDER' });
    }
    if (order.status !== 'PENDING') {
      throw new BadRequestException({ code: 'ORDER_INVALID_TRANSITION' });
    }
    return this.orders.transition(
      id,
      'CANCELLED',
      admin,
      reason?.trim() || 'Admin từ chối đơn wholesale',
    );
  }

  listReceivables(status?: WholesaleReceivableStatus) {
    return this.prisma.wholesaleReceivable.findMany({
      where: status ? { status } : undefined,
      include: {
        account: { select: { id: true, companyName: true } },
        order: { select: { id: true, code: true, total: true, createdAt: true } },
      },
      orderBy: [{ dueDate: { sort: 'asc', nulls: 'last' } }, { createdAt: 'desc' }],
    });
  }

  /**
   * Record one collection against a receivable. Amounts accumulate in a
   * ledger (WholesalePayment: how much, when, method, bank reference, who
   * confirmed); the receivable flips PARTIAL while under-collected and PAID
   * when fully collected. The row lock serializes concurrent confirms.
   */
  async recordReceivablePayment(
    id: string,
    adminId: string,
    dto: {
      amountVnd?: number;
      method?: string;
      reference?: string;
      note?: string;
      clientRequestId?: string;
    } = {},
  ) {
    const settled = () =>
      this.prisma.wholesaleReceivable.findUniqueOrThrow({
        where: { id },
        include: { payments: { orderBy: { paidAt: 'desc' } } },
      });
    return this.prisma
      .$transaction(async (tx) => {
        await tx.$queryRaw`SELECT "id" FROM "WholesaleReceivable" WHERE "id" = ${id} FOR UPDATE`;
        // Idempotency: the same confirm retried (double-click, network retry)
        // must NOT collect twice — the second attempt still fits the remaining
        // balance, so the amount guard alone can't catch it.
        if (dto.clientRequestId) {
          const existing = await tx.wholesalePayment.findUnique({
            where: {
              receivableId_clientRequestId: {
                receivableId: id,
                clientRequestId: dto.clientRequestId,
              },
            },
          });
          if (existing) {
            return tx.wholesaleReceivable.findUniqueOrThrow({
              where: { id },
              include: { payments: { orderBy: { paidAt: 'desc' } } },
            });
          }
        }
        const receivable = await tx.wholesaleReceivable.findUnique({ where: { id } });
        if (!receivable) throw new NotFoundException({ code: 'RECEIVABLE_NOT_FOUND' });
        if (!['OPEN', 'PARTIAL', 'OVERDUE'].includes(receivable.status)) {
          throw new BadRequestException({
            code: 'RECEIVABLE_NOT_OPEN',
            message: 'Công nợ này đã được xử lý.',
          });
        }
        const remaining =
          Number(receivable.amountVnd.toString()) - Number(receivable.paidAmountVnd.toString());
        const amount = dto.amountVnd ?? remaining;
        if (amount <= 0 || amount > remaining) {
          throw new BadRequestException({
            code: 'PAYMENT_AMOUNT_INVALID',
            message: `Số tiền thu phải trong khoảng 1 – ${new Intl.NumberFormat('vi-VN').format(remaining)} ₫.`,
          });
        }
        await tx.wholesalePayment.create({
          data: {
            receivableId: id,
            amountVnd: new Prisma.Decimal(amount),
            method: dto.method ?? 'BANK_TRANSFER',
            reference: dto.reference?.trim() || null,
            note: dto.note?.trim() || null,
            confirmedByAdminId: adminId,
            clientRequestId: dto.clientRequestId ?? null,
          },
        });
        const nowPaid = Number(receivable.paidAmountVnd.toString()) + amount;
        const fullyPaid = nowPaid >= Number(receivable.amountVnd.toString());
        // Under-collected AND past due stays OVERDUE — a partial payment must
        // not hide the debt from the overdue filter until the next cron.
        const stillOverdue =
          receivable.dueDate != null && receivable.dueDate.getTime() < Date.now();
        await tx.wholesaleReceivable.update({
          where: { id },
          data: {
            paidAmountVnd: { increment: new Prisma.Decimal(amount) },
            status: fullyPaid ? 'PAID' : stillOverdue ? 'OVERDUE' : 'PARTIAL',
            ...(fullyPaid && { paidAt: new Date(), confirmedByAdminId: adminId }),
          },
        });
        return tx.wholesaleReceivable.findUniqueOrThrow({
          where: { id },
          include: { payments: { orderBy: { paidAt: 'desc' } } },
        });
      })
      .catch((e) => {
        // Same-key race past the in-tx pre-read: return the settled state.
        if (
          e instanceof Prisma.PrismaClientKnownRequestError &&
          e.code === 'P2002' &&
          dto.clientRequestId
        ) {
          return settled();
        }
        throw e;
      });
  }

  /** Legacy "mark fully paid" — one ledger entry for the whole remaining balance. */
  markReceivablePaid(id: string, adminId: string) {
    return this.recordReceivablePayment(id, adminId, {});
  }

  // ── customer (wholesale buyer) ────────────────────────────────────────────

  /** The caller's ACTIVE wholesale account, or a 403. */
  async access(userId: string) {
    const account = await this.prisma.wholesaleAccount.findUnique({
      where: { userId },
      select: { id: true, companyName: true, active: true },
    });
    return {
      enabled: account?.active ?? false,
      accountId: account?.id ?? null,
      companyName: account?.companyName ?? null,
    };
  }

  private async requireAccount(userId: string) {
    const account = await this.prisma.wholesaleAccount.findUnique({
      where: { userId },
    });
    if (!account || !account.active) {
      throw new ForbiddenException({
        code: 'WHOLESALE_NOT_ENABLED',
        message: account?.blockedReason?.trim()
          ? `Tài khoản wholesale đang bị khoá: ${account.blockedReason}`
          : 'Tài khoản của bạn chưa được kích hoạt mua sỉ.',
      });
    }
    return account;
  }

  private contractWindowFilter(now: Date): Prisma.WholesaleContractWhereInput {
    return {
      active: true,
      startsAt: { lte: now },
      OR: [{ endsAt: null }, { endsAt: { gte: now } }],
    };
  }

  /** Contract price per unit for a line, given the retail unit price. */
  private contractUnitPrice(
    line: { fixedPriceVnd: number | null; discountPct: Prisma.Decimal | null },
    contract: { defaultDiscountPct: Prisma.Decimal | null },
    retail: Prisma.Decimal,
  ): Prisma.Decimal {
    if (line.fixedPriceVnd != null) return new Prisma.Decimal(line.fixedPriceVnd);
    const pct = line.discountPct ?? contract.defaultDiscountPct ?? new Prisma.Decimal(0);
    const price = retail.times(new Prisma.Decimal(100).minus(pct)).dividedBy(100);
    return price.toDecimalPlaces(0, Prisma.Decimal.ROUND_DOWN); // whole ₫, làm tròn xuống có lợi cho khách
  }

  /** The buyer's catalog: active contracts + their active lines with prices. */
  async catalog(userId: string) {
    const account = await this.requireAccount(userId);
    const contracts = await this.prisma.wholesaleContract.findMany({
      where: { wholesaleAccountId: account.id, ...this.contractWindowFilter(new Date()) },
      include: {
        lines: {
          where: { active: true },
          include: {
            product: {
              select: {
                id: true,
                name: true,
                basePrice: true,
                isAvailable: true,
                variants: {
                  orderBy: [{ size: 'asc' }, { flavor: 'asc' }],
                  select: {
                    id: true,
                    size: true,
                    flavor: true,
                    priceDelta: true,
                    isAvailable: true,
                  },
                },
              },
            },
            variant: { select: { id: true, size: true, flavor: true, priceDelta: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return contracts.map((c) => ({
      id: c.id,
      name: c.name,
      startsAt: c.startsAt,
      endsAt: c.endsAt,
      minOrderVnd: c.minOrderVnd,
      nextDayCutoffMinutes: c.nextDayCutoffMinutes,
      noDeliveryDays: c.noDeliveryDays,
      shipFeeVnd: c.shipFeeVnd,
      lines: c.lines
        .filter((l) => l.product.isAvailable)
        .flatMap((l) => {
          // A product-level contract line authorizes every currently available
          // variant. Surface one catalog row per variant so the buyer can
          // choose explicitly and the submitted price snapshot is unambiguous.
          const variants = l.variant
            ? [l.variant]
            : l.product.variants.filter((variant) => variant.isAvailable);
          return variants.map((variant) => {
            const retail = new Prisma.Decimal(l.product.basePrice).plus(variant.priceDelta);
            return {
              id: `${l.id}:${variant.id}`,
              productId: l.productId,
              productName: l.product.name,
              variantId: variant.id,
              variantLabel: `${variant.size} · ${variant.flavor}`,
              retailPrice: retail,
              contractPrice: this.contractUnitPrice(l, c, retail),
              minQty: l.minQty,
              leadTimeHours: l.leadTimeHours,
              multipleQty: l.multipleQty,
              deliveryDays: l.deliveryDays,
              leadTimeDays: l.leadTimeDays,
            };
          });
        }),
    }));
  }

  /**
   * Place an on-account order strictly inside the contract: every item must
   * match an active line, respect minQty, and price from the contract. No
   * coupons/points/gift cards/campaigns ever apply. The order waits in
   * PENDING for admin confirmation; an OPEN receivable is created with it.
   */
  async createOrder(userId: string, dto: CreateWholesaleOrderDto) {
    const account = await this.requireAccount(userId);
    const now = new Date();
    const targetAt = dto.scheduledFor ? new Date(dto.scheduledFor) : now;

    // Idempotency: the buyer IS the creator here, so the same
    // (createdById, clientRequestId) unique the staff channels use applies —
    // a double-click or network retry returns the first order, and never
    // books the debt or the stock twice.
    if (dto.clientRequestId) {
      const replay = await this.prisma.order.findUnique({
        where: {
          createdById_clientRequestId: {
            createdById: userId,
            clientRequestId: dto.clientRequestId,
          },
        },
        include: ORDER_LIST_INCLUDE,
      });
      if (replay) return replay;
    }

    const contract = await this.prisma.wholesaleContract.findFirst({
      where: {
        id: dto.contractId,
        wholesaleAccountId: account.id,
        ...this.contractWindowFilter(now),
      },
      include: { lines: { where: { active: true } } },
    });
    if (!contract) {
      throw new BadRequestException({
        code: 'WHOLESALE_CONTRACT_INVALID',
        message: 'Hợp đồng không tồn tại hoặc đã hết hiệu lực.',
      });
    }

    // ── delivery-schedule rules (all dates in VN local time) ──
    const hasScheduleRules =
      contract.nextDayCutoffMinutes != null ||
      contract.noDeliveryDays.length > 0 ||
      contract.lines.some((l) => l.deliveryDays.length > 0 || (l.leadTimeDays ?? 0) > 0);
    if (!dto.scheduledFor && hasScheduleRules) {
      throw new BadRequestException({
        code: 'WHOLESALE_DELIVERY_DATE_REQUIRED',
        message: 'Hợp đồng này yêu cầu chọn ngày giao hàng.',
      });
    }
    const today = vnDay(now);
    const deliveryDay = dto.scheduledFor ? vnDay(targetAt) : null;
    const weekday = dto.scheduledFor ? vnWeekday(targetAt) : null;
    if (deliveryDay != null && contract.nextDayCutoffMinutes != null) {
      const earliest = today + (vnMinuteOfDay(now) < contract.nextDayCutoffMinutes ? 1 : 2);
      if (deliveryDay < earliest) {
        throw new BadRequestException({
          code: 'WHOLESALE_CUTOFF',
          message:
            `Đặt trước ${fmtCutoff(contract.nextDayCutoffMinutes)} để giao vào ngày hôm sau — ` +
            `đơn này sớm nhất giao sau ${earliest - today} ngày.`,
        });
      }
    }
    if (weekday != null && contract.noDeliveryDays.includes(weekday)) {
      throw new BadRequestException({
        code: 'WHOLESALE_NO_DELIVERY_DAY',
        message: `Không giao hàng vào ${WEEKDAY_VI[weekday]}.`,
      });
    }

    // Resolve products + variants and price every line from the contract.
    const productIds = [...new Set(dto.items.map((i) => i.productId))];
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds } },
      include: { variants: { orderBy: [{ size: 'asc' }, { flavor: 'asc' }] } },
    });
    const productById = new Map(products.map((p) => [p.id, p]));
    if (productIds.some((id) => !productById.has(id))) {
      throw new BadRequestException({ code: 'PRODUCT_NOT_FOUND' });
    }
    if (new Set(products.map((p) => p.storeId)).size > 1) {
      throw new BadRequestException({ code: 'CART_MULTI_STORE' });
    }
    const storeId = products[0]!.storeId;

    let subtotal = new Prisma.Decimal(0);
    const lineCreates: Prisma.OrderItemCreateManyOrderInput[] = [];
    for (const item of dto.items) {
      const product = productById.get(item.productId)!;
      if (!product.isAvailable) {
        throw new BadRequestException({
          code: 'PRODUCT_UNAVAILABLE',
          message: `${product.name} hiện không bán.`,
        });
      }
      const variant = item.variantId
        ? product.variants.find((v) => v.id === item.variantId)
        : product.variants[0];
      if (!variant || !variant.isAvailable) {
        throw new BadRequestException({ code: 'VARIANT_UNAVAILABLE' });
      }
      // A line with a null variantId covers EVERY variant of the product; a
      // line pinned to a variant only covers that one.
      const line = contract.lines.find(
        (l) =>
          l.productId === item.productId && (l.variantId == null || l.variantId === variant.id),
      );
      if (!line) {
        throw new BadRequestException({
          code: 'WHOLESALE_ITEM_NOT_IN_CONTRACT',
          message: `"${product.name}" không nằm trong hợp đồng.`,
        });
      }
      if (item.quantity < line.minQty) {
        throw new BadRequestException({
          code: 'WHOLESALE_MIN_QTY',
          message: `"${product.name}" đặt tối thiểu ${line.minQty}.`,
        });
      }
      if (line.multipleQty > 1 && item.quantity % line.multipleQty !== 0) {
        throw new BadRequestException({
          code: 'WHOLESALE_QTY_MULTIPLE',
          message: `"${product.name}" đặt theo bội số ${line.multipleQty}.`,
        });
      }
      if (weekday != null && line.deliveryDays.length > 0 && !line.deliveryDays.includes(weekday)) {
        throw new BadRequestException({
          code: 'WHOLESALE_ITEM_DELIVERY_DAY',
          message: `"${product.name}" chỉ giao vào ${line.deliveryDays
            .map((d) => WEEKDAY_VI[d])
            .join(', ')}.`,
        });
      }
      if (line.leadTimeDays && deliveryDay != null && deliveryDay - today < line.leadTimeDays) {
        throw new BadRequestException({
          code: 'WHOLESALE_LEAD_TIME',
          message: `"${product.name}" cần đặt trước ${line.leadTimeDays} ngày.`,
        });
      }
      if (line.leadTimeHours && line.leadTimeHours > 0) {
        const targetAt = dto.scheduledFor ? new Date(dto.scheduledFor) : now;
        if (targetAt.getTime() - now.getTime() < line.leadTimeHours * 3600 * 1000) {
          throw new BadRequestException({
            code: 'WHOLESALE_LEAD_TIME',
            message: `"${product.name}" cần đặt trước ${line.leadTimeHours} giờ.`,
          });
        }
      }
      const retail = new Prisma.Decimal(product.basePrice).plus(variant.priceDelta);
      const unitPrice = this.contractUnitPrice(line, contract, retail);
      const lineTotal = unitPrice.times(item.quantity);
      subtotal = subtotal.plus(lineTotal);
      lineCreates.push({
        productId: product.id,
        variantId: variant.id,
        productName: product.name,
        variantLabel: `${variant.size} · ${variant.flavor}`,
        quantity: item.quantity,
        unitPrice,
        lineTotal,
      });
    }

    const subtotalVnd = Number(subtotal.toString());
    if (contract.minOrderVnd && subtotalVnd < contract.minOrderVnd) {
      const fmt = new Intl.NumberFormat('vi-VN').format(contract.minOrderVnd);
      throw new BadRequestException({
        code: 'WHOLESALE_MIN_ORDER',
        message: `Đơn hợp đồng tối thiểu ${fmt} ₫.`,
      });
    }
    // Ship fee rides on top of the goods — the minimum-order rule above applies
    // to goods only, but credit and the receivable cover the full amount owed.
    const shipFee = new Prisma.Decimal(contract.shipFeeVnd ?? 0);
    const grandTotal = subtotal.plus(shipFee);
    const totalVnd = Number(grandTotal.toString());
    const orderCode = generateOrderCode();
    const created = await this.prisma
      .$transaction(async (tx) => {
        // Serialize every credit decision for this account. Without this lock,
        // two concurrent orders can both observe the same free credit and both
        // pass, overshooting the contract limit.
        await tx.$queryRaw`
        SELECT "id" FROM "WholesaleAccount"
        WHERE "id" = ${account.id}
        FOR UPDATE
      `;
        const freshAccount = await tx.wholesaleAccount.findUniqueOrThrow({
          where: { id: account.id },
          select: { active: true, blockedReason: true, creditLimitVnd: true },
        });
        if (!freshAccount.active || freshAccount.blockedReason?.trim()) {
          throw new ForbiddenException({
            code: 'WHOLESALE_NOT_ENABLED',
            message: freshAccount.blockedReason?.trim()
              ? `Tài khoản wholesale đang bị khoá: ${freshAccount.blockedReason}`
              : 'Tài khoản wholesale đang bị khoá.',
          });
        }
        const overdue = await tx.wholesaleReceivable.count({
          where: {
            wholesaleAccountId: account.id,
            status: { in: ['OPEN', 'PARTIAL', 'OVERDUE'] },
            dueDate: { lt: now },
          },
        });
        if (overdue > 0) {
          throw new BadRequestException({
            code: 'WHOLESALE_OVERDUE',
            message: 'Có công nợ quá hạn — vui lòng thanh toán trước khi đặt đơn mới.',
          });
        }
        const committed = await tx.wholesaleReceivable.aggregate({
          _sum: { amountVnd: true, paidAmountVnd: true },
          where: {
            wholesaleAccountId: account.id,
            status: { in: ['PENDING', 'OPEN', 'PARTIAL', 'OVERDUE'] },
          },
        });
        // Outstanding = billed − already collected, so a partial payment frees
        // credit immediately instead of only when the receivable fully closes.
        const committedDebt =
          Number((committed._sum.amountVnd ?? new Prisma.Decimal(0)).toString()) -
          Number((committed._sum.paidAmountVnd ?? new Prisma.Decimal(0)).toString());
        if (committedDebt + totalVnd > freshAccount.creditLimitVnd) {
          const fmt = new Intl.NumberFormat('vi-VN');
          throw new BadRequestException({
            code: 'WHOLESALE_CREDIT_LIMIT',
            message:
              `Vượt hạn mức công nợ (${fmt.format(freshAccount.creditLimitVnd)} ₫ — ` +
              `đã dùng ${fmt.format(committedDebt)} ₫).`,
          });
        }

        await this.orders.reserveChannelStock(tx, products, lineCreates, targetAt);
        const order = await tx.order.create({
          data: {
            code: orderCode,
            customerId: userId,
            storeId,
            fulfillmentType: 'DELIVERY',
            scheduledFor: dto.scheduledFor ? new Date(dto.scheduledFor) : null,
            status: 'PENDING',
            source: 'WHOLESALE',
            settlementMode: 'ON_ACCOUNT',
            wholesaleAccountId: account.id,
            wholesaleContractId: contract.id,
            createdById: userId,
            clientRequestId: dto.clientRequestId ?? null,
            // Order-time SNAPSHOT — editing the account later must not rewrite
            // what this order displays (address, tax id, contact, buyer's PO).
            wholesaleInfo: {
              companyName: account.companyName,
              deliveryAddress: account.deliveryAddress ?? null,
              taxId: account.taxId ?? null,
              billingEmail: account.billingEmail ?? null,
              contactName: account.contactName ?? null,
              contactPhone: account.contactPhone ?? null,
              poCode: dto.poCode?.trim() || null,
            },
            subtotal,
            deliveryFee: shipFee,
            total: grandTotal,
            notes: dto.notes,
            items: { createMany: { data: lineCreates } },
            statusEvents: {
              create: {
                fromStatus: null,
                toStatus: 'PENDING',
                actorId: userId,
                note: 'Đơn wholesale — chờ admin xác nhận',
              },
            },
          },
          include: ORDER_LIST_INCLUDE,
        });
        await tx.wholesaleReceivable.create({
          data: {
            wholesaleAccountId: account.id,
            orderId: order.id,
            amountVnd: grandTotal,
            dueDate: null,
            status: 'PENDING',
          },
        });
        return order;
      })
      .catch(async (e) => {
        // Two same-key submits racing past the pre-read: the loser hits the
        // (createdById, clientRequestId) unique — hand back the winner's order.
        if (
          e instanceof Prisma.PrismaClientKnownRequestError &&
          e.code === 'P2002' &&
          dto.clientRequestId
        ) {
          const winner = await this.prisma.order.findUnique({
            where: {
              createdById_clientRequestId: {
                createdById: userId,
                clientRequestId: dto.clientRequestId,
              },
            },
            include: ORDER_LIST_INCLUDE,
          });
          if (winner) return winner;
        }
        throw e;
      });
    this.orders.notifyWholesaleOrderCreated(created);
    return created;
  }

  async myOrders(userId: string) {
    await this.requireAccount(userId);
    return this.prisma.order.findMany({
      where: { customerId: userId, source: 'WHOLESALE' },
      include: ORDER_LIST_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  async myReceivables(userId: string) {
    const account = await this.requireAccount(userId);
    return this.prisma.wholesaleReceivable.findMany({
      where: { wholesaleAccountId: account.id },
      include: { order: { select: { id: true, code: true, createdAt: true } } },
      orderBy: [{ dueDate: { sort: 'asc', nulls: 'last' } }, { createdAt: 'desc' }],
    });
  }
}
