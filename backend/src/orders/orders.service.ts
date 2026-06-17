import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { KitchenStatus, OrderStatus, Prisma, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'node:crypto';

import { AuthService } from '../auth/auth.service';
import { CouponsService } from '../coupons/coupons.service';
import { DeliveryConfigService } from '../geo/delivery-config.service';
import { StoreRouterService } from '../geo/store-router.service';
import { LoyaltyService, LOYALTY_CONFIG } from '../loyalty/loyalty.service';
import {
  kitchenStatusNotification,
  orderStatusNotification,
} from '../notifications/notification-templates';
import { NotificationsService } from '../notifications/notifications.service';
import type { PaymentInstructions } from '../payments/dto/payment-instructions';
import { PaymentsService } from '../payments/payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { PromotionsService } from '../promotions/promotions.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { RefundsService } from '../refunds/refunds.service';

import type { CreateOrderDto } from './dto/create-order.dto';
import { generateOrderCode } from './order-code';
import {
  canCustomerCancel,
  isAllowedKitchenTransition,
  isAllowedTransition,
} from './order-status';

/// Default fee when the routing failed (no ward / no coords). Kept very
/// conservative — the admin-tunable DeliveryConfig is the real pricing
/// source once a ward is resolved.
const DELIVERY_FEE_FALLBACK = 0;

const ORDER_INCLUDE = {
  items: true,
  address: true,
  store: { select: { id: true, name: true, slug: true } },
  statusEvents: { orderBy: { createdAt: 'asc' } },
  payments: { orderBy: { createdAt: 'desc' } },
  refunds: { orderBy: { createdAt: 'desc' } },
} satisfies Prisma.OrderInclude;

type OrderWithIncludes = Prisma.OrderGetPayload<{ include: typeof ORDER_INCLUDE }>;

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
    private readonly payments: PaymentsService,
    private readonly refunds: RefundsService,
    private readonly loyalty: LoyaltyService,
    private readonly coupons: CouponsService,
    private readonly notifications: NotificationsService,
    private readonly auth: AuthService,
    private readonly storeRouter: StoreRouterService,
    private readonly deliveryConfig: DeliveryConfigService,
    private readonly promotions: PromotionsService,
  ) {}

  /**
   * Creates an order in a single transaction with snapshot pricing — once
   * stored, line totals never recompute even if the product changes.
   *
   * After commit, delegates to PaymentsService to either record a CASH
   * payment row (pickup only) or hand back a redirect URL for Stripe / VNPay
   * / MoMo. The created order is returned with the resolved payment
   * instructions in `paymentInstructions`.
   */
  async create(
    authedCustomerId: string | null,
    dto: CreateOrderDto,
    customerIp: string,
  ): Promise<{
    order: OrderWithIncludes;
    payment: PaymentInstructions;
    /// Present only when a brand-new guest user was created during this
    /// order. Shape mirrors `/auth/register` so the customer app can pipe
    /// it straight into its auth controller (auto-log-in).
    guestSession?: object;
  }> {
    if (dto.fulfillmentType === 'DELIVERY' && !dto.address) {
      throw new BadRequestException({
        code: 'ADDRESS_REQUIRED',
        message: 'Delivery orders require an address.',
      });
    }
    this.payments.validate(dto.paymentMethod, dto.fulfillmentType);

    // VAT invoice — when requested, all four company fields are required so
    // the merchant has enough to issue a valid Vietnamese tax invoice.
    if (dto.requestVatInvoice) {
      const missing: string[] = [];
      if (!dto.invoiceCompanyName?.trim()) missing.push('tên công ty');
      if (!dto.invoiceTaxId?.trim()) missing.push('mã số thuế');
      if (!dto.invoiceAddress?.trim()) missing.push('địa chỉ công ty');
      if (!dto.invoiceEmail?.trim()) missing.push('email nhận hoá đơn');
      if (missing.length > 0) {
        throw new BadRequestException({
          code: 'INVOICE_FIELDS_REQUIRED',
          message: `Vui lòng điền: ${missing.join(', ')} để xuất hoá đơn VAT.`,
        });
      }
    }

    // Guest checkout — resolve the customer from the inline name/phone the
    // shopper just typed. Reuses an existing user if their phone is already
    // on file; otherwise creates a new CUSTOMER user with a random password.
    let customerId: string;
    let freshGuestUserId: string | null = null;
    // True when an UNAUTHENTICATED guest checkout resolved (by phone) to an
    // already-existing account. We must not let an anonymous shopper spend
    // that account's stored value (loyalty points), consume its per-user
    // coupons, or claim its membership/birthday/first-order benefits — the
    // phone was never verified (no OTP), so this could be account takeover.
    let guestBoundToExisting = false;
    if (authedCustomerId) {
      customerId = authedCustomerId;
    } else {
      if (!dto.guestFullName || !dto.guestPhone) {
        throw new BadRequestException({
          code: 'GUEST_INFO_REQUIRED',
          message: 'Guest checkout requires a name and phone number.',
        });
      }
      const guest = await this.upsertGuestCustomer({
        fullName: dto.guestFullName,
        phone: dto.guestPhone,
        email: dto.guestEmail,
      });
      customerId = guest.userId;
      if (guest.createdNew) {
        freshGuestUserId = guest.userId;
      } else {
        guestBoundToExisting = true;
      }
    }

    const productIds = [...new Set(dto.items.map((i) => i.productId))];
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds } },
      include: { variants: true },
      // leadTimeHours + availableDaysOfWeek are needed by assertProducts…().
      // They're regular scalar columns, so `include` already brings them in.
    });
    if (products.length !== productIds.length) {
      throw new BadRequestException({ code: 'PRODUCT_NOT_FOUND' });
    }

    const productById = new Map(products.map((p) => [p.id, p]));
    const productStoreIds = new Set(products.map((p) => p.storeId));
    if (productStoreIds.size !== 1) {
      throw new BadRequestException({
        code: 'CART_MULTI_STORE',
        message: 'All items must be from the same store.',
      });
    }
    // Pickup orders route to the customer-chosen branch.
    // Delivery prefers an explicit `deliveryStoreId` (rare — power-user
    // override). When absent, we auto-route to the *nearest open branch*
    // from the address ward centroid, so a customer in Thủ Đức is served
    // from the Thủ Đức branch instead of the catalog store. Falls back
    // to the catalog store only when ward routing returns nothing.
    let storeId = [...productStoreIds][0]!;
    if (dto.fulfillmentType === 'PICKUP' && dto.pickupStoreId) {
      const pickupStore = await this.prisma.store.findUnique({
        where: { id: dto.pickupStoreId },
        select: { id: true },
      });
      if (!pickupStore) {
        throw new BadRequestException({
          code: 'PICKUP_STORE_NOT_FOUND',
          message: 'The selected pickup branch is no longer available.',
        });
      }
      storeId = pickupStore.id;
    } else if (dto.fulfillmentType === 'DELIVERY') {
      if (dto.deliveryStoreId) {
        const dStore = await this.prisma.store.findUnique({
          where: { id: dto.deliveryStoreId },
          select: { id: true },
        });
        if (!dStore) {
          throw new BadRequestException({
            code: 'DELIVERY_STORE_NOT_FOUND',
            message: 'The selected delivery branch is no longer available.',
          });
        }
        storeId = dStore.id;
      } else {
        // Auto-route to nearest open branch by ward centroid.
        const routed = await this.storeRouter.pickNearestDeliveryStore(
          dto.address?.wardCode,
        );
        if (routed) {
          storeId = routed.storeId;
        }
        // If `routed` is null we keep the catalog store as last-resort
        // fallback — the assertStoreAcceptingOrder check below will still
        // reject if even that store is paused.
      }
    }

    // Reject orders placed outside the fulfilling branch's opening hours,
    // when the store is paused, or on a blackout date. Also enforces the
    // store's `defaultLeadHours` against scheduled time.
    // For scheduled orders we validate the requested time; otherwise now.
    const placedAt = new Date();
    const targetAt = dto.scheduledFor ? new Date(dto.scheduledFor) : placedAt;
    await this.assertStoreAcceptingOrder(
      storeId,
      dto.fulfillmentType,
      targetAt,
      placedAt,
      !!dto.scheduledFor,
    );

    // Per-product availability rules: days-of-week + advance-notice override.
    await this.assertProductsAcceptingOrder(
      products,
      targetAt,
      placedAt,
      !!dto.scheduledFor,
    );

    let subtotal = new Prisma.Decimal(0);
    const lineCreates: Prisma.OrderItemCreateManyOrderInput[] = [];

    for (const input of dto.items) {
      const product = productById.get(input.productId)!;
      if (!product.isAvailable) {
        throw new BadRequestException({
          code: 'PRODUCT_UNAVAILABLE',
          message: `${product.name} is no longer available.`,
        });
      }
      const variant = input.variantId
        ? product.variants.find((v) => v.id === input.variantId)
        : product.variants[0];
      if (!variant || !variant.isAvailable) {
        throw new BadRequestException({
          code: 'VARIANT_UNAVAILABLE',
          message: `Selected option for ${product.name} is unavailable.`,
        });
      }
      // Stock check for LIMITED variants. The hard race-safe decrement
      // lives inside the transaction below; this is the friendly early
      // rejection so the customer doesn't even get charged before we
      // realise we sold out.
      if (variant.stockMode === 'LIMITED') {
        const have = variant.stockQty ?? 0;
        if (have < input.quantity) {
          throw new BadRequestException({
            code: 'OUT_OF_STOCK',
            message: have <= 0
              ? `"${product.name}" đã hết hàng.`
              : `"${product.name}" chỉ còn ${have} cái — vui lòng giảm số lượng.`,
          });
        }
      }
      // Macaron-set flavour composition. When the product requires the
      // customer to pick N flavours, the composition lives in
      // `personalization.flavors` ({ "Jasmine": 3, "Lemon": 2 }). Validate
      // it sums to exactly N × quantity and every flavour is a known
      // option — defence-in-depth on top of the frontend gating.
      if (product.flavorPickCount && product.flavorPickCount > 0) {
        const flavors = (input.personalization?.flavors ?? {}) as Record<
          string,
          number
        >;
        const total = Object.values(flavors).reduce(
          (s, n) => s + (Number(n) || 0),
          0,
        );
        const need = product.flavorPickCount * input.quantity;
        if (total !== need) {
          throw new BadRequestException({
            code: 'FLAVOR_COUNT_MISMATCH',
            message:
              `"${product.name}" cần chọn đúng ${product.flavorPickCount} ` +
              `vị mỗi set (tổng ${need} cho ${input.quantity} set), ` +
              `bạn đang chọn ${total}.`,
          });
        }
        const allowed = new Set(product.flavorOptions);
        const unknown = Object.keys(flavors).find((f) => !allowed.has(f));
        if (unknown) {
          throw new BadRequestException({
            code: 'FLAVOR_UNKNOWN',
            message: `Vị "${unknown}" không có trong "${product.name}".`,
          });
        }
      }

      const unitPrice = new Prisma.Decimal(product.basePrice).plus(variant.priceDelta);
      const lineTotal = unitPrice.times(input.quantity);
      subtotal = subtotal.plus(lineTotal);

      lineCreates.push({
        productId: product.id,
        variantId: variant.id,
        productName: product.name,
        variantLabel: `${variant.size} · ${variant.flavor}`,
        quantity: input.quantity,
        unitPrice,
        customMessage: input.customMessage,
        // Personalization is free-form JSON — only kept when the wizard
        // captured something. Empty objects are normalised to null to
        // keep the column actually-nullable.
        personalization:
          input.personalization && Object.keys(input.personalization).length > 0
            ? (input.personalization as Prisma.InputJsonValue)
            : Prisma.JsonNull,
        lineTotal,
      });
    }

    const deliveryFeeVndRaw =
      dto.fulfillmentType === 'DELIVERY'
        ? await this.computeDeliveryFee(
            storeId,
            dto.address?.wardCode,
            productIds,
          )
        : 0;
    const deliveryFee = new Prisma.Decimal(deliveryFeeVndRaw);

    // ── Coupon validation (no DB write yet — that happens in the tx below).
    const subtotalVnd = Number(subtotal.toString());
    const deliveryFeeVnd = Number(deliveryFee.toString());

    // Enforce store's minimum order subtotal (set in store settings).
    await this.assertMinOrder(storeId, subtotalVnd);

    // Automatic promotion-engine discounts (product/category/flash/happy-hour).
    // Applied to the subtotal before the coupon so the coupon stacks on the
    // already-discounted amount.
    const promo = await this.promotions.evaluate({
      lines: lineCreates.map((l) => ({
        productId: l.productId,
        quantity: l.quantity,
        lineTotalVnd: Number(l.lineTotal.toString()),
      })),
      storeId,
      subtotalVnd,
      // Skip customer-targeted campaigns (membership / birthday / first-order /
      // re-activation) for a guest order bound to a pre-existing account.
      customerId: guestBoundToExisting ? undefined : customerId,
    });
    const campaignDiscountVnd = Math.min(promo.discountVnd, subtotalVnd);
    const subtotalAfterCampaign = subtotalVnd - campaignDiscountVnd;

    let couponDiscountVnd = 0;
    let couponId: string | null = null;
    if (dto.couponCode && !guestBoundToExisting) {
      const v = await this.coupons.validate({
        code: dto.couponCode,
        subtotalVnd: subtotalAfterCampaign,
        deliveryFeeVnd,
        userId: customerId,
        storeId,
      });
      couponDiscountVnd = v.discountVnd;
      couponId = v.coupon.id;
    }

    // Gift-card pre-check (friendly early rejection). The atomic decrement +
    // re-check happens inside the order transaction below.
    const giftCardCode = dto.giftCardCode?.trim().toUpperCase();
    if (giftCardCode) {
      const card = await this.prisma.giftCard.findUnique({
        where: { code: giftCardCode },
      });
      const expired =
        card?.expiresAt != null && card.expiresAt.getTime() < Date.now();
      if (!card || !card.isActive || expired || card.balanceVnd <= 0) {
        throw new BadRequestException({
          code: 'GIFT_CARD_INVALID',
          message: 'Mã thẻ quà tặng không hợp lệ, đã hết hạn hoặc hết số dư.',
        });
      }
    }

    // Order code generated up-front so loyalty messages reference the same code.
    const orderCode = generateOrderCode();

    const created = await this.prisma.$transaction(async (tx) => {
      let addressId: string | undefined;
      if (dto.address) {
        const addr = await tx.address.create({
          data: {
            userId: customerId,
            label: 'Delivery',
            recipient: dto.address.recipient,
            phone: dto.address.phone,
            line1: dto.address.line1,
            line2: dto.address.line2,
            city: dto.address.city,
            district: dto.address.district,
            wardCode: dto.address.wardCode,
          },
        });
        addressId = addr.id;
      }

      // Compute the final total including coupon and points discounts. We
      // run loyalty redemption inside the transaction so balance/event/order
      // are consistent — failures roll everything back.
      const couponDiscount = new Prisma.Decimal(couponDiscountVnd);

      const totalBeforePoints = new Prisma.Decimal(
        Math.max(0, subtotalAfterCampaign - couponDiscountVnd) + deliveryFeeVnd,
      );
      // Loyalty redemption: the customer chooses how many Micho to spend.
      // Capped at their balance and at the order value (never below 0). The
      // deduction itself happens after the order row exists (below) so the
      // REDEEM event references the order id — all inside this tx.
      // Never spend a pre-existing account's points on an unverified guest
      // order that merely matched its phone number.
      const requestedPoints = guestBoundToExisting
          ? 0
          : Math.max(0, Math.floor(dto.pointsToRedeem ?? 0));
      let pointsRedeemed = 0;
      let pointsDiscount = new Prisma.Decimal(0);
      if (requestedPoints > 0) {
        const lu = await tx.user.findUniqueOrThrow({
          where: { id: customerId },
          select: { pointsBalance: true },
        });
        const totalBeforePointsVnd = Math.round(
          Number(totalBeforePoints.toString()),
        );
        const maxByValue = Math.floor(
          totalBeforePointsVnd / LOYALTY_CONFIG.redemptionValueVnd,
        );
        pointsRedeemed = Math.max(
          0,
          Math.min(requestedPoints, lu.pointsBalance, maxByValue),
        );
        pointsDiscount = new Prisma.Decimal(
          pointsRedeemed * LOYALTY_CONFIG.redemptionValueVnd,
        );
      }

      const totalAfterPoints = totalBeforePoints.minus(pointsDiscount);

      // Gift-card redemption (balance-based). Re-fetch live in-txn, apply
      // min(balance, total), decrement atomically so two checkouts can't
      // double-spend the same balance.
      let giftCardAmountVnd = 0;
      let total = totalAfterPoints;
      if (giftCardCode) {
        const card = await tx.giftCard.findUnique({
          where: { code: giftCardCode },
        });
        const expired =
          card?.expiresAt != null && card.expiresAt.getTime() < Date.now();
        if (!card || !card.isActive || expired || card.balanceVnd <= 0) {
          throw new BadRequestException({ code: 'GIFT_CARD_INVALID' });
        }
        const totalVnd = Math.round(Number(totalAfterPoints.toString()));
        giftCardAmountVnd = Math.min(card.balanceVnd, totalVnd);
        if (giftCardAmountVnd > 0) {
          const dec = await tx.giftCard.updateMany({
            where: { id: card.id, balanceVnd: { gte: giftCardAmountVnd } },
            data: { balanceVnd: { decrement: giftCardAmountVnd } },
          });
          if (dec.count === 0) {
            throw new BadRequestException({ code: 'GIFT_CARD_INVALID' });
          }
          total = totalAfterPoints.minus(new Prisma.Decimal(giftCardAmountVnd));
        }
      }

      // Race-safe stock decrement for LIMITED variants — uses a
      // conditional updateMany so two parallel checkouts can't both
      // pass the early check above. If `count` comes back 0, someone
      // else just took the last unit and we roll the whole txn back.
      for (const line of lineCreates) {
        const variantId = line.variantId;
        if (!variantId) continue;
        const variant = productById
          .get(line.productId)!
          .variants.find((v) => v.id === variantId);
        if (!variant || variant.stockMode !== 'LIMITED') continue;
        const updated = await tx.productVariant.updateMany({
          where: {
            id: variantId,
            stockQty: { gte: line.quantity },
          },
          data: { stockQty: { decrement: line.quantity } },
        });
        if (updated.count === 0) {
          throw new BadRequestException({
            code: 'OUT_OF_STOCK',
            message:
              `"${line.productName}" vừa hết — một khách khác đã mua ` +
              `mất món cuối trong lúc bạn đặt. Vui lòng chọn món khác.`,
          });
        }
      }

      const order = await tx.order.create({
        data: {
          code: orderCode,
          customerId,
          storeId,
          fulfillmentType: dto.fulfillmentType,
          scheduledFor: dto.scheduledFor ? new Date(dto.scheduledFor) : null,
          addressId,
          status: 'PENDING',
          subtotal,
          deliveryFee,
          couponId,
          couponDiscount,
          campaignDiscount: new Prisma.Decimal(campaignDiscountVnd),
          campaignInfo:
            promo.applied.length > 0
              ? (promo.applied as unknown as Prisma.InputJsonValue)
              : Prisma.JsonNull,
          giftCardCode: giftCardAmountVnd > 0 ? giftCardCode : null,
          giftCardAmountVnd,
          pointsRedeemed,
          pointsDiscount,
          total,
          notes: dto.notes,
          isGift: dto.isGift ?? false,
          giftMessage: dto.isGift ? dto.giftMessage?.trim() || null : null,
          giftRecipientName: dto.isGift
            ? dto.giftRecipientName?.trim() || null
            : null,
          giftRecipientPhone: dto.isGift
            ? dto.giftRecipientPhone?.trim() || null
            : null,
          giftWrap: dto.isGift ? dto.giftWrap ?? false : false,
          hidePrice: dto.isGift ? dto.hidePrice ?? false : false,
          requestVatInvoice: dto.requestVatInvoice ?? false,
          invoiceCompanyName: dto.invoiceCompanyName?.trim() || null,
          invoiceTaxId: dto.invoiceTaxId?.trim() || null,
          invoiceAddress: dto.invoiceAddress?.trim() || null,
          invoiceEmail: dto.invoiceEmail?.trim() || null,
          items: { createMany: { data: lineCreates } },
          statusEvents: {
            create: {
              fromStatus: null,
              toStatus: 'PENDING',
              actorId: customerId,
              note: 'Order placed',
            },
          },
        },
        include: ORDER_INCLUDE,
      });

      if (couponId) {
        await this.coupons.recordRedemption({
          couponId,
          userId: customerId,
          orderId: order.id,
          tx,
        });
      }
      if (pointsRedeemed > 0) {
        await this.loyalty.redeemWithinTx(tx, {
          userId: customerId,
          orderId: order.id,
          orderCode,
          points: pointsRedeemed,
        });
      }

      return order;
    });

    // When a gift card fully covers the order, there's nothing left to charge
    // a gateway for — route to the cash provider (records a 0₫ payment) so we
    // never hand VNPay/Stripe a zero amount.
    const effectiveMethod =
      Number(created.total.toString()) <= 0 ? 'CASH' : dto.paymentMethod;
    const paymentInstructions = await this.payments.initiate({
      order: created,
      paymentMethod: effectiveMethod,
      customerIp,
    });

    // Re-fetch to include the freshly-written Payment row.
    const order = await this.prisma.order.findUniqueOrThrow({
      where: { id: created.id },
      include: ORDER_INCLUDE,
    });

    this.realtime.emit(
      [`store:${storeId}`, `user:${customerId}`],
      'order.created',
      this.toEventPayload(order),
    );

    // Alert the fulfilling store's staff — in-app + web push (with sound on
    // the open merchant screen). Fire-and-forget; never blocks the order.
    void this.notifications.notifyStoreStaff(
      storeId,
      {
        type: 'order_new',
        title: `Đơn mới · ${order.code}`,
        body:
          `${order.items.length} món · ` +
          `${order.fulfillmentType === 'DELIVERY' ? 'Giao hàng' : 'Lấy tại quầy'}`,
      },
      { code: order.code },
    );

    // For fresh guest users only: issue auth tokens AND echo the full user
    // view (matching /auth/register shape). The customer-facing app pipes
    // this into its auth controller to auto-log-in.
    let guestSession: object | undefined;
    if (freshGuestUserId) {
      const user = await this.prisma.user.findUniqueOrThrow({
        where: { id: freshGuestUserId },
      });
      const tokens = await this.auth.issueSessionForUser(user);
      guestSession = {
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        user: {
          id: user.id,
          email: user.email,
          phone: user.phone,
          fullName: user.fullName,
          avatarUrl: user.avatarUrl,
          role: user.role,
          membershipTier: user.membershipTier,
          pointsBalance: user.pointsBalance,
          birthday: user.birthday?.toISOString() ?? null,
          storeId: user.storeId,
          kitchenId: user.kitchenId,
        },
      };
    }

    return { order, payment: paymentInstructions, guestSession };
  }

  async findOne(
    id: string,
    principal: { sub: string; role: Role; storeId?: string | null; kitchenId?: string | null },
  ): Promise<OrderWithIncludes> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: ORDER_INCLUDE,
    });
    if (!order) throw new NotFoundException({ code: 'ORDER_NOT_FOUND' });
    this.assertCanRead(order, principal);
    return order;
  }

  async listForCustomer(customerId: string, page = 1, perPage = 20) {
    const skip = (page - 1) * perPage;
    const [items, total] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        where: { customerId },
        include: ORDER_INCLUDE,
        orderBy: { createdAt: 'desc' },
        skip,
        take: perPage,
      }),
      this.prisma.order.count({ where: { customerId } }),
    ]);
    return { items, meta: { page, perPage, total } };
  }

  async listForStore(
    storeId: string | null,
    opts: { status?: OrderStatus; page?: number; perPage?: number },
  ) {
    const page = opts.page ?? 1;
    const perPage = opts.perPage ?? 30;
    // `storeId == null` → admin view, no scope. We spread the storeId key
    // only when set so Prisma never receives `{ storeId: null }`, which
    // would fail against the non-nullable foreign key column.
    const where: Prisma.OrderWhereInput = {
      ...(storeId != null && { storeId }),
      ...(opts.status && { status: opts.status }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        where,
        include: ORDER_INCLUDE,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.order.count({ where }),
    ]);
    return { items, meta: { page, perPage, total } };
  }

  async transition(
    id: string,
    toStatus: OrderStatus,
    actor: { sub: string; role: Role; storeId?: string | null; kitchenId?: string | null },
    note?: string,
  ): Promise<OrderWithIncludes> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: ORDER_INCLUDE,
    });
    if (!order) throw new NotFoundException({ code: 'ORDER_NOT_FOUND' });
    this.assertCanWrite(order, actor);
    if (!isAllowedTransition(order.status, toStatus)) {
      throw new BadRequestException({
        code: 'ORDER_INVALID_TRANSITION',
        message: `Cannot move from ${order.status} to ${toStatus}.`,
      });
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      const next = await tx.order.update({
        where: { id },
        data: { status: toStatus },
        include: ORDER_INCLUDE,
      });
      await tx.orderStatusEvent.create({
        data: {
          orderId: id,
          fromStatus: order.status,
          toStatus,
          actorId: actor.sub,
          note,
        },
      });
      return next;
    });

    // Side-effects: cash gets captured on completion; uncaptured payments
    // get voided on cancellation. (Real refunds for captured Stripe/VNPay/MoMo
    // payments arrive in M5.)
    if (toStatus === 'COMPLETED') {
      await this.payments.onOrderCompleted(id);
      await this.loyalty.earnFor(order);
    } else if (toStatus === 'CANCELLED') {
      await this.loyalty.refundRedemption(id);
      const { capturedPayments } = await this.payments.onOrderCancelled(id);
      for (const payment of capturedPayments) {
        await this.refunds.createRequest({
          order,
          payment,
          reason: note ?? 'Order cancelled',
          requestedById: actor.sub,
        });
      }
      await this.restoreInventory(id);
    }

    const rooms = [
      `order:${id}`,
      `user:${order.customerId}`,
      `store:${order.storeId}`,
    ];
    if (order.kitchenId) rooms.push(`kitchen:${order.kitchenId}`);
    this.realtime.emit(rooms, 'order.status_changed', {
      orderId: id,
      code: order.code,
      fromStatus: order.status,
      toStatus,
      at: new Date().toISOString(),
    });

    // Push a customer-facing notification (in-app + future FCM).
    await this.notifications.sendToUser(
      order.customerId,
      orderStatusNotification(order.code, toStatus),
      { orderId: id, code: order.code, status: toStatus },
    );

    return updated;
  }

  async customerCancel(id: string, customerId: string, reason?: string): Promise<OrderWithIncludes> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: ORDER_INCLUDE,
    });
    if (!order) throw new NotFoundException({ code: 'ORDER_NOT_FOUND' });
    if (order.customerId !== customerId) {
      throw new ForbiddenException({ code: 'AUTH_FORBIDDEN' });
    }
    if (!canCustomerCancel(order.status)) {
      throw new BadRequestException({
        code: 'ORDER_NOT_CANCELLABLE',
        message: 'This order can no longer be cancelled by you.',
      });
    }
    return this.transition(
      id,
      'CANCELLED',
      { sub: customerId, role: 'CUSTOMER' },
      reason ?? 'Customer cancelled',
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Central kitchen handoff (M6)
  // ────────────────────────────────────────────────────────────────────────

  /**
   * Merchant transfers an in-preparation order to the central kitchen.
   * The order's `status` flips to SENT_TO_KITCHEN and `kitchenStatus`
   * starts at PREPARING. Routes to the store's `defaultKitchenId` unless
   * the merchant overrides via `kitchenId`.
   */
  /**
   * Merchant marks the VAT invoice as issued. Fills `invoiceIssuedAt` to
   * now (or clears the marker — re-issuing is uncommon but allowed for
   * fix-ups). The actual hoá đơn PDF is hosted on the merchant's external
   * provider; we just persist the URL so the customer can download it.
   */
  async issueInvoice(
    id: string,
    actor: { sub: string; role: Role; storeId?: string | null },
    invoiceFileUrl?: string,
  ): Promise<OrderWithIncludes> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: ORDER_INCLUDE,
    });
    if (!order) throw new NotFoundException({ code: 'ORDER_NOT_FOUND' });
    this.assertCanWrite(order, actor);
    if (!order.requestVatInvoice) {
      throw new BadRequestException({
        code: 'NO_INVOICE_REQUESTED',
        message: 'Đơn này không yêu cầu xuất hoá đơn VAT.',
      });
    }
    const updated = await this.prisma.order.update({
      where: { id },
      data: {
        invoiceIssuedAt: new Date(),
        invoiceFileUrl: invoiceFileUrl ?? order.invoiceFileUrl,
      },
      include: ORDER_INCLUDE,
    });
    this.realtime.emit(
      [`store:${updated.storeId}`, `user:${updated.customerId}`],
      'order.status_changed',
      this.toEventPayload(updated),
    );
    return updated;
  }

  async transferToKitchen(
    id: string,
    actor: { sub: string; role: Role; storeId?: string | null },
    opts: { kitchenId?: string; note?: string } = {},
  ): Promise<OrderWithIncludes> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: { ...ORDER_INCLUDE, store: { select: { id: true, name: true, slug: true, defaultKitchenId: true } } },
    });
    if (!order) throw new NotFoundException({ code: 'ORDER_NOT_FOUND' });
    this.assertCanWrite(order, actor);
    if (!isAllowedTransition(order.status, 'SENT_TO_KITCHEN')) {
      throw new BadRequestException({
        code: 'ORDER_INVALID_TRANSITION',
        message: `Order in ${order.status} cannot be transferred to a kitchen.`,
      });
    }
    const kitchenId = opts.kitchenId ?? order.store.defaultKitchenId;
    if (!kitchenId) {
      throw new BadRequestException({
        code: 'NO_KITCHEN_AVAILABLE',
        message: 'No kitchen specified and the store has no default kitchen.',
      });
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      const next = await tx.order.update({
        where: { id },
        data: {
          status: 'SENT_TO_KITCHEN',
          // Newly transferred orders sit at PENDING_ACK so kitchen staff
          // explicitly accept before they start preparing.
          kitchenStatus: 'PENDING_ACK',
          kitchenId,
        },
        include: ORDER_INCLUDE,
      });
      await tx.orderStatusEvent.create({
        data: {
          orderId: id,
          fromStatus: order.status,
          toStatus: 'SENT_TO_KITCHEN',
          actorId: actor.sub,
          note: opts.note ?? 'Transferred to central kitchen',
        },
      });
      return next;
    });

    this.realtime.emit(
      [
        `order:${id}`,
        `user:${order.customerId}`,
        `store:${order.storeId}`,
        `kitchen:${kitchenId}`,
      ],
      'order.status_changed',
      {
        orderId: id,
        code: order.code,
        fromStatus: order.status,
        toStatus: 'SENT_TO_KITCHEN',
        // Mirror what we persisted (PENDING_ACK) so listeners don't show the
        // order in the wrong kitchen column until the next refetch.
        kitchenStatus: updated.kitchenStatus,
        at: new Date().toISOString(),
      },
    );

    await this.notifications.sendToUser(
      order.customerId,
      orderStatusNotification(order.code, 'SENT_TO_KITCHEN'),
      { orderId: id, code: order.code, status: 'SENT_TO_KITCHEN' },
    );

    // Alert the kitchen's staff — in-app + web push (sound on the open
    // kitchen board). Fire-and-forget.
    void this.notifications.notifyKitchenStaff(
      kitchenId,
      {
        type: 'kitchen_new',
        title: `Đơn vào bếp · ${order.code}`,
        body: `${order.items.length} món cần chuẩn bị.`,
      },
      { code: order.code },
    );

    return updated;
  }

  /**
   * Kitchen kanban transition: PREPARING → BAKING → COOLING → DECORATING →
   * PACKED → READY_DISPATCH. Forward-only. Caller must be the kitchen
   * staffing this kitchen (or admin).
   */
  async transitionKitchen(
    id: string,
    toKitchenStatus: KitchenStatus,
    actor: { sub: string; role: Role; kitchenId?: string | null },
  ): Promise<OrderWithIncludes> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: ORDER_INCLUDE,
    });
    if (!order) throw new NotFoundException({ code: 'ORDER_NOT_FOUND' });
    this.assertKitchenScope(order, actor);
    if (!isAllowedKitchenTransition(order.kitchenStatus, toKitchenStatus)) {
      throw new BadRequestException({
        code: 'KITCHEN_INVALID_TRANSITION',
        message: `Cannot move kitchen status from ${order.kitchenStatus ?? 'null'} to ${toKitchenStatus}.`,
      });
    }
    const updated = await this.prisma.order.update({
      where: { id },
      data: { kitchenStatus: toKitchenStatus },
      include: ORDER_INCLUDE,
    });
    this.realtime.emit(
      [
        `order:${id}`,
        `user:${order.customerId}`,
        `store:${order.storeId}`,
        `kitchen:${order.kitchenId!}`,
      ],
      'order.kitchen_status_changed',
      {
        orderId: id,
        code: order.code,
        fromKitchenStatus: order.kitchenStatus,
        toKitchenStatus,
        at: new Date().toISOString(),
      },
    );

    await this.notifications.sendToUser(
      order.customerId,
      kitchenStatusNotification(order.code, toKitchenStatus),
      { orderId: id, code: order.code, kitchenStatus: toKitchenStatus },
    );

    return updated;
  }

  /**
   * Kitchen finishes a card on READY_DISPATCH and hands it back to the
   * store. Order status moves to DELIVERING (delivery orders) or
   * READY_FOR_PICKUP (pickup). Kitchen status stays at READY_DISPATCH so the
   * card disappears from the kanban (filtered by status).
   */
  async dispatchFromKitchen(
    id: string,
    actor: { sub: string; role: Role; kitchenId?: string | null },
  ): Promise<OrderWithIncludes> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: ORDER_INCLUDE,
    });
    if (!order) throw new NotFoundException({ code: 'ORDER_NOT_FOUND' });
    this.assertKitchenScope(order, actor);
    if (order.kitchenStatus !== 'READY_DISPATCH') {
      throw new BadRequestException({
        code: 'KITCHEN_NOT_READY',
        message: 'Order is not at READY_DISPATCH yet.',
      });
    }
    const targetOrderStatus: OrderStatus =
      order.fulfillmentType === 'DELIVERY' ? 'DELIVERING' : 'READY_FOR_PICKUP';

    const updated = await this.prisma.$transaction(async (tx) => {
      const next = await tx.order.update({
        where: { id },
        data: { status: targetOrderStatus },
        include: ORDER_INCLUDE,
      });
      await tx.orderStatusEvent.create({
        data: {
          orderId: id,
          fromStatus: order.status,
          toStatus: targetOrderStatus,
          actorId: actor.sub,
          note: 'Dispatched from central kitchen',
        },
      });
      return next;
    });

    this.realtime.emit(
      [
        `order:${id}`,
        `user:${order.customerId}`,
        `store:${order.storeId}`,
        `kitchen:${order.kitchenId!}`,
      ],
      'order.status_changed',
      {
        orderId: id,
        code: order.code,
        fromStatus: order.status,
        toStatus: targetOrderStatus,
        at: new Date().toISOString(),
      },
    );

    // Notify the customer that their order is ready / out for delivery —
    // the kitchen dispatch bypasses transition(), which would otherwise
    // send this. (in-app + push)
    await this.notifications.sendToUser(
      order.customerId,
      orderStatusNotification(order.code, targetOrderStatus),
      { orderId: id, code: order.code, status: targetOrderStatus },
    );

    return updated;
  }

  /**
   * Kanban view: orders that are currently routed to a kitchen and not
   * dispatched yet. With `includeDoneToday`, also returns orders dispatched
   * back to the store today — for the "Completed" column on the kanban.
   */
  async listForKitchen(
    kitchenId: string,
    opts: { status?: KitchenStatus | null; includeDoneToday?: boolean } = {},
  ) {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const where: Prisma.OrderWhereInput = opts.includeDoneToday
      ? {
          kitchenId,
          OR: [
            // Still routed to the kitchen.
            {
              status: 'SENT_TO_KITCHEN',
              ...(opts.status !== undefined && { kitchenStatus: opts.status }),
            },
            // Dispatched back today — the "Completed" column.
            {
              status: { in: ['READY_FOR_PICKUP', 'DELIVERING', 'COMPLETED'] },
              updatedAt: { gte: startOfToday },
            },
          ],
        }
      : {
          kitchenId,
          status: 'SENT_TO_KITCHEN',
          ...(opts.status !== undefined && { kitchenStatus: opts.status }),
        };
    return this.prisma.order.findMany({
      where,
      include: ORDER_INCLUDE,
      orderBy: { updatedAt: 'asc' },
    });
  }

  /**
   * Reject orders placed outside the fulfilling branch's opening hours.
   * `openingHours` is `{ mon: [["10:00","21:30"]], ... }`. Times are
   * interpreted in Vietnam local time (UTC+7, no DST). When closed, the
   * error message suggests the next opening slot so the customer can
   * use "Schedule for later".
   */
  private async assertStoreAcceptingOrder(
    storeId: string,
    channel: 'PICKUP' | 'DELIVERY',
    at: Date,
    placedAt: Date,
    scheduled: boolean,
  ): Promise<void> {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: {
        openingHours: true,
        name: true,
        isPaused: true,
        isPickupPaused: true,
        isDeliveryPaused: true,
        pauseReason: true,
        defaultLeadHours: true,
      },
    });
    if (!store) return;

    // 1) Pause checks — three levels of granularity:
    //    - master pause     → blocks every order
    //    - pickup pause     → blocks only PICKUP
    //    - delivery pause   → blocks only DELIVERY
    if (store.isPaused) {
      throw new BadRequestException({
        code: 'STORE_PAUSED',
        message: store.pauseReason?.trim()
          ? `${store.name} đang tạm dừng nhận đơn: ${store.pauseReason}`
          : `${store.name} đang tạm dừng nhận đơn.`,
      });
    }
    if (channel === 'PICKUP' && store.isPickupPaused) {
      throw new BadRequestException({
        code: 'STORE_PICKUP_PAUSED',
        message: store.pauseReason?.trim()
          ? `${store.name} đang tạm dừng nhận đơn tự lấy: ${store.pauseReason}`
          : `${store.name} đang tạm dừng nhận đơn tự lấy. Vui lòng đặt giao hàng hoặc thử chi nhánh khác.`,
      });
    }
    if (channel === 'DELIVERY' && store.isDeliveryPaused) {
      throw new BadRequestException({
        code: 'STORE_DELIVERY_PAUSED',
        message: store.pauseReason?.trim()
          ? `${store.name} đang tạm dừng giao hàng: ${store.pauseReason}`
          : `${store.name} đang tạm dừng giao hàng. Vui lòng đặt tự lấy hoặc thử chi nhánh khác.`,
      });
    }

    // 2) Blackout date — block orders whose target falls on a closed day.
    //    Compare in VN local time so the calendar matches what the merchant
    //    sees in the settings screen.
    const toVnDateOnly = (d: Date) => {
      const vn = new Date(d.getTime() + 7 * 3600 * 1000);
      return new Date(Date.UTC(vn.getUTCFullYear(), vn.getUTCMonth(), vn.getUTCDate()));
    };
    const blackout = await this.prisma.storeBlackoutDate.findUnique({
      where: { storeId_date: { storeId, date: toVnDateOnly(at) } },
      select: { reason: true, date: true },
    });
    if (blackout) {
      const ymd = blackout.date.toISOString().slice(0, 10);
      throw new BadRequestException({
        code: 'STORE_BLACKOUT',
        message: blackout.reason
          ? `${store.name} đóng cửa ngày ${ymd} (${blackout.reason}).`
          : `${store.name} đóng cửa ngày ${ymd}.`,
      });
    }

    // 3) Store-wide minimum lead time (in hours) — gives staff time to bake.
    //    Skipped when defaultLeadHours = 0 (default).
    if (store.defaultLeadHours > 0) {
      const minMs = store.defaultLeadHours * 3600 * 1000;
      if (at.getTime() - placedAt.getTime() < minMs) {
        throw new BadRequestException({
          code: 'STORE_LEAD_TIME',
          message: scheduled
            ? `Cần đặt trước ít nhất ${store.defaultLeadHours} giờ. Vui lòng chọn thời gian khác.`
            : `Cửa hàng cần ${store.defaultLeadHours} giờ chuẩn bị. Dùng "Đặt trước theo lịch" để chọn thời gian.`,
        });
      }
    }

    // 4) Opening hours — same logic as before but on the expanded check.
    const hours = store.openingHours as
      | Record<string, [string, string][]>
      | null;
    if (!hours || Object.keys(hours).length === 0) return; // 24/7

    const toMin = (hhmm: string) => {
      const [h, m] = hhmm.split(':').map(Number);
      return h * 60 + m;
    };
    const dayKeys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

    // Shift to VN local time so weekday + minutes are correct.
    const toVn = (d: Date) => new Date(d.getTime() + 7 * 3600 * 1000);
    const vn = toVn(at);
    const key = dayKeys[vn.getUTCDay()];
    const minutes = vn.getUTCHours() * 60 + vn.getUTCMinutes();
    const todays = hours[key] ?? [];
    const isOpen = todays.some(
      ([o, c]) => minutes >= toMin(o) && minutes <= toMin(c),
    );
    if (isOpen) return;

    // Find the next opening datetime within the next 8 days.
    let nextLabel: string | null = null;
    for (let i = 0; i < 8 && !nextLabel; i++) {
      const probe = new Date(vn.getTime() + i * 24 * 3600 * 1000);
      const dk = dayKeys[probe.getUTCDay()];
      const wins = hours[dk] ?? [];
      for (const [o] of wins) {
        const openMin = toMin(o);
        if (i === 0 && openMin <= minutes) continue; // already past today
        const dayName = [
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ][probe.getUTCDay()];
        const when = i === 0 ? 'today' : i === 1 ? 'tomorrow' : dayName;
        nextLabel = `${when} at ${o}`;
        break;
      }
    }

    const subject = scheduled
      ? `${store.name} đóng cửa vào thời điểm bạn chọn`
      : `${store.name} hiện đang đóng cửa`;
    throw new BadRequestException({
      code: 'STORE_CLOSED',
      message: nextLabel
        ? `${subject}. Mở cửa lại: ${nextLabel}. Mẹo: dùng "Đặt trước theo lịch" để hẹn giờ.`
        : `${subject}.`,
    });
  }

  /**
   * Enforces per-product `availableDaysOfWeek` (days the product is sold) and
   * per-product `leadTimeHours` (advance notice override). Store-wide lead
   * time is checked separately in `assertStoreAcceptingOrder`; whichever is
   * larger effectively wins, since both must pass.
   */
  private async assertProductsAcceptingOrder(
    products: { id: string; name: string; leadTimeHours: number | null; availableDaysOfWeek: number[] }[],
    at: Date,
    placedAt: Date,
    scheduled: boolean,
  ): Promise<void> {
    // VN local weekday for day-of-week comparison.
    const vn = new Date(at.getTime() + 7 * 3600 * 1000);
    const dow = vn.getUTCDay(); // 0=Sun..6=Sat

    for (const p of products) {
      if (
        p.availableDaysOfWeek &&
        p.availableDaysOfWeek.length > 0 &&
        !p.availableDaysOfWeek.includes(dow)
      ) {
        const names = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
        const allowed = p.availableDaysOfWeek
          .map((d) => names[d] ?? `?${d}`)
          .join(', ');
        throw new BadRequestException({
          code: 'PRODUCT_DAY_UNAVAILABLE',
          message: `${p.name} chỉ bán vào ${allowed}. Vui lòng chọn ngày khác hoặc loại bỏ khỏi giỏ hàng.`,
        });
      }

      if (p.leadTimeHours && p.leadTimeHours > 0) {
        const minMs = p.leadTimeHours * 3600 * 1000;
        if (at.getTime() - placedAt.getTime() < minMs) {
          throw new BadRequestException({
            code: 'PRODUCT_LEAD_TIME',
            message: scheduled
              ? `${p.name} cần đặt trước ít nhất ${p.leadTimeHours} giờ. Vui lòng chọn thời gian khác.`
              : `${p.name} cần đặt trước ${p.leadTimeHours} giờ. Hãy dùng "Đặt trước theo lịch".`,
          });
        }
      }
    }
  }

  /**
   * Resolves the delivery fee using the admin-tunable `DeliveryConfig`:
   *   - picks the standard or birthday-cake tier (any cart item in the
   *     birthday-cake collection switches to the higher tier)
   *   - picks the under/over band by comparing haversine distance from
   *     the fulfilling store to the address ward centroid
   *
   * Falls back to `DELIVERY_FEE_FALLBACK` only when ward / store coords
   * are missing — the routing already prefers stores with coords, so this
   * branch is rarely hit in practice.
   */
  private async computeDeliveryFee(
    storeId: string,
    wardCode: string | null | undefined,
    productIds: string[],
  ): Promise<number> {
    const cfg = await this.deliveryConfig.get();
    const hasBirthdayCake = await this.deliveryConfig.cartHasBirthdayCake(
      productIds,
      cfg,
    );
    // No customer ward → treat as "other ward" so we never undercharge.
    if (!wardCode) {
      return hasBirthdayCake
        ? cfg.birthdayCakeFeeOtherWardVnd
        : cfg.standardFeeOtherWardVnd;
    }
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { wardCode: true },
    });
    return this.deliveryConfig.feeFor(
      cfg,
      wardCode,
      store?.wardCode ?? null,
      hasBirthdayCake,
    );
  }

  /// Enforces store's minimum order subtotal (₫). 0 = no minimum.
  private async assertMinOrder(storeId: string, subtotalVnd: number): Promise<void> {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { minOrderVnd: true, name: true },
    });
    if (!store || !store.minOrderVnd || store.minOrderVnd <= 0) return;
    if (subtotalVnd < store.minOrderVnd) {
      const fmt = new Intl.NumberFormat('vi-VN').format(store.minOrderVnd);
      throw new BadRequestException({
        code: 'MIN_ORDER_NOT_MET',
        message: `Đơn tối thiểu tại ${store.name} là ${fmt} ₫. Vui lòng thêm sản phẩm vào giỏ.`,
      });
    }
  }

  /**
   * Find-or-create a CUSTOMER user for a guest checkout. Keyed by phone
   * (which is unique on User). If the email is also given and free, it's
   * saved; otherwise we synthesise `guest+{uuid}@banan.local` so the unique
   * email constraint never blocks the order. The generated password is
   * random — guest users can recover access later via password reset.
   */
  private async upsertGuestCustomer(args: {
    fullName: string;
    phone: string;
    email?: string;
  }): Promise<{ userId: string; createdNew: boolean }> {
    const existing = await this.prisma.user.findUnique({
      where: { phone: args.phone },
      select: { id: true, claimed: true, role: true },
    });
    if (existing) {
      // Anti-takeover: only an UNCLAIMED, CUSTOMER-role stub (a prior guest or
      // a merchant-created phone customer) is safe to reuse, so a returning
      // guest's orders still aggregate. A claimed account, or any staff /
      // kitchen / admin account, must never be bound to an unverified guest
      // order — force the shopper to log in instead.
      if (existing.claimed || existing.role !== 'CUSTOMER') {
        throw new BadRequestException({
          code: 'PHONE_HAS_ACCOUNT',
          message:
            'Số điện thoại này đã có tài khoản. Vui lòng đăng nhập để đặt hàng.',
        });
      }
      return { userId: existing.id, createdNew: false };
    }

    // Email may collide — synthesise a unique one when omitted or taken.
    const normalisedEmail = args.email?.toLowerCase();
    const emailInUse = normalisedEmail
      ? (await this.prisma.user.findUnique({
          where: { email: normalisedEmail },
          select: { id: true },
        })) !== null
      : false;
    const finalEmail = normalisedEmail && !emailInUse
      ? normalisedEmail
      : `guest+${randomBytes(8).toString('hex')}@banan.local`;

    const password = randomBytes(24).toString('base64url');
    const passwordHash = await bcrypt.hash(password, 12);

    const user = await this.prisma.user.create({
      data: {
        email: finalEmail,
        phone: args.phone,
        passwordHash,
        fullName: args.fullName,
        role: 'CUSTOMER',
        // A guest never opted into marketing — don't sweep them into campaign
        // audiences (esp. when the email is the synthetic guest+…@banan.local).
        marketingOptIn: false,
      },
      select: { id: true },
    });
    return { userId: user.id, createdNew: true };
  }

  private assertKitchenScope(
    order: { kitchenId: string | null },
    actor: { role: Role; kitchenId?: string | null },
  ) {
    if (actor.role === 'ADMIN') return;
    if (
      (actor.role === 'KITCHEN_MANAGER' || actor.role === 'KITCHEN_STAFF') &&
      actor.kitchenId &&
      actor.kitchenId === order.kitchenId
    ) {
      return;
    }
    throw new ForbiddenException({ code: 'AUTH_FORBIDDEN' });
  }

  private assertCanRead(
    order: { customerId: string; storeId: string; kitchenId: string | null },
    principal: { sub: string; role: Role; storeId?: string | null; kitchenId?: string | null },
  ) {
    if (principal.role === 'ADMIN') return;
    if (principal.role === 'CUSTOMER' && order.customerId === principal.sub) return;
    if (
      (principal.role === 'MERCHANT_OWNER' || principal.role === 'MERCHANT_STAFF') &&
      principal.storeId === order.storeId
    ) {
      return;
    }
    if (
      (principal.role === 'KITCHEN_MANAGER' || principal.role === 'KITCHEN_STAFF') &&
      principal.kitchenId === order.kitchenId
    ) {
      return;
    }
    throw new ForbiddenException({ code: 'AUTH_FORBIDDEN' });
  }

  private assertCanWrite(
    order: { storeId: string; kitchenId: string | null; customerId: string },
    principal: { sub: string; role: Role; storeId?: string | null; kitchenId?: string | null },
  ) {
    if (principal.role === 'ADMIN') return;
    if (
      (principal.role === 'MERCHANT_OWNER' || principal.role === 'MERCHANT_STAFF') &&
      principal.storeId === order.storeId
    ) {
      return;
    }
    if (
      (principal.role === 'KITCHEN_MANAGER' || principal.role === 'KITCHEN_STAFF') &&
      principal.kitchenId === order.kitchenId
    ) {
      return;
    }
    // The order's own customer may write to it — in practice only to cancel.
    // `customerCancel` is the sole path that hands a CUSTOMER actor to
    // `transition`, and it already enforces ownership + `canCustomerCancel`
    // (PENDING/ACCEPTED → CANCELLED only). The merchant transition endpoint
    // is role-locked, so a customer can never reach an arbitrary status here.
    if (principal.role === 'CUSTOMER' && principal.sub === order.customerId) {
      return;
    }
    throw new ForbiddenException({ code: 'AUTH_FORBIDDEN' });
  }

  private toEventPayload(order: OrderWithIncludes) {
    return {
      orderId: order.id,
      code: order.code,
      status: order.status,
      total: order.total.toString(),
      itemCount: order.items.reduce((sum, i) => sum + i.quantity, 0),
      createdAt: order.createdAt.toISOString(),
      customerId: order.customerId,
      storeId: order.storeId,
    };
  }

  /// Cancellation reverse-step for #13 (inventory). Walks the order's
  /// LIMITED-variant lines and increments stockQty back. Best-effort —
  /// log if a variant has been deleted in the meantime.
  private async restoreInventory(orderId: string): Promise<void> {
    const items = await this.prisma.orderItem.findMany({
      where: { orderId, variantId: { not: null } },
      include: {
        variant: { select: { id: true, stockMode: true } },
      },
    });
    for (const i of items) {
      if (!i.variant || i.variant.stockMode !== 'LIMITED') continue;
      await this.prisma.productVariant.update({
        where: { id: i.variant.id },
        data: { stockQty: { increment: i.quantity } },
      });
    }
  }
}
