import { OrderStatus, KitchenStatus } from '@prisma/client';

export interface NotificationTemplate {
  type: string;
  title: string;
  body: string;
}

const ORDER_STATUS_LABEL: Record<OrderStatus, string> = {
  PENDING: 'Đã đặt hàng',
  ACCEPTED: 'Đã nhận đơn',
  IN_PREPARATION: 'Đang chuẩn bị',
  SENT_TO_KITCHEN: 'Đã chuyển bếp trung tâm',
  READY_FOR_PICKUP: 'Sẵn sàng để lấy',
  DELIVERING: 'Đang giao hàng',
  COMPLETED: 'Hoàn tất đơn hàng',
  CANCELLED: 'Đơn đã huỷ',
  REFUNDED: 'Đơn đã hoàn tiền',
};

const ORDER_STATUS_BODY: Record<OrderStatus, (code: string) => string> = {
  PENDING: (c) => `Đã tạo đơn ${c}.`,
  ACCEPTED: (c) => `Đơn ${c} của bạn đã được tiếp nhận.`,
  IN_PREPARATION: (c) => `Chúng tôi đang chuẩn bị đơn ${c}.`,
  SENT_TO_KITCHEN: (c) =>
    `Đơn ${c} đang được làm tại bếp trung tâm.`,
  READY_FOR_PICKUP: (c) => `Đơn ${c} đã sẵn sàng để lấy!`,
  DELIVERING: (c) => `Đơn ${c} đang trên đường giao!`,
  COMPLETED: (c) => `Cảm ơn bạn đã đặt đơn ${c}. Chúc ngon miệng!`,
  CANCELLED: (c) => `Đơn ${c} đã bị huỷ.`,
  REFUNDED: (c) => `Đơn ${c} đã được hoàn tiền.`,
};

const KITCHEN_STATUS_LABEL: Record<KitchenStatus, string> = {
  PENDING_ACK: 'Chờ bếp tiếp nhận',
  PREPARING: 'Bếp đang làm',
  READY_DISPATCH: 'Sẵn sàng giao đi',
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
    body: `Đơn ${code} hiện ${KITCHEN_STATUS_LABEL[status].toLowerCase()}.`,
  };
}

export function refundUpdatedNotification(
  code: string,
  status: 'APPROVED' | 'PROCESSING' | 'COMPLETED' | 'REJECTED',
): NotificationTemplate {
  const titles: Record<string, string> = {
    APPROVED: 'Đã duyệt hoàn tiền',
    PROCESSING: 'Đang xử lý hoàn tiền',
    COMPLETED: 'Hoàn tiền hoàn tất',
    REJECTED: 'Từ chối hoàn tiền',
  };
  const bodies: Record<string, string> = {
    APPROVED: `Yêu cầu hoàn tiền cho đơn ${code} đã được duyệt.`,
    PROCESSING: `Yêu cầu hoàn tiền cho đơn ${code} đang được xử lý.`,
    COMPLETED: `Hoàn tiền cho đơn ${code} đã hoàn tất.`,
    REJECTED: `Yêu cầu hoàn tiền cho đơn ${code} đã bị từ chối.`,
  };
  return { type: 'refund.updated', title: titles[status], body: bodies[status] };
}
