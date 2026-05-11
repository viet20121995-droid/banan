import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { KitchenStatus, OrderStatus, Prisma, Role } from '@prisma/client';

import { CouponsService } from '../coupons/coupons.service';
import { LoyaltyService } from '../loyalty/loyalty.service';
import {
  kitchenStatusNotification,
  orderStatusNotification,
} from '../notifications/notification-templates';
import { NotificationsService } from '../notifications/notifications.service';
import type { PaymentInstructions } from '../payments/dto/payment-instructions';
import { PaymentsService } from '../payments/payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { RefundsService } from '../refunds/refunds.service';

import type { CreateOrderDto } from './dto/create-order.dto';
import { generateOrderCode } from './order-code';
import {
  canCustomerCancel,
  isAllowedKitchenTransition,
  isAllowedTransition,
} from './order-status';

const DELIVERY_FEE = 30000;

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
    customerId: string,
    dto: CreateOrderDto,
    customerIp: string,
  ): Promise<{ order: OrderWithIncludes; payment: PaymentInstructions }> {
    if (dto.fulfillmentType === 'DELIVERY' && !dto.address) {
      throw new BadRequestException({
        code: 'ADDRESS_REQUIRED',
        message: 'Delivery orders require an address.',
      });
    }
    this.payments.validate(dto.paymentMethod, dto.fulfillmentType);

    const productIds = [...new Set(dto.items.map((i) => i.productId))];
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds } },
      include: { variants: true },
    });
    if (products.length !== productIds.length) {
      throw new BadRequestException({ code: 'PRODUCT_NOT_FOUND' });
    }

    const productById = new Map(products.map((p) => [p.id, p]));
    const storeIds = new Set(products.map((p) => p.storeId));
    if (storeIds.size !== 1) {
      throw new BadRequestException({
        code: 'CART_MULTI_STORE',
        message: 'All items must be from the same store.',
      });
    }
    const storeId = [...storeIds][0]!;

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
        lineTotal,
      });
    }

    const deliveryFee = dto.fulfillmentType === 'DELIVERY'
      ? new Prisma.Decimal(DELIVERY_FEE)
      : new Prisma.Decimal(0);

    // ── Coupon validation (no DB write yet — that happens in the tx below).
    const subtotalVnd = Number(subtotal.toString());
    const deliveryFeeVnd = Number(deliveryFee.toString());
    let couponDiscountVnd = 0;
    let couponId: string | null = null;
    if (dto.couponCode) {
      const v = await this.coupons.validate({
        code: dto.couponCode,
        subtotalVnd,
        deliveryFeeVnd,
        userId: customerId,
      });
      couponDiscountVnd = v.discountVnd;
      couponId = v.coupon.id;
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
          },
        });
        addressId = addr.id;
      }

      // Compute the final total including coupon and points discounts. We
      // run loyalty redemption inside the transaction so balance/event/order
      // are consistent — failures roll everything back.
      const couponDiscount = new Prisma.Decimal(couponDiscountVnd);
      const subtotalAfterCoupon = Math.max(0, subtotalVnd - couponDiscountVnd);

      const totalBeforePoints = new Prisma.Decimal(
        Math.max(0, subtotalVnd - couponDiscountVnd) + deliveryFeeVnd,
      );
      // We can't call the loyalty service inside this nested tx (no shared
      // client), so we inline the redeem logic here for atomicity.
      let pointsRedeemed = 0;
      let pointsDiscount = new Prisma.Decimal(0);
      if (dto.pointsToRedeem && dto.pointsToRedeem > 0) {
        const user = await tx.user.findUniqueOrThrow({
          where: { id: customerId },
          select: { pointsBalance: true },
        });
        if (dto.pointsToRedeem > user.pointsBalance) {
          throw new BadRequestException({
            code: 'LOYALTY_INSUFFICIENT_POINTS',
            message: `You only have ${user.pointsBalance} points.`,
          });
        }
        const maxByValue = Math.floor(subtotalAfterCoupon / 100);
        const points = Math.min(dto.pointsToRedeem, maxByValue);
        if (points > 0) {
          pointsRedeemed = points;
          pointsDiscount = new Prisma.Decimal(points * 100);
        }
      }

      const total = totalBeforePoints.minus(pointsDiscount);

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
          pointsRedeemed,
          pointsDiscount,
          total,
          notes: dto.notes,
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
        const user = await tx.user.findUniqueOrThrow({
          where: { id: customerId },
          select: { pointsBalance: true },
        });
        const balanceAfter = user.pointsBalance - pointsRedeemed;
        await tx.loyaltyEvent.create({
          data: {
            userId: customerId,
            orderId: order.id,
            type: 'REDEEM',
            delta: -pointsRedeemed,
            balanceAfter,
            reason: `Redeemed against order ${orderCode}`,
          },
        });
        await tx.user.update({
          where: { id: customerId },
          data: { pointsBalance: balanceAfter },
        });
      }

      return order;
    });

    const paymentInstructions = await this.payments.initiate({
      order: created,
      paymentMethod: dto.paymentMethod,
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

    return { order, payment: paymentInstructions };
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

  async listForStore(storeId: string, opts: { status?: OrderStatus; page?: number; perPage?: number }) {
    const page = opts.page ?? 1;
    const perPage = opts.perPage ?? 30;
    const where: Prisma.OrderWhereInput = {
      storeId,
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
          kitchenStatus: 'PREPARING',
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
        kitchenStatus: 'PREPARING',
        at: new Date().toISOString(),
      },
    );

    await this.notifications.sendToUser(
      order.customerId,
      orderStatusNotification(order.code, 'SENT_TO_KITCHEN'),
      { orderId: id, code: order.code, status: 'SENT_TO_KITCHEN' },
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

    return updated;
  }

  /**
   * Kanban view: orders that are currently routed to a kitchen and not
   * dispatched yet. Filtered by `kitchenStatus`.
   */
  async listForKitchen(
    kitchenId: string,
    opts: { status?: KitchenStatus | null } = {},
  ) {
    const where: Prisma.OrderWhereInput = {
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
    order: { storeId: string; kitchenId: string | null },
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
}
