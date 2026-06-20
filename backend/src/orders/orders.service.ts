import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { KitchenStatus, OrderStatus, Prisma, Refund, Role } from '@prisma/client';
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
import { canCustomerCancel, isAllowedKitchenTransition, isAllowedTransition } from './order-status';

/// A bundle shaped just enough to price its expansion — structurally satisfied
/// by the Prisma bundle when fetched with items.product.variants + items.variant.
type BundleForExpansion = {
  name: string;
  priceVnd: number;
  items: ReadonlyArray<{
    quantity: number;
    product: {
      id: string;
      basePrice: Prisma.Decimal;
      variants: ReadonlyArray<{ id: string; priceDelta: Prisma.Decimal }>;
    } | null;
    variant: { id: string; priceDelta: Prisma.Decimal } | null;
  }>;
};

/// One product line input fed to the order line-build loop — either a plain
/// cart line or a combo-expanded constituent (`fromBundle` true).
type ExpandedLineInput = {
  productId: string;
  variantId?: string | null;
  quantity: number;
  customMessage?: string | null;
  personalization?: Record<string, unknown> | null;
  fromBundle: boolean;
};

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
  private readonly logger = new Logger(OrdersService.name);

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

    // An item references either a Product directly or a Bundle (combo). Fetch
    // both: products carry leadTimeHours/availableDaysOfWeek (scalars `include`
    // brings in automatically) for the timeline check; bundles bring their
    // constituent products+variants so we can expand a combo into real product
    // line items (OrderItem has a hard FK to Product, so a combo can't be a
    // single line).
    const requestedIds = [...new Set(dto.items.map((i) => i.productId))];
    // Canonical variant ordering (size, flavor) — so a line's default variant
    // (`variants[0]`, used for combo parts without an explicit variantId)
    // resolves to the SAME variant the customer saw in the bundle detail.
    const products = await this.prisma.product.findMany({
      where: { id: { in: requestedIds } },
      include: { variants: { orderBy: [{ size: 'asc' }, { flavor: 'asc' }] } },
    });
    const productById = new Map(products.map((p) => [p.id, p]));

    const bundleIds = requestedIds.filter((id) => !productById.has(id));
    const bundles = bundleIds.length
      ? await this.prisma.bundle.findMany({
          where: { id: { in: bundleIds }, isActive: true },
          include: {
            items: {
              include: {
                product: {
                  include: {
                    variants: { orderBy: [{ size: 'asc' }, { flavor: 'asc' }] },
                  },
                },
                variant: true,
              },
            },
          },
        })
      : [];
    const bundleById = new Map(bundles.map((b) => [b.id, b]));

    // Anything that's neither a product nor an active bundle is unknown.
    if (requestedIds.some((id) => !productById.has(id) && !bundleById.has(id))) {
      throw new BadRequestException({ code: 'PRODUCT_NOT_FOUND' });
    }

    // Merge each bundle's constituent products into productById so the
    // multi-store + timeline checks, stock decrement and the line loop all
    // treat them as ordinary products.
    for (const b of bundles) {
      for (const it of b.items) {
        if (it.product) productById.set(it.product.id, it.product);
      }
    }

    // Expand combos into product line inputs at REGULAR prices + the combo
    // savings (see expandLineInputs). Plain product lines pass through.
    const { lines: expandedLines, bundleDiscount } = this.expandLineInputs(dto.items, bundleById);

    const productStoreIds = new Set([...productById.values()].map((p) => p.storeId));
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
        const routed = await this.storeRouter.pickNearestDeliveryStore(dto.address?.wardCode);
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
    // Runs on every REAL product being ordered, including the ones a combo
    // expands into (productById was merged with bundle constituents above).
    await this.assertProductsAcceptingOrder(
      [...productById.values()],
      targetAt,
      placedAt,
      !!dto.scheduledFor,
    );

    let subtotal = new Prisma.Decimal(0);
    const lineCreates: Prisma.OrderItemCreateManyOrderInput[] = [];
    // Parallel to lineCreates: marks which lines came from a combo expansion,
    // so auto-promotions don't stack on top of the combo deal.
    const lineFromBundle: boolean[] = [];

    // Aggregate LIMITED-variant demand across every expanded line so a combo +
    // a standalone line (or two combos) sharing one variant is rejected up
    // front by the friendly check below — instead of passing it per-line and
    // only failing mid-transaction with a misleading "someone else took the
    // last one". The in-tx decrement is still the authoritative guard.
    const demandByVariant = new Map<string, number>();
    for (const input of expandedLines) {
      const p = productById.get(input.productId);
      const v = input.variantId
        ? p?.variants.find((x) => x.id === input.variantId)
        : p?.variants[0];
      if (v) {
        demandByVariant.set(v.id, (demandByVariant.get(v.id) ?? 0) + input.quantity);
      }
    }

    for (const input of expandedLines) {
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
        // Total demand for THIS variant across the whole cart (combo + direct),
        // not just this line — so shared-variant carts fail here, not mid-tx.
        const demand = demandByVariant.get(variant.id) ?? input.quantity;
        if (have < demand) {
          throw new BadRequestException({
            code: 'OUT_OF_STOCK',
            message:
              have <= 0
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
      // Combo-expanded lines carry no personalization (the combo fixes its
      // contents), so skip the flavour-composition check for them — otherwise a
      // combo containing a flavour-pick product would always fail.
      if (!input.fromBundle && product.flavorPickCount && product.flavorPickCount > 0) {
        const flavors = (input.personalization?.flavors ?? {}) as Record<string, number>;
        const total = Object.values(flavors).reduce((s, n) => s + (Number(n) || 0), 0);
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
      lineFromBundle.push(input.fromBundle);
    }

    // Delivery fee keys off the REAL products in the order (combo-expanded
    // included) — e.g. the birthday-cake tier — so resolve from the line set.
    const orderedProductIds = [...new Set(lineCreates.map((l) => l.productId))];
    const deliveryFeeVndRaw =
      dto.fulfillmentType === 'DELIVERY'
        ? await this.computeDeliveryFee(storeId, dto.address?.wardCode, orderedProductIds)
        : 0;
    const deliveryFee = new Prisma.Decimal(deliveryFeeVndRaw);

    // ── Coupon validation (no DB write yet — that happens in the tx below).
    const subtotalVnd = Number(subtotal.toString());
    const deliveryFeeVnd = Number(deliveryFee.toString());
    const bundleDiscountVnd = Math.round(Number(bundleDiscount.toString()));
    // Goods total the customer actually owes once the combo deal is applied —
    // combos drop to their flat price, everything else stays at menu price.
    const subtotalAfterBundleVnd = Math.max(0, subtotalVnd - bundleDiscountVnd);

    // Enforce store's minimum order subtotal (set in store settings) against
    // the post-combo goods total.
    await this.assertMinOrder(storeId, subtotalAfterBundleVnd);

    // Automatic promotion-engine discounts. ALL lines are passed (combo lines
    // flagged) so order-level customer campaigns (first-order / birthday /
    // membership / reactivation) still apply to a combo-only order; the engine
    // skips combo lines for LINE + BUY_X_GET_Y promos (a combo is already a
    // discount, so we don't stack on its parts). The base is the post-combo
    // goods total, and it's applied before the coupon so the coupon stacks on
    // the already-discounted amount.
    const promo = await this.promotions.evaluate({
      lines: lineCreates.map((l, i) => ({
        productId: l.productId,
        quantity: l.quantity,
        lineTotalVnd: Number(l.lineTotal.toString()),
        comboLine: lineFromBundle[i],
      })),
      storeId,
      subtotalVnd: subtotalAfterBundleVnd,
      // Skip customer-targeted campaigns (membership / birthday / first-order /
      // re-activation) for a guest order bound to a pre-existing account.
      customerId: guestBoundToExisting ? undefined : customerId,
    });
    const campaignDiscountVnd = Math.min(promo.discountVnd, subtotalAfterBundleVnd);
    // Subtotal after BOTH the combo discount and the auto-promo discount.
    const subtotalAfterCampaign = subtotalAfterBundleVnd - campaignDiscountVnd;

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
      const expired = card?.expiresAt != null && card.expiresAt.getTime() < Date.now();
      if (!card || !card.isActive || expired || card.balanceVnd <= 0) {
        throw new BadRequestException({
          code: 'GIFT_CARD_INVALID',
          message: 'Mã thẻ quà tặng không hợp lệ, đã hết hạn hoặc hết số dư.',
        });
      }
    }

    // Order code generated up-front so loyalty messages reference the same code.
    const orderCode = generateOrderCode();

    // Per-product quantity in THIS order (combo-expanded lines folded in), so a
    // combo's constituents count against the product's daily cap just like a
    // direct order would.
    const qtyByProduct = new Map<string, number>();
    for (const l of expandedLines) {
      qtyByProduct.set(l.productId, (qtyByProduct.get(l.productId) ?? 0) + l.quantity);
    }

    const created = await this.prisma.$transaction(async (tx) => {
      // Daily order cap (Product.dailyMaxQuantity). Enforced first, inside the
      // tx with a per-(product, fulfilment-date) advisory lock, so concurrent
      // checkouts can't both slip past the cap. No-op for uncapped products.
      await this.assertDailyCaps(tx, [...productById.values()], qtyByProduct, targetAt);

      // Combo (bundle) read happened BEFORE this tx; re-validate each ordered
      // combo here under a per-combo advisory lock so a concurrent admin edit
      // (price/composition/deactivate) can't leave the order with stale lines.
      // bundles.update() takes the same lock, so the two serialise.
      await this.assertBundlesUnchanged(tx, bundleById);

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
        const totalBeforePointsVnd = Math.round(Number(totalBeforePoints.toString()));
        const maxByValue = Math.floor(totalBeforePointsVnd / LOYALTY_CONFIG.redemptionValueVnd);
        pointsRedeemed = Math.max(0, Math.min(requestedPoints, lu.pointsBalance, maxByValue));
        pointsDiscount = new Prisma.Decimal(pointsRedeemed * LOYALTY_CONFIG.redemptionValueVnd);
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
        const expired = card?.expiresAt != null && card.expiresAt.getTime() < Date.now();
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

      // Re-read the products + variants FRESH inside the tx — the availability +
      // stockMode checked before the transaction can be stale. If an admin set a
      // product/variant unavailable, or flipped a variant UNLIMITED→LIMITED, at
      // checkout time, the pre-tx snapshot would let the order through without
      // decrementing stock (oversell). Validate + build the decrement plan from
      // the fresh state instead.
      const freshProducts = new Map(
        (
          await tx.product.findMany({
            where: { id: { in: [...new Set(lineCreates.map((l) => l.productId))] } },
            select: { id: true, isAvailable: true },
          })
        ).map((p) => [p.id, p]),
      );
      const freshVariants = new Map(
        (
          await tx.productVariant.findMany({
            where: {
              id: {
                in: [
                  ...new Set(lineCreates.map((l) => l.variantId).filter((v): v is string => !!v)),
                ],
              },
            },
            select: { id: true, stockMode: true, isAvailable: true },
          })
        ).map((v) => [v.id, v]),
      );

      // Race-safe stock decrement for LIMITED variants — a conditional
      // updateMany so two parallel checkouts can't both pass the check; count 0
      // means someone took the last unit and we roll back.
      //
      // Demand is aggregated per variant (a variant can appear in a combo line
      // AND a standalone line) and applied in SORTED variant-id order, so two
      // checkouts sharing variants A and B can't acquire the row locks in
      // opposite order and deadlock.
      const limitedDemand = new Map<string, { quantity: number; productName: string }>();
      for (const line of lineCreates) {
        const product = freshProducts.get(line.productId);
        if (!product || !product.isAvailable) {
          throw new BadRequestException({
            code: 'PRODUCT_UNAVAILABLE',
            message: `"${line.productName}" vừa ngừng bán — vui lòng kiểm tra lại giỏ hàng.`,
          });
        }
        const variantId = line.variantId;
        if (!variantId) continue;
        const variant = freshVariants.get(variantId);
        if (!variant || !variant.isAvailable) {
          throw new BadRequestException({
            code: 'VARIANT_UNAVAILABLE',
            message: `Lựa chọn cho "${line.productName}" vừa ngừng bán.`,
          });
        }
        if (variant.stockMode !== 'LIMITED') continue;
        const cur = limitedDemand.get(variantId);
        if (cur) cur.quantity += line.quantity;
        else
          limitedDemand.set(variantId, {
            quantity: line.quantity,
            productName: line.productName,
          });
      }
      for (const variantId of [...limitedDemand.keys()].sort()) {
        const { quantity, productName } = limitedDemand.get(variantId)!;
        const updated = await tx.productVariant.updateMany({
          where: { id: variantId, stockQty: { gte: quantity } },
          data: { stockQty: { decrement: quantity } },
        });
        if (updated.count === 0) {
          throw new BadRequestException({
            code: 'OUT_OF_STOCK',
            message:
              `"${productName}" vừa hết — một khách khác đã mua ` +
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
          bundleDiscount: new Prisma.Decimal(bundleDiscountVnd),
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
          giftRecipientName: dto.isGift ? dto.giftRecipientName?.trim() || null : null,
          giftRecipientPhone: dto.isGift ? dto.giftRecipientPhone?.trim() || null : null,
          giftWrap: dto.isGift ? (dto.giftWrap ?? false) : false,
          hidePrice: dto.isGift ? (dto.hidePrice ?? false) : false,
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
      // Record campaign usage (enforces per-user / global caps atomically).
      // Skipped for a guest order bound to a pre-existing account so it can't
      // burn that account's campaign allowances.
      if (!guestBoundToExisting && promo.applied.length > 0) {
        await this.promotions.recordUsage({
          campaignIds: promo.applied.map((c) => c.id),
          userId: customerId,
          orderId: order.id,
          tx,
        });
      }

      return order;
    });

    // When a gift card fully covers the order, there's nothing left to charge
    // a gateway for — route to the cash provider (records a 0₫ payment) so we
    // never hand VNPay/Stripe a zero amount.
    const effectiveMethod = Number(created.total.toString()) <= 0 ? 'CASH' : dto.paymentMethod;
    let paymentInstructions;
    try {
      paymentInstructions = await this.payments.initiate({
        order: created,
        paymentMethod: effectiveMethod,
        customerIp,
      });
    } catch (err) {
      // The order transaction already committed — gift card debited, stock
      // decremented, points redeemed. If we can't even produce payment
      // instructions (e.g. a gateway network error), nothing will later
      // reverse the gift-card debit, so customer value would be lost. Roll
      // back every consumable and cancel the stranded order before surfacing
      // the failure.
      this.logger.error(
        `Payment initiation failed for order ${created.id} — compensating and cancelling`,
        err as Error,
      );
      // Reverse every consumable AND flip the order to CANCELLED in ONE
      // transaction, so we never end up with resources returned but the order
      // still PENDING (or vice-versa).
      await this.prisma.$transaction(
        async (tx) => {
          await this.loyalty.refundRedemption(created.id, tx);
          await this.restoreInventory(created.id, tx);
          await this.restoreGiftCard(created.id, tx);
          await this.coupons.reverseRedemption(created.id, tx);
          await this.promotions.reverseUsage(created.id, tx);
          await this.payments.onOrderCancelled(created.id, tx);
          await tx.order.update({
            where: { id: created.id },
            data: { status: 'CANCELLED' },
          });
        },
        { timeout: 15_000 },
      );
      throw new BadRequestException({
        code: 'PAYMENT_INIT_FAILED',
        message: 'Không khởi tạo được thanh toán. Đơn hàng đã được huỷ, vui lòng thử lại.',
      });
    }

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
    const txResult = await this.prisma.$transaction(
      async (tx) => {
        // Status-GUARDED update: only transition if the order is still in the
        // exact status we validated against. Two concurrent transitions (e.g. a
        // double cancel) would otherwise both pass isAllowedTransition and both
        // run the side-effects below (double refund/restock/reverse). The loser
        // sees count 0, throws, rolls back, and never reaches side-effects.
        const res = await tx.order.updateMany({
          where: { id, status: order.status },
          data: {
            status: toStatus,
            // A cancel can land while the order is still live at the kitchen
            // (SENT_TO_KITCHEN, kitchenStatus=PREPARING/…). Clear the kitchen
            // status here so a cancelled order never carries an orphaned live
            // kanban state — preserving the invariant the kitchen-transition
            // guards rely on ("only SENT_TO_KITCHEN orders carry kitchenStatus").
            ...(toStatus === 'CANCELLED' && { kitchenStatus: null }),
          },
        });
        if (res.count === 0) {
          throw new BadRequestException({
            code: 'ORDER_INVALID_TRANSITION',
            message: `Order is no longer in ${order.status}.`,
          });
        }
        await tx.orderStatusEvent.create({
          data: {
            orderId: id,
            fromStatus: order.status,
            toStatus,
            actorId: actor.sub,
            note,
          },
        });
        // DB side-effects run in the SAME transaction as the status change, so
        // the status flip and every money-state award/reversal commit (or roll
        // back) atomically. Previously these ran AFTER commit — a failure there
        // left the order terminal with the work half-done, and the status guard
        // blocked any retry. External effects (refund-request rows, realtime,
        // push) stay after the commit; they don't corrupt money state if they
        // fail and are independently retryable/idempotent.
        const createdRefunds: Refund[] = [];
        if (toStatus === 'COMPLETED') {
          await this.payments.onOrderCompleted(id, tx);
          await this.loyalty.earnFor(order, tx);
        } else if (toStatus === 'CANCELLED') {
          await this.loyalty.refundRedemption(id, tx);
          const { capturedPayments } = await this.payments.onOrderCancelled(id, tx);
          await this.restoreInventory(id, tx);
          await this.restoreGiftCard(id, tx);
          // Release coupon + campaign usage so a cancelled order doesn't burn the
          // customer's coupon or a campaign's allowance (mirrors points/stock/
          // gift card being restored above).
          await this.coupons.reverseRedemption(id, tx);
          await this.promotions.reverseUsage(id, tx);
          // Open a refund row for each already-captured payment INSIDE this tx,
          // so a cancelled order can never be left without its refund row (which
          // the status guard would then block a retry from creating). Realtime
          // emit is deferred until after commit.
          for (const payment of capturedPayments) {
            const { refund, created } = await this.refunds.createRequestTx(tx, {
              order,
              payment,
              reason: note ?? 'Order cancelled',
              requestedById: actor.sub,
              inInteractiveTx: true,
            });
            if (created) createdRefunds.push(refund);
          }
        }

        const next = await tx.order.findUniqueOrThrow({
          where: { id },
          include: ORDER_INCLUDE,
        });
        return { order: next, createdRefunds };
      },
      { timeout: 15_000 },
    );
    const updated = txResult.order;

    // Post-commit: emit realtime for refund rows created inside the tx (the
    // emit is a side-channel, kept out of the transaction).
    for (const refund of txResult.createdRefunds) {
      this.refunds.notifyCreated(refund);
    }

    const rooms = [`order:${id}`, `user:${order.customerId}`, `store:${order.storeId}`];
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

  async customerCancel(
    id: string,
    customerId: string,
    reason?: string,
  ): Promise<OrderWithIncludes> {
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
      include: {
        ...ORDER_INCLUDE,
        store: { select: { id: true, name: true, slug: true, defaultKitchenId: true } },
      },
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
    // Kitchen routing authz + integrity. Kitchens are CENTRAL — one kitchen
    // serves many stores via Store.defaultKitchenId, so there is no per-kitchen
    // storeId to scope against. When an explicit kitchenId is supplied:
    //   • a store merchant may only target THEIR store's own kitchen, and
    //   • only an admin (chain operator) may direct an order elsewhere.
    // Without this a merchant could pass any kitchen's UUID and leak the order —
    // customer name, phone, address and items — onto an unrelated store's
    // kitchen board (assertCanWrite above only checks order ownership, not the
    // target kitchen). The common merchant path passes no kitchenId and falls
    // back to the store default, so this adds zero overhead for it.
    if (opts.kitchenId) {
      if (actor.role !== Role.ADMIN && opts.kitchenId !== order.store.defaultKitchenId) {
        throw new ForbiddenException({
          code: 'KITCHEN_NOT_ALLOWED',
          message: 'Bạn chỉ có thể chuyển đơn tới bếp của cửa hàng mình.',
        });
      }
      const exists = await this.prisma.kitchen.count({
        where: { id: opts.kitchenId },
      });
      if (exists === 0) {
        throw new BadRequestException({
          code: 'KITCHEN_NOT_FOUND',
          message: 'Bếp không tồn tại.',
        });
      }
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      // Status-guarded on the validated status so a cancel winning the race
      // can't be overwritten back to SENT_TO_KITCHEN (order resurrection).
      const res = await tx.order.updateMany({
        where: { id, status: order.status },
        data: {
          status: 'SENT_TO_KITCHEN',
          // Newly transferred orders sit at PENDING_ACK so kitchen staff
          // explicitly accept before they start preparing.
          kitchenStatus: 'PENDING_ACK',
          kitchenId,
        },
      });
      if (res.count === 0) {
        throw new BadRequestException({
          code: 'ORDER_INVALID_TRANSITION',
          message: `Order is no longer in ${order.status}.`,
        });
      }
      await tx.orderStatusEvent.create({
        data: {
          orderId: id,
          fromStatus: order.status,
          toStatus: 'SENT_TO_KITCHEN',
          actorId: actor.sub,
          note: opts.note ?? 'Transferred to central kitchen',
        },
      });
      return tx.order.findUniqueOrThrow({
        where: { id },
        include: ORDER_INCLUDE,
      });
    });

    // The order may have moved off a previous kitchen — evict that kitchen's
    // stale `order:{id}` subscribers BEFORE we emit, and AWAIT it, so neither
    // this transfer event nor any later kitchen-status event reaches the old
    // kitchen. The new kitchen's staff (joined via kitchen:{id}) and the
    // customer/store are unaffected.
    await this.realtime.evictStaleKitchenSubscribers(id, kitchenId);

    this.realtime.emit(
      [`order:${id}`, `user:${order.customerId}`, `store:${order.storeId}`, `kitchen:${kitchenId}`],
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
    // Kitchen kanban only advances while the order is live at the kitchen —
    // never on a cancelled/completed order that still carries a kitchenStatus.
    if (order.status !== 'SENT_TO_KITCHEN') {
      throw new BadRequestException({
        code: 'KITCHEN_INVALID_TRANSITION',
        message: `Order is not at the kitchen (status ${order.status}).`,
      });
    }
    if (!isAllowedKitchenTransition(order.kitchenStatus, toKitchenStatus)) {
      throw new BadRequestException({
        code: 'KITCHEN_INVALID_TRANSITION',
        message: `Cannot move kitchen status from ${order.kitchenStatus ?? 'null'} to ${toKitchenStatus}.`,
      });
    }
    // Status-guarded (incl. SENT_TO_KITCHEN) so a double-click / concurrent
    // advance — or a cancel landing mid-flight — doesn't run the emit +
    // customer notification twice or advance a no-longer-live order.
    const res = await this.prisma.order.updateMany({
      where: {
        id,
        status: 'SENT_TO_KITCHEN',
        kitchenStatus: order.kitchenStatus,
        // Re-check the kitchen at write time: if the order was reassigned to a
        // different kitchen between the scope check above and here, count comes
        // back 0 and we abort rather than advancing an order this kitchen no
        // longer owns.
        kitchenId: order.kitchenId,
      },
      data: { kitchenStatus: toKitchenStatus },
    });
    if (res.count === 0) {
      throw new BadRequestException({
        code: 'KITCHEN_INVALID_TRANSITION',
        message: `Kitchen status changed concurrently; expected ${order.kitchenStatus ?? 'null'}.`,
      });
    }
    const updated = await this.prisma.order.findUniqueOrThrow({
      where: { id },
      include: ORDER_INCLUDE,
    });
    // Safe to include order:{id}: kitchen staff can no longer join an order room
    // (onOrderSubscribe rejects KITCHEN roles), so no kitchen the order was
    // transferred away from can be a stale subscriber. The customer / admin
    // watching the order get the kitchen workflow live again.
    const rooms = [`order:${id}`, `user:${order.customerId}`, `store:${order.storeId}`];
    if (order.kitchenId) rooms.push(`kitchen:${order.kitchenId}`);
    this.realtime.emit(rooms, 'order.kitchen_status_changed', {
      orderId: id,
      code: order.code,
      fromKitchenStatus: order.kitchenStatus,
      toKitchenStatus,
      at: new Date().toISOString(),
    });

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
    // Must still be live at the kitchen. Guarding on the *actual* SENT_TO_KITCHEN
    // status (not order.status) prevents resurrecting an order that was
    // cancelled while it still carried kitchenStatus=READY_DISPATCH.
    if (order.status !== 'SENT_TO_KITCHEN' || order.kitchenStatus !== 'READY_DISPATCH') {
      throw new BadRequestException({
        code: 'KITCHEN_NOT_READY',
        message: 'Order is not a live SENT_TO_KITCHEN card at READY_DISPATCH.',
      });
    }
    const targetOrderStatus: OrderStatus =
      order.fulfillmentType === 'DELIVERY' ? 'DELIVERING' : 'READY_FOR_PICKUP';

    const updated = await this.prisma.$transaction(async (tx) => {
      // Status-guarded on SENT_TO_KITCHEN (not order.status) so a concurrent
      // cancel/dispatch can't double-fire or revive a cancelled order, and a
      // double dispatch can't run the emit/notify twice.
      const res = await tx.order.updateMany({
        where: {
          id,
          status: 'SENT_TO_KITCHEN',
          kitchenStatus: 'READY_DISPATCH',
          // Re-check ownership at write time (see transitionKitchen): a
          // concurrent reassignment to another kitchen makes count 0 and aborts
          // the dispatch instead of acting on an order this kitchen lost.
          kitchenId: order.kitchenId,
        },
        data: { status: targetOrderStatus },
      });
      if (res.count === 0) {
        throw new BadRequestException({
          code: 'KITCHEN_NOT_READY',
          message: 'Order was already dispatched or changed concurrently.',
        });
      }
      const next = await tx.order.findUniqueOrThrow({
        where: { id },
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

    const rooms = [`order:${id}`, `user:${order.customerId}`, `store:${order.storeId}`];
    if (order.kitchenId) rooms.push(`kitchen:${order.kitchenId}`);
    this.realtime.emit(rooms, 'order.status_changed', {
      orderId: id,
      code: order.code,
      fromStatus: order.status,
      toStatus: targetOrderStatus,
      at: new Date().toISOString(),
    });

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
    const hours = store.openingHours as Record<string, [string, string][]> | null;
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
    const isOpen = todays.some(([o, c]) => minutes >= toMin(o) && minutes <= toMin(c));
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
   * Expands combo (Bundle) cart lines into their constituent product line
   * inputs at REGULAR prices, returning the per-order combo savings (the
   * difference between the regular total and the bundle's flat `priceVnd`,
   * times the combo quantity). Plain product lines pass through unchanged.
   *
   * Keeping the constituents at regular price means each OrderItem holds its
   * true menu price (correct for VAT invoices / reports), and the discount is
   * recorded once on the order as `bundleDiscount` ("Giảm combo"). Pure — no DB
   * access — so it's unit-tested directly.
   */
  private expandLineInputs(
    items: CreateOrderDto['items'],
    bundleById: ReadonlyMap<string, BundleForExpansion>,
  ): { lines: ExpandedLineInput[]; bundleDiscount: Prisma.Decimal } {
    const lines: ExpandedLineInput[] = [];
    let bundleDiscount = new Prisma.Decimal(0);

    for (const input of items) {
      const bundle = bundleById.get(input.productId);
      if (!bundle) {
        lines.push({
          productId: input.productId,
          variantId: input.variantId,
          quantity: input.quantity,
          customMessage: input.customMessage,
          personalization: input.personalization,
          fromBundle: false,
        });
        continue;
      }

      const comboQty = input.quantity;
      let regularTotal = new Prisma.Decimal(0);
      for (const bi of bundle.items) {
        const prod = bi.product;
        if (!prod) throw new BadRequestException({ code: 'PRODUCT_NOT_FOUND' });
        const variant = bi.variant ?? prod.variants[0];
        if (!variant) {
          throw new BadRequestException({
            code: 'VARIANT_UNAVAILABLE',
            message: `Combo "${bundle.name}" có món thiếu lựa chọn hợp lệ.`,
          });
        }
        const qty = bi.quantity * comboQty;
        regularTotal = regularTotal.plus(
          new Prisma.Decimal(prod.basePrice).plus(variant.priceDelta).times(qty),
        );
        lines.push({
          productId: prod.id,
          variantId: variant.id,
          quantity: qty,
          customMessage: `Combo: ${bundle.name}`,
          personalization: null,
          fromBundle: true,
        });
      }
      const comboPrice = new Prisma.Decimal(bundle.priceVnd).times(comboQty);
      const saving = regularTotal.minus(comboPrice);
      // Re-validated at order time, not just at combo create: if component
      // prices have since dropped below the flat combo price, the combo is no
      // longer a deal. Reject rather than silently charging the lower à-la-carte
      // sum (which would undercut the displayed combo price).
      if (saving.lessThan(0)) {
        throw new BadRequestException({
          code: 'BUNDLE_PRICE_ABOVE_SUM',
          message:
            `Combo "${bundle.name}" tạm thời không áp dụng được ` +
            `(giá thành phần đã thay đổi). Vui lòng thử lại sau.`,
        });
      }
      if (saving.greaterThan(0)) bundleDiscount = bundleDiscount.plus(saving);
    }

    return { lines, bundleDiscount };
  }

  /**
   * Enforces per-product `availableDaysOfWeek` (days the product is sold) and
   * per-product `leadTimeHours` (advance notice override). Store-wide lead
   * time is checked separately in `assertStoreAcceptingOrder`; whichever is
   * larger effectively wins, since both must pass.
   *
   * Collects EVERY offending item rather than throwing on the first, so the
   * customer sees the full list of cakes that don't fit their chosen time (and
   * the app can highlight each one). On any violation it throws a single
   * `ORDER_ITEMS_TIMELINE` error carrying machine-readable `details.items`.
   */
  private async assertProductsAcceptingOrder(
    products: {
      id: string;
      name: string;
      leadTimeHours: number | null;
      availableDaysOfWeek: number[];
    }[],
    at: Date,
    placedAt: Date,
    scheduled: boolean,
  ): Promise<void> {
    // VN local weekday for day-of-week comparison.
    const vn = new Date(at.getTime() + 7 * 3600 * 1000);
    const dow = vn.getUTCDay(); // 0=Sun..6=Sat
    const dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    type TimelineViolation = {
      productId: string;
      name: string;
      reason: 'LEAD_TIME' | 'DAY_UNAVAILABLE';
      leadTimeHours?: number;
      availableDaysOfWeek?: number[];
    };
    const violations: TimelineViolation[] = [];

    for (const p of products) {
      // Day-of-week takes precedence: if the product isn't sold on the chosen
      // day, lead time is moot for it — report the day constraint only.
      if (
        p.availableDaysOfWeek &&
        p.availableDaysOfWeek.length > 0 &&
        !p.availableDaysOfWeek.includes(dow)
      ) {
        violations.push({
          productId: p.id,
          name: p.name,
          reason: 'DAY_UNAVAILABLE',
          availableDaysOfWeek: p.availableDaysOfWeek,
        });
        continue;
      }

      if (p.leadTimeHours && p.leadTimeHours > 0) {
        const minMs = p.leadTimeHours * 3600 * 1000;
        if (at.getTime() - placedAt.getTime() < minMs) {
          violations.push({
            productId: p.id,
            name: p.name,
            reason: 'LEAD_TIME',
            leadTimeHours: p.leadTimeHours,
          });
        }
      }
    }

    if (violations.length === 0) return;

    // Longest lead time among the lead-time offenders — lets the app jump the
    // schedule straight to the soonest time that satisfies every cake.
    const earliestLeadHours = violations.reduce(
      (m, v) => (v.reason === 'LEAD_TIME' ? Math.max(m, v.leadTimeHours ?? 0) : m),
      0,
    );

    // Human-readable summary that names every offending cake and its rule, so
    // even a client that only renders the message string is actionable.
    const reasons = violations.map((v) =>
      v.reason === 'LEAD_TIME'
        ? `${v.name} cần đặt trước ${v.leadTimeHours} giờ`
        : `${v.name} chỉ bán ${(v.availableDaysOfWeek ?? [])
            .map((d) => dayNames[d] ?? `?${d}`)
            .join(', ')}`,
    );
    const hint = scheduled
      ? 'Vui lòng chọn thời gian khác hoặc bỏ các món này khỏi giỏ.'
      : 'Hãy dùng "Đặt trước theo lịch" hoặc bỏ các món này khỏi giỏ.';

    throw new BadRequestException({
      code: 'ORDER_ITEMS_TIMELINE',
      message: `${reasons.join('; ')}. ${hint}`,
      details: {
        items: violations,
        ...(earliestLeadHours > 0 && { earliestLeadHours }),
      },
    });
  }

  /**
   * Resolves the delivery fee using the admin-tunable `DeliveryConfig`:
   *   - picks the standard or birthday-cake tier (any cart item in the
   *     birthday-cake collection switches to the higher tier)
   *   - picks the under/over band by comparing haversine distance from
   *     the fulfilling store to the address ward centroid
   *
   * Falls back to a zero fee only when ward / store coords are missing — the
   * routing already prefers stores with coords, so this branch is rarely hit
   * in practice.
   */
  private async computeDeliveryFee(
    storeId: string,
    wardCode: string | null | undefined,
    productIds: string[],
  ): Promise<number> {
    const cfg = await this.deliveryConfig.get();
    const hasBirthdayCake = await this.deliveryConfig.cartHasBirthdayCake(productIds, cfg);
    // No customer ward → treat as "other ward" so we never undercharge.
    if (!wardCode) {
      return hasBirthdayCake ? cfg.birthdayCakeFeeOtherWardVnd : cfg.standardFeeOtherWardVnd;
    }
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { wardCode: true },
    });
    return this.deliveryConfig.feeFor(cfg, wardCode, store?.wardCode ?? null, hasBirthdayCake);
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
          message: 'Số điện thoại này đã có tài khoản. Vui lòng đăng nhập để đặt hàng.',
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
    const finalEmail =
      normalisedEmail && !emailInUse
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

  /**
   * Re-validates each ordered combo INSIDE the order transaction. The combo was
   * read BEFORE the tx (to expand into line items + compute bundleDiscount), so
   * a concurrent admin edit/deactivate could otherwise leave the order with
   * stale component lines and a stale discount. Under a per-combo advisory lock
   * (bundles.update() takes the same one, so they serialise) we re-fetch and
   * reject if the combo is gone/inactive or its price or composition changed —
   * the customer retries against the current combo. No-op when the cart has no
   * combos.
   */
  private async assertBundlesUnchanged(
    tx: Prisma.TransactionClient,
    bundleById: Map<
      string,
      {
        priceVnd: number;
        items: Array<{
          productId: string;
          variantId: string | null;
          quantity: number;
        }>;
      }
    >,
  ): Promise<void> {
    const ids = [...bundleById.keys()].sort();
    if (ids.length === 0) return;
    const fingerprint = (b: {
      priceVnd: number;
      items: Array<{
        productId: string;
        variantId: string | null;
        quantity: number;
      }>;
    }): string =>
      `${b.priceVnd}|` +
      b.items
        .map((i) => `${i.productId}:${i.variantId ?? ''}:${i.quantity}`)
        .sort()
        .join(',');
    for (const id of ids) {
      // Same key bundles.update() locks on. Sorted ids + daily-caps-locked-first
      // keep the global lock-acquisition order consistent (deadlock-safe).
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${'bundle:' + id}, 0))`;
      const fresh = await tx.bundle.findUnique({
        where: { id },
        select: {
          isActive: true,
          priceVnd: true,
          items: {
            select: { productId: true, variantId: true, quantity: true },
          },
        },
      });
      if (!fresh || !fresh.isActive) {
        throw new BadRequestException({
          code: 'BUNDLE_UNAVAILABLE',
          message: 'Một combo trong giỏ vừa ngừng bán. Vui lòng kiểm tra lại giỏ hàng.',
        });
      }
      if (fingerprint(fresh) !== fingerprint(bundleById.get(id)!)) {
        throw new BadRequestException({
          code: 'BUNDLE_CHANGED',
          message: 'Một combo trong giỏ vừa được cập nhật. Vui lòng tải lại giỏ và đặt lại.',
        });
      }
    }
  }

  /**
   * Enforces Product.dailyMaxQuantity — a per-product cap on units ordered for
   * a single fulfilment date, across ALL customers. The cap counts a scheduled
   * order against its `scheduledFor` date and an ASAP order against the day it
   * was placed; cancelled orders don't count. Must run inside the order
   * transaction: it takes a per-(product, date) advisory lock so two concurrent
   * checkouts can't both read an under-cap total and both commit past it.
   * Uncapped products (`dailyMaxQuantity = null`) and products not in this
   * order are skipped, so the common path costs nothing.
   */
  private async assertDailyCaps(
    tx: Prisma.TransactionClient,
    products: Array<{ id: string; name: string; dailyMaxQuantity: number | null }>,
    qtyByProduct: Map<string, number>,
    targetAt: Date,
  ): Promise<void> {
    // Sorted by id so concurrent checkouts containing the same products always
    // take the per-product advisory locks in the SAME order — otherwise order1
    // (locks A then B) and order2 (locks B then A) could deadlock.
    const capped = products
      .filter((p) => p.dailyMaxQuantity != null && (qtyByProduct.get(p.id) ?? 0) > 0)
      .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
    if (capped.length === 0) return;

    // Fulfilment-DAY window in Vietnam time (UTC+7, no DST) — the same
    // convention the rest of the order/availability logic uses (the server
    // runs in UTC). Shift +7h to read the VN calendar date, then express that
    // VN-midnight … +24h window back as real UTC instants for the query.
    const VN_OFFSET_MS = 7 * 3600 * 1000;
    const shifted = new Date(targetAt.getTime() + VN_OFFSET_MS);
    const dayKey = shifted.toISOString().slice(0, 10); // VN calendar date
    const dayStart = new Date(
      Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate()) -
        VN_OFFSET_MS,
    );
    const dayEnd = new Date(dayStart.getTime() + 24 * 3600 * 1000);

    for (const p of capped) {
      const requested = qtyByProduct.get(p.id) ?? 0;
      // Serialise concurrent orders for the same product+date. Released at tx end.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`daily:${p.id}:${dayKey}`}, 0))`;
      const agg = await tx.orderItem.aggregate({
        _sum: { quantity: true },
        where: {
          productId: p.id,
          order: {
            status: { not: 'CANCELLED' },
            OR: [
              { scheduledFor: { gte: dayStart, lt: dayEnd } },
              { scheduledFor: null, createdAt: { gte: dayStart, lt: dayEnd } },
            ],
          },
        },
      });
      const existing = agg._sum.quantity ?? 0;
      const cap = p.dailyMaxQuantity!;
      if (existing + requested > cap) {
        const remaining = Math.max(0, cap - existing);
        throw new BadRequestException({
          code: 'DAILY_LIMIT_EXCEEDED',
          message:
            remaining <= 0
              ? `"${p.name}" đã hết suất đặt cho ngày này — vui lòng chọn ngày khác.`
              : `"${p.name}" chỉ còn ${remaining} suất cho ngày đã chọn — vui lòng giảm số lượng.`,
          details: { productId: p.id, remaining, dailyMax: cap },
        });
      }
    }
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
  private async restoreInventory(
    orderId: string,
    db: Prisma.TransactionClient = this.prisma,
  ): Promise<void> {
    const items = await db.orderItem.findMany({
      where: { orderId, variantId: { not: null } },
      include: {
        variant: { select: { id: true, stockMode: true } },
      },
    });
    for (const i of items) {
      if (!i.variant || i.variant.stockMode !== 'LIMITED') continue;
      await db.productVariant.update({
        where: { id: i.variant.id },
        data: { stockQty: { increment: i.quantity } },
      });
    }
  }

  /// Cancellation reverse-step: credit a redeemed gift-card balance back.
  /// The order persists the code + amount it consumed, so we add that amount
  /// back to the card. Best-effort (the card may have been deleted).
  private async restoreGiftCard(
    orderId: string,
    db: Prisma.TransactionClient = this.prisma,
  ): Promise<void> {
    const order = await db.order.findUnique({
      where: { id: orderId },
      select: { giftCardCode: true, giftCardAmountVnd: true },
    });
    if (!order?.giftCardCode || order.giftCardAmountVnd <= 0) return;
    await db.giftCard.updateMany({
      where: { code: order.giftCardCode },
      data: { balanceVnd: { increment: order.giftCardAmountVnd } },
    });
  }
}
