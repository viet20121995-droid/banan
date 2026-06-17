import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Order,
  OrderStatus,
  Payment,
  Prisma,
  Refund,
  RefundStatus,
  Role,
} from '@prisma/client';

import { PaymentsService } from '../payments/payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

interface ActorContext {
  sub: string;
  role: Role;
  storeId?: string | null;
}

@Injectable()
export class RefundsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  /**
   * Creates a refund row in the REQUESTED state. Used by both:
   *   - the cancel flow when the order had a captured payment, and
   *   - the explicit "request refund" merchant endpoint.
   *
   * Caller must have already verified scope (the order belongs to the actor's
   * store, etc.). Idempotent on `(orderId, paymentId)` for an in-flight refund.
   */
  async createRequest(args: {
    order: Order;
    payment: Payment;
    amount?: Prisma.Decimal | number;
    reason: string;
    requestedById: string;
  }): Promise<Refund> {
    const existing = await this.prisma.refund.findFirst({
      where: {
        orderId: args.order.id,
        paymentId: args.payment.id,
        status: { in: ['REQUESTED', 'APPROVED', 'PROCESSING'] },
      },
    });
    if (existing) return existing;

    const amount = args.amount
      ? new Prisma.Decimal(args.amount.toString())
      : args.payment.amount;

    const refund = await this.prisma.refund.create({
      data: {
        orderId: args.order.id,
        paymentId: args.payment.id,
        amount,
        reason: args.reason,
        status: 'REQUESTED',
        requestedById: args.requestedById,
      },
    });
    this.emit(refund);
    return refund;
  }

  async findOne(
    id: string,
    actor?: ActorContext,
  ): Promise<Refund & { order: Order; payment: Payment | null }> {
    const refund = await this.prisma.refund.findUnique({
      where: { id },
      include: { order: true, payment: true },
    });
    if (!refund) throw new NotFoundException({ code: 'REFUND_NOT_FOUND' });
    // Scope reads: a merchant/staff may only see their own store's refund
    // (it bundles full order + payment data). Without this, any valid refund
    // UUID would leak another store's payment details.
    if (actor) this.assertCanRead(refund.order, actor);
    return refund;
  }

  async listForStore(
    storeId: string | null,
    opts: { status?: RefundStatus; page?: number; perPage?: number },
  ) {
    const page = opts.page ?? 1;
    const perPage = opts.perPage ?? 30;
    // Admin (no storeId) sees refunds across every store.
    const where: Prisma.RefundWhereInput = {
      ...(storeId != null && { order: { storeId } }),
      ...(opts.status && { status: opts.status }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.refund.findMany({
        where,
        include: { order: true, payment: true },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * perPage,
        take: perPage,
      }),
      this.prisma.refund.count({ where }),
    ]);
    return { items, meta: { page, perPage, total } };
  }

  async approve(id: string, actor: ActorContext): Promise<Refund> {
    const refund = await this.findOne(id);
    this.assertCanApprove(refund.order, actor);
    if (refund.status !== 'REQUESTED') {
      throw new BadRequestException({
        code: 'REFUND_NOT_REQUESTED',
        message: 'Only REQUESTED refunds can be approved.',
      });
    }
    const approved = await this.prisma.refund.update({
      where: { id },
      data: {
        status: 'APPROVED',
        approvedById: actor.sub,
      },
    });
    this.emit(approved);

    // Kick off provider-side refund. The processed status (COMPLETED) is set
    // either inline (CASH) or asynchronously by the provider webhook.
    await this.process(approved);
    return approved;
  }

  async reject(id: string, actor: ActorContext, reason?: string): Promise<Refund> {
    const refund = await this.findOne(id);
    this.assertCanApprove(refund.order, actor);
    if (refund.status !== 'REQUESTED') {
      throw new BadRequestException({ code: 'REFUND_NOT_REQUESTED' });
    }
    const rejected = await this.prisma.refund.update({
      where: { id },
      data: {
        status: 'REJECTED',
        approvedById: actor.sub,
        reason: reason ? `${refund.reason} · rejected: ${reason}` : refund.reason,
      },
    });
    this.emit(rejected);
    return rejected;
  }

  /**
   * Calls the provider's refund API. For CASH this is synchronous (the
   * physical money goes back at the counter). For Stripe / VNPay / MoMo we
   * mark PROCESSING and rely on the provider's webhook to land COMPLETED.
   */
  private async process(refund: Refund): Promise<void> {
    const outcome = await this.payments.executeRefund(refund);
    if (outcome.completed) {
      const completed = await this.markCompleted(refund, outcome.providerRef);
      if (refund.paymentId) {
        await this.payments.markPaymentRefunded(refund.paymentId);
      }
      this.emit(completed);
    } else {
      const processing = await this.prisma.refund.update({
        where: { id: refund.id },
        data: {
          status: 'PROCESSING',
          providerRef: outcome.providerRef ?? refund.providerRef,
        },
      });
      this.emit(processing);
    }
  }

  /**
   * Webhook landing point — providers call this after their refund settles.
   * Updates the refund + order status accordingly.
   */
  async markCompleted(refund: Refund, providerRef?: string): Promise<Refund> {
    const completed = await this.prisma.refund.update({
      where: { id: refund.id },
      data: {
        status: 'COMPLETED',
        providerRef: providerRef ?? refund.providerRef,
      },
    });
    // Mirror onto the order so the customer's "My Orders" list shows REFUNDED.
    await this.prisma.order.updateMany({
      where: {
        id: refund.orderId,
        status: { in: ['CANCELLED', 'COMPLETED'] },
      },
      data: { status: 'REFUNDED' satisfies OrderStatus },
    });
    this.emit(completed);
    return completed;
  }

  private assertCanApprove(order: { storeId: string }, actor: ActorContext) {
    if (actor.role === 'ADMIN') return;
    if (actor.role === 'MERCHANT_OWNER' && actor.storeId === order.storeId) return;
    throw new ForbiddenException({ code: 'AUTH_FORBIDDEN' });
  }

  /** Read scope: admin, or owner/staff of the refund's own store. */
  private assertCanRead(order: { storeId: string }, actor: ActorContext) {
    if (actor.role === 'ADMIN') return;
    if (
      (actor.role === 'MERCHANT_OWNER' || actor.role === 'MERCHANT_STAFF') &&
      actor.storeId === order.storeId
    ) {
      return;
    }
    throw new ForbiddenException({ code: 'AUTH_FORBIDDEN' });
  }

  private emit(refund: Refund) {
    this.realtime.emit(
      [`order:${refund.orderId}`],
      'refund.updated',
      {
        refundId: refund.id,
        orderId: refund.orderId,
        status: refund.status,
        amount: refund.amount.toString(),
      },
    );
  }
}
