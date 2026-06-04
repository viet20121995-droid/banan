import { KitchenStatus, OrderStatus } from '@prisma/client';

/**
 * Allowed merchant-driven transitions. Cancellation can happen from any of
 * the pre-completion states by either the customer (when allowed) or staff.
 */
const TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  PENDING: ['ACCEPTED', 'CANCELLED'],
  ACCEPTED: ['IN_PREPARATION', 'SENT_TO_KITCHEN', 'CANCELLED'],
  IN_PREPARATION: ['READY_FOR_PICKUP', 'DELIVERING', 'SENT_TO_KITCHEN', 'CANCELLED'],
  SENT_TO_KITCHEN: ['IN_PREPARATION', 'READY_FOR_PICKUP', 'DELIVERING', 'CANCELLED'],
  READY_FOR_PICKUP: ['COMPLETED', 'CANCELLED'],
  DELIVERING: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
  REFUNDED: [],
};

export function isAllowedTransition(from: OrderStatus, to: OrderStatus): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
}

export function canCustomerCancel(status: OrderStatus): boolean {
  return status === 'PENDING' || status === 'ACCEPTED';
}

/**
 * Kitchen kanban state machine. Forward-only — corrections are merchant-side
 * via order-level cancellation. Simplified to 3 stages so the kanban stays
 * readable; merchants who want fine-grained stages can track them out-of-band.
 */
const KITCHEN_TRANSITIONS: Record<KitchenStatus, KitchenStatus[]> = {
  PENDING_ACK: ['PREPARING'],
  PREPARING: ['READY_DISPATCH'],
  READY_DISPATCH: [],
};

/** `from` may be null when the order has just been transferred to the kitchen. */
export function isAllowedKitchenTransition(
  from: KitchenStatus | null,
  to: KitchenStatus,
): boolean {
  if (from === null) return to === 'PENDING_ACK';
  return KITCHEN_TRANSITIONS[from]?.includes(to) ?? false;
}
