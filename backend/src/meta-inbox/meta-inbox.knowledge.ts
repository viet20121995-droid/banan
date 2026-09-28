import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

/** Grok ends its reply with this when a human has to take over. */
export const HANDOFF_MARKER = '[CHUYEN_NGUOI]';

const CACHE_MS = 10 * 60 * 1000;
/** Keeps the prompt bounded if the catalogue grows. */
const MAX_PRODUCTS = 200;

const DAYS: [string, string][] = [
  ['mon', 'T2'],
  ['tue', 'T3'],
  ['wed', 'T4'],
  ['thu', 'T5'],
  ['fri', 'T6'],
  ['sat', 'T7'],
  ['sun', 'CN'],
];

/**
 * Builds Grok's system prompt from live data — branches (address, phone,
 * hours, paused) and the storefront menu with prices — so the bot never
 * quotes a price or an opening hour the app itself wouldn't show. Cached
 * for 10 minutes; menu edits reach the bot within that window.
 */
@Injectable()
export class MetaInboxKnowledge {
  private cache: { prompt: string; at: number } | null = null;

  constructor(private readonly prisma: PrismaService) {}

  async systemPrompt(): Promise<string> {
    if (this.cache && Date.now() - this.cache.at < CACHE_MS) return this.cache.prompt;
    const prompt = buildSystemPrompt(await this.stores(), await this.menu());
    this.cache = { prompt, at: Date.now() };
    return prompt;
  }

  private async stores(): Promise<string[]> {
    const stores = await this.prisma.store.findMany({
      select: {
        name: true,
        address: true,
        phone: true,
        openingHours: true,
        isPaused: true,
        pauseReason: true,
      },
      orderBy: { name: 'asc' },
    });
    return stores.map((s) => {
      const paused = s.isPaused
        ? ` — ĐANG TẠM NGƯNG NHẬN ĐƠN${s.pauseReason ? ` (${s.pauseReason})` : ''}`
        : '';
      return `- ${s.name}: ${s.address} · ĐT ${s.phone} · Giờ mở cửa: ${formatHours(s.openingHours)}${paused}`;
    });
  }

  private async menu(): Promise<string[]> {
    const products = await this.prisma.product.findMany({
      where: { isAvailable: true, category: { isHidden: false } },
      select: {
        name: true,
        basePrice: true,
        category: { select: { name: true } },
        variants: {
          where: { isAvailable: true },
          select: { size: true, flavor: true, priceDelta: true },
        },
      },
      orderBy: [{ category: { sortOrder: 'asc' } }, { name: 'asc' }],
      take: MAX_PRODUCTS,
    });
    return products.map((p) => {
      const base = Number(p.basePrice);
      const variants = p.variants
        .map((v) => {
          const label = [v.size, v.flavor].filter((x) => x && x !== 'Default').join(' ');
          return label ? `${label} ${formatVnd(base + Number(v.priceDelta))}` : null;
        })
        .filter(Boolean);
      const price = variants.length ? variants.join(', ') : formatVnd(base);
      return `- [${p.category.name}] ${p.name}: ${price}`;
    });
  }
}

export function buildSystemPrompt(stores: string[], menu: string[]): string {
  const orderUrl = process.env.CUSTOMER_APP_BASE_URL ?? 'https://order.banancakes.vn';
  const payment =
    process.env.COD_ENABLED === 'true'
      ? 'Thanh toán online (QR ngân hàng / thẻ) hoặc tiền mặt khi nhận.'
      : 'Đặt qua web thì thanh toán online trước (QR ngân hàng / thẻ). Không nhận tiền mặt khi giao.';

  return `Bạn là nhân viên tư vấn của tiệm bánh Banan (Banan Fukuoka Pâtisserie Saigon), trả lời tin nhắn Facebook/Instagram của khách.

GIỌNG: xưng "em", gọi khách "anh/chị". Thân thiện, ngắn gọn (2-5 câu), emoji vừa phải. Trả lời bằng tiếng Việt, trừ khi khách viết tiếng Anh thì trả lời tiếng Anh. Không dùng markdown (không **, không #) vì Messenger không hiển thị.

QUY TẮC:
1. CHỈ dùng thông tin trong phần DỮ LIỆU bên dưới. Không bịa giá, món, khuyến mãi, thời gian giao, phí ship hay chính sách không có trong dữ liệu.
2. Khách muốn đặt bánh: hướng dẫn đặt trên web ${orderUrl} (chọn bánh, chọn giờ nhận/giao, thanh toán online). Em không tự tạo hay xác nhận đơn trong chat.
3. ${payment} Không bao giờ gửi số tài khoản.
4. Chuyển cho nhân viên thật khi: bánh custom / vẽ hình / mẫu riêng, số lượng lớn hoặc đơn sỉ, khiếu nại hay đơn có vấn đề, hỏi về đơn đã đặt, khách yêu cầu gặp người, hoặc câu hỏi không có trong dữ liệu. Khi đó trả lời đúng một câu giữ khách kiểu "Dạ em chuyển anh/chị cho nhân viên tiệm, bạn ấy sẽ nhắn lại anh/chị sớm nhất ạ" rồi thêm ${HANDOFF_MARKER} ở cuối tin.
5. Khách gửi ảnh/sticker không kèm chữ: hỏi lại khách cần tư vấn gì; nếu là ảnh mẫu bánh muốn làm theo thì chuyển nhân viên (quy tắc 4).

DỮ LIỆU — CHI NHÁNH:
${stores.join('\n') || '(chưa có)'}

DỮ LIỆU — MENU (giá niêm yết trên web):
${menu.join('\n') || '(chưa có)'}`;
}

/** `{ mon: [["10:00","21:30"]], ... }` → "T2–CN 10:00–21:30" (groups equal days). */
export function formatHours(raw: unknown): string {
  const hours = (raw ?? {}) as Record<string, [string, string][] | undefined>;
  const groups: { from: string; to: string; value: string }[] = [];
  for (const [key, label] of DAYS) {
    const slots = hours[key] ?? [];
    const value = slots.length ? slots.map(([a, b]) => `${a}–${b}`).join(', ') : 'nghỉ';
    const last = groups[groups.length - 1];
    if (last && last.value === value) last.to = label;
    else groups.push({ from: label, to: label, value });
  }
  return groups
    .map((g) => `${g.from === g.to ? g.from : `${g.from}–${g.to}`} ${g.value}`)
    .join('; ');
}

function formatVnd(n: number): string {
  return `${Math.round(n).toLocaleString('vi-VN')}đ`;
}
