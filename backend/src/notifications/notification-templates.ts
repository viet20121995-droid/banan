import { OrderStatus, KitchenStatus } from '@prisma/client';

export interface NotificationTemplate {
  type: string;
  title: string;
  body: string;
}

const ORDER_STATUS_LABEL: Record<OrderStatus, string> = {
  PENDING: 'Order placed',
  ACCEPTED: 'Order accepted',
  IN_PREPARATION: 'Being prepared',
  SENT_TO_KITCHEN: 'Sent to central kitchen',
  READY_FOR_PICKUP: 'Ready for pickup',
  DELIVERING: 'Out for delivery',
  COMPLETED: 'Order completed',
  CANCELLED: 'Order cancelled',
  REFUNDED: 'Order refunded',
};

const ORDER_STATUS_BODY: Record<OrderStatus, (code: string) => string> = {
  PENDING: (c) => `Order ${c} placed.`,
  ACCEPTED: (c) => `Your order ${c} has been accepted.`,
  IN_PREPARATION: (c) => `We're preparing your order ${c}.`,
  SENT_TO_KITCHEN: (c) =>
    `Order ${c} is being crafted at our central kitchen.`,
  READY_FOR_PICKUP: (c) => `Order ${c} is ready for pickup!`,
  DELIVERING: (c) => `Order ${c} is on the way!`,
  COMPLETED: (c) => `Thanks for your order ${c}. Enjoy!`,
  CANCELLED: (c) => `Order ${c} was cancelled.`,
  REFUNDED: (c) => `Order ${c} has been refunded.`,
};

const KITCHEN_STATUS_LABEL: Record<KitchenStatus, string> = {
  PREPARING: 'Kitchen preparing',
  BAKING: 'Kitchen baking',
  COOLING: 'Cooling',
  DECORATING: 'Decorating',
  PACKED: 'Packed',
  READY_DISPATCH: 'Ready to dispatch',
};

export function orderStatusNotification(
  code: string,
  status: OrderStatus,
): NotificationTemplate {
  return {
    type: 'order.status_changed',
    title: ORDER_STATUS_LABEL[status],
    body: ORDER_STATUS_BODY[status](code),
  };
}

export function kitchenStatusNotification(
  code: string,
  status: KitchenStatus,
): NotificationTemplate {
  return {
    type: 'order.kitchen_status_changed',
    title: KITCHEN_STATUS_LABEL[status],
    body: `Order ${code} is now ${KITCHEN_STATUS_LABEL[status].toLowerCase()}.`,
  };
}

export function refundUpdatedNotification(
  code: string,
  status: 'APPROVED' | 'PROCESSING' | 'COMPLETED' | 'REJECTED',
): NotificationTemplate {
  const titles: Record<string, string> = {
    APPROVED: 'Refund approved',
    PROCESSING: 'Refund processing',
    COMPLETED: 'Refund completed',
    REJECTED: 'Refund rejected',
  };
  const bodies: Record<string, string> = {
    APPROVED: `Your refund for ${code} has been approved.`,
    PROCESSING: `Your refund for ${code} is being processed.`,
    COMPLETED: `Your refund for ${code} is complete.`,
    REJECTED: `Your refund request for ${code} was declined.`,
  };
  return { type: 'refund.updated', title: titles[status], body: bodies[status] };
}
