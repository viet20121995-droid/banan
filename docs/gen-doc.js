/* Sinh tài liệu hệ thống + hướng dẫn vận hành Banan (.docx) */
const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, LevelFormat, TableOfContents, HeadingLevel,
  BorderStyle, WidthType, ShadingType, PageNumber, PageBreak, VerticalAlign, ImageRun,
} = require('docx');

const CW = 9026; // content width A4, 1" margins
const cellM = { top: 60, bottom: 60, left: 110, right: 110 };
const BR = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const BORD = { top: BR, bottom: BR, left: BR, right: BR };
const GREEN = "1E7A3E", PINK = "C9405C", DARK = "2B2A22";

const H1 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(t)] });
const H2 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(t)] });
const H3 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun(t)] });
const P = (t, opts = {}) => new Paragraph({ spacing: { after: 120 }, children: Array.isArray(t) ? t : [new TextRun({ text: t, ...opts })] });
const r = (text, opts = {}) => new TextRun({ text, ...opts });
const b = (text) => new TextRun({ text, bold: true });

const bullets = (items) => items.map((it) =>
  new Paragraph({ numbering: { reference: "bul", level: 0 }, spacing: { after: 40 },
    children: Array.isArray(it) ? it : [new TextRun(it)] }));
const nums = (items) => items.map((it) =>
  new Paragraph({ numbering: { reference: "num", level: 0 }, spacing: { after: 40 },
    children: Array.isArray(it) ? it : [new TextRun(it)] }));

const code = (lines) => (Array.isArray(lines) ? lines : [lines]).map((ln, i, arr) =>
  new Paragraph({
    shading: { type: ShadingType.CLEAR, fill: "F4F4F2" },
    spacing: { after: i === arr.length - 1 ? 120 : 0, before: i === 0 ? 40 : 0 },
    children: [new TextRun({ text: ln || " ", font: "Consolas", size: 17 })],
  }));

function cellPars(c) {
  if (Array.isArray(c)) return c.map((s) => new Paragraph({ children: [new TextRun({ text: s, size: 19 })] }));
  return [new Paragraph({ children: [new TextRun({ text: String(c), size: 19 })] })];
}
function table(headers, rows, widths) {
  const total = widths.reduce((a, x) => a + x, 0);
  const head = new TableRow({ tableHeader: true, children: headers.map((h, i) =>
    new TableCell({ borders: BORD, width: { size: widths[i], type: WidthType.DXA },
      shading: { fill: GREEN, type: ShadingType.CLEAR }, margins: cellM, verticalAlign: VerticalAlign.CENTER,
      children: [new Paragraph({ children: [new TextRun({ text: h, bold: true, color: "FFFFFF", size: 19 })] })] })) });
  const body = rows.map((row, ri) => new TableRow({ children: row.map((c, i) =>
    new TableCell({ borders: BORD, width: { size: widths[i], type: WidthType.DXA }, margins: cellM,
      shading: ri % 2 ? { fill: "FAFAF8", type: ShadingType.CLEAR } : undefined,
      children: cellPars(c) })) }));
  return new Table({ width: { size: total, type: WidthType.DXA }, columnWidths: widths, rows: [head, ...body] });
}
const SP = (h = 80) => new Paragraph({ spacing: { after: h }, children: [] });
const img = (file, w, h, cap) => imgF("diagrams/" + file, w, h, cap, file);
const imgF = (path, w, h, cap, name) => [
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 140, after: 30 },
    children: [new ImageRun({ type: "png", data: fs.readFileSync(path),
      transformation: { width: w, height: h },
      altText: { title: cap, description: cap, name: name || path } })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 180 },
    children: [new TextRun({ text: cap, italics: true, size: 17, color: "999999" })] }),
];

const children = [];

// ───────── Title page ─────────
children.push(
  new Paragraph({ spacing: { before: 1600, after: 60 }, alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "BANAN", bold: true, size: 72, color: PINK, font: "Georgia" })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 40 },
    children: [new TextRun({ text: "Tài liệu Hệ thống & Hướng dẫn Vận hành", size: 32, color: DARK })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
    children: [new TextRun({ text: "Nền tảng đặt bánh kissaten — banancakes.vn", size: 22, italics: true, color: "777777" })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "Phiên bản 1.0  ·  Cập nhật 12/06/2026", size: 22 })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 1200 }, children: [new TextRun({ text: "CÔNG TY TNHH MTV DỊCH VỤ VƯỜN CHUỐI", size: 20, color: "777777" })] }),
  new Paragraph({ children: [new PageBreak()] }),
);

// ───────── TOC ─────────
children.push(H1("Mục lục"),
  new TableOfContents("Mục lục", { hyperlink: true, headingStyleRange: "1-2" }),
  new Paragraph({ children: [new PageBreak()] }));

// ───────── 1. Tổng quan ─────────
children.push(H1("1. Tổng quan dự án"));
children.push(P([b("Banan"), r(" là nền tảng đặt bánh kiểu kissaten (tiệm bánh – cà phê Nhật) vận hành thực tế tại banancakes.vn. Hệ thống gồm "), b("3 ứng dụng web"), r(" dùng chung một backend duy nhất:")]));
children.push(...bullets([
  [b("App Khách hàng"), r(" (banancakes.vn) — duyệt thực đơn, đặt bánh, theo dõi đơn, tài khoản & điểm thưởng.")],
  [b("App Cửa hàng / Quản trị"), r(" (merchant.banancakes.vn) — quản lý đơn, thực đơn, khách hàng, khuyến mãi, báo cáo.")],
  [b("App Bếp"), r(" (kitchen.banancakes.vn) — nhận đơn cần làm, cập nhật trạng thái chế biến.")],
]));
children.push(P([r("Mã nguồn là một "), b("monorepo Flutter"), r(" (quản lý bằng Melos): 3 app + 5 gói dùng chung ("), r("core, design_system, domain, data, features_shared", { font: "Consolas", size: 18 }), r("). Backend là một dịch vụ "), b("NestJS"), r(". Toàn bộ chạy bằng Docker Compose trên một máy chủ ảo (VPS).")]));

// ───────── 2. Kiến trúc ─────────
children.push(H1("2. Kiến trúc hệ thống"));
children.push(P("Hệ thống chia thành 5 tầng, dữ liệu đi một chiều rõ ràng từ người dùng xuống cơ sở dữ liệu:"));
children.push(table(["Tầng", "Thành phần", "Vai trò"], [
  ["Ứng dụng", "3 app Flutter Web (Khách, Cửa hàng, Bếp)", "Giao diện người dùng; gọi API qua Dio; cập nhật realtime qua WebSocket"],
  ["Cổng vào", "Caddy 2", "Reverse proxy, HTTPS tự động (Let's Encrypt), phục vụ file web tĩnh"],
  ["Backend", "NestJS 10 + Realtime Gateway (Socket.IO)", "REST /api/v1, WebSocket, toàn bộ logic nghiệp vụ, Prisma ORM"],
  ["Dữ liệu", "PostgreSQL 16 · Redis 7 · volume uploads", "Nguồn sự thật · cache/throttle/realtime · lưu ảnh /uploads"],
  ["Dịch vụ ngoài", "Resend · Firebase FCM", "Gửi email giao dịch + newsletter · push web notification"],
], [1500, 3300, 4226]));
children.push(...img("arch.png", 600, 575, "Hình 1. Sơ đồ tổng thể kiến trúc hệ thống Banan"));
children.push(H2("2.1 Vòng đời một request"));
children.push(...nums([
  [r("App gọi tới "), r("api.banancakes.vn/api/v1", { font: "Consolas", size: 18 }), r(" qua thư viện Dio.")],
  "Caddy chuyển tiếp vào container backend (reverse proxy).",
  [r("NestJS chạy chuỗi: "), b("JwtGuard → RolesGuard (phân quyền) → Throttler → Controller → Service → Prisma → PostgreSQL"), r(".")],
  [r("Kết quả được "), b("EnvelopeInterceptor"), r(" bọc thành "), r("{ data: … }", { font: "Consolas", size: 18 }), r("; lỗi trả "), r("{ error: { code, message } }", { font: "Consolas", size: 18 }), r(".")],
  [r("Lớp "), r("data", { font: "Consolas", size: 18 }), r(" của app parse thành DTO → entity "), r("domain", { font: "Consolas", size: 18 }), r(", gói trong "), r("Result<T, AppFailure>", { font: "Consolas", size: 18 }), r(" để UI xử lý thành công / lỗi rõ ràng.")],
]));

// ───────── 3. Công nghệ ─────────
children.push(H1("3. Công nghệ sử dụng"));
children.push(table(["Lớp", "Công nghệ chính"], [
  ["Frontend", "Flutter Web (monorepo Melos), Riverpod (state), go_router (điều hướng), Dio (HTTP), Equatable, fl_chart, file_picker"],
  ["Backend", "NestJS 10, Prisma 5 (ORM), class-validator, Socket.IO (realtime), JWT (xác thực), Throttler (chống spam)"],
  ["Cơ sở dữ liệu", "PostgreSQL 16 (dữ liệu chính), Redis 7 (cache · throttle · realtime adapter)"],
  ["Hạ tầng", "Docker Compose, Caddy 2 (HTTPS Let's Encrypt), VPS Ubuntu (PA Việt Nam)"],
  ["Tích hợp ngoài", "Resend (email), Firebase Admin (FCM web push)"],
], [1800, 7226]));

// ───────── 4. Cấu trúc mã nguồn ─────────
children.push(H1("4. Cấu trúc mã nguồn"));
children.push(H2("4.1 Ứng dụng (apps/)"));
children.push(...bullets([
  [r("apps/banan_customer", { font: "Consolas", size: 18 }), r(" — app khách hàng")],
  [r("apps/banan_merchant", { font: "Consolas", size: 18 }), r(" — app cửa hàng / quản trị")],
  [r("apps/banan_kitchen", { font: "Consolas", size: 18 }), r(" — app bếp")],
]));
children.push(H2("4.2 Gói dùng chung (packages/)"));
children.push(table(["Gói", "Nội dung"], [
  ["core", "Tiện ích nền: Result<T, AppFailure>, lỗi, hằng số, cấu hình môi trường"],
  ["design_system", "Màu (BananColors), khoảng cách (BananSpacing), bo góc, widget UI dùng chung"],
  ["domain", "Entity & interface repository (Product, Order, Customer, Campaign…) — không phụ thuộc hạ tầng"],
  ["data", "DTO, API client (Dio), repository implementation; ánh xạ JSON ↔ domain"],
  ["features_shared", "Provider Riverpod & widget dùng chung giữa các app (strings, auth session…)"],
], [2000, 7026]));
children.push(H2("4.3 Backend (backend/)"));
children.push(...bullets([
  [r("src/<module>/", { font: "Consolas", size: 18 }), r(" — mỗi nghiệp vụ là một module (controller + service + dto)")],
  [r("prisma/schema.prisma", { font: "Consolas", size: 18 }), r(" — định nghĩa toàn bộ bảng dữ liệu")],
  [r("prisma/migrations/", { font: "Consolas", size: 18 }), r(" — lịch sử thay đổi CSDL (chạy bằng prisma migrate deploy)")],
]));

// ───────── 5. Module backend ─────────
children.push(H1("5. Các module backend"));
children.push(P("Backend gồm khoảng 40 module. Nhóm chính:"));
children.push(table(["Nhóm", "Module tiêu biểu", "Chức năng"], [
  ["Xác thực", "Auth", "Đăng nhập JWT, refresh token, đổi mật khẩu/email, phân quyền 6 vai trò"],
  ["Thực đơn", "Products, Categories, ProductVariant, Collections, Bundles, Banners, Threads", "Sản phẩm, danh mục, biến thể/size, bộ sưu tập, combo, banner, bài đăng"],
  ["Bán hàng", "Orders, OrderItem, Payments, Refunds, Kitchen, Reviews", "Đặt hàng, thanh toán, hoàn tiền, luồng bếp, đánh giá"],
  ["Khuyến mãi", "Promotions, Coupons, GiftCards, Loyalty, Marketing, PromoPopup", "14 chương trình KM, mã giảm giá, gift card, điểm Micho, popup"],
  ["Khách hàng", "Customers, Addresses, Wishlist, Newsletter", "Hồ sơ/CRM, sổ địa chỉ, yêu thích, bản tin email"],
  ["Vận hành", "Stores, DeliveryConfig, DisplayConfig, SiteContent, Geo", "Cửa hàng, phí giao, hiển thị tồn kho, nội dung trang, địa giới"],
  ["Hệ thống", "Notifications, Realtime, Reports, Analytics, Uploads, Schedule, Health", "Thông báo/push, WebSocket, báo cáo, thống kê, tải ảnh, cron, health-check"],
], [1500, 4100, 3426]));

// ───────── 6. Mô hình dữ liệu ─────────
children.push(H1("6. Mô hình dữ liệu (các bảng chính)"));
children.push(P([b("Order"), r(" là bảng trung tâm. "), b("OrderItem"), r(" chụp ảnh giá lúc mua (lưu cứng tên + đơn giá) nên sửa giá sản phẩm về sau không làm sai đơn cũ.")]));
children.push(table(["Bảng", "Trường chính", "Quan hệ"], [
  ["User", "id, fullName, email, phone, role, pointsBalance, membershipTier", "1—N Order, Address, Review, LoyaltyEvent, Wishlist, DeviceToken"],
  ["Store", "id, name, defaultLeadHours, preparationLeadMinutes", "1—N Product, 1—N Order"],
  ["Category", "id, name, sortOrder", "1—N Product"],
  ["Product", "id, name, basePrice, images[], leadTimeHours, preparationMinutes", "N—1 Store, N—1 Category, 1—N ProductVariant, 1—N OrderItem"],
  ["ProductVariant", "id, label, priceDelta", "N—1 Product (size/giá)"],
  ["Order", "id, code, status, total, subtotal, fulfillmentType, scheduledFor, campaignInfo, giftCardCode", "N—1 User, N—1 Store, N—1 Coupon, 1—N OrderItem"],
  ["OrderItem", "orderId, productId, variantId, quantity, unitPrice, personalization", "N—1 Order, N—1 Product/Variant"],
  ["Coupon", "id, code, type, value, minSubtotal, maxRedemptions", "1—N CouponRedemption"],
  ["Campaign", "type (14 loại), scope, value, lịch chạy", "Không khoá ngoại — áp khi checkout, lưu vết qua Order.campaignInfo"],
  ["GiftCard", "code, balanceVnd, isActive", "Không khoá ngoại — áp qua Order.giftCardCode"],
  ["LoyaltyEvent", "userId, delta, reason, balanceAfter", "N—1 User (nguồn sự thật của điểm Micho)"],
], [1500, 4400, 3126]));

// ───────── 7. Phân quyền ─────────
children.push(H1("7. Phân quyền (RBAC)"));
children.push(P([r("Có "), b("6 vai trò"), r(". Nguyên tắc: "), b("Admin = toàn chuỗi"), r("; cửa hàng & bếp giới hạn theo phạm vi của họ; khách chỉ thấy dữ liệu của chính mình. Mỗi endpoint gắn "), r("@Roles(...)", { font: "Consolas", size: 18 }), r(" và được RolesGuard kiểm tra.")]));
children.push(table(["Vai trò", "App", "Đơn hàng", "Thực đơn", "Khách/CRM", "Marketing", "Cấu hình"], [
  ["Admin", "Quản trị", "✓ toàn chuỗi", "✓", "✓", "✓", "✓"],
  ["Chủ cửa hàng", "Quản trị", "✓ cửa hàng", "✓", "✓", "✓", "◐"],
  ["NV cửa hàng", "Quản trị", "✓", "◐", "◐", "—", "—"],
  ["Quản lý bếp", "Bếp", "◐ bếp", "—", "—", "—", "◐ mẻ"],
  ["NV bếp", "Bếp", "◐ cập nhật", "—", "—", "—", "—"],
  ["Khách hàng", "Khách", "◐ của mình", "—", "—", "—", "—"],
], [1700, 1300, 1500, 1140, 1300, 1100, 986].slice(0, 7)));
children.push(P([r("Chú thích: ", { italics: true }), r("✓ đầy đủ · ◐ giới hạn (1 cửa hàng / của mình) · — không có.", { italics: true, size: 19 })]));
children.push(...img("rbac.png", 600, 288, "Hình 2. Ma trận phân quyền theo 6 vai trò"));

// ───────── 8. Luồng đặt hàng ─────────
children.push(H1("8. Luồng đặt hàng"));
children.push(...nums([
  "Khách duyệt thực đơn, thêm vào giỏ, chọn hình thức nhận + lịch (giỏ tự kiểm thời gian chuẩn bị, mặc định giờ sớm nhất hợp lệ).",
  [r("Khách gửi "), r("POST /orders", { font: "Consolas", size: 18 }), r(" kèm coupon / điểm / gift card.")],
  [b("Backend tính giá: "), r("PromotionsService đánh giá khuyến mãi → cộng coupon → điểm Micho → gift card (cắt không vượt tạm tính).")],
  [b("Tạo đơn trong transaction: "), r("ghi Order + OrderItem + giảm tồn kho cùng lúc → không bao giờ bán quá số lượng.")],
  [b("Bắn realtime + push: "), r("WebSocket + FCM gửi đơn mới sang app Cửa hàng và Bếp ngay lập tức (kèm chuông).")],
  "Khách nhận mã đơn + email xác nhận (Resend).",
  "Bếp/cửa hàng đổi trạng thái → đẩy ngược về app Khách qua WebSocket để theo dõi.",
]));
children.push(P([b("Điểm cốt lõi: "), r("giá luôn được backend chốt lại (app không tự tính) → không gian lận; giảm tồn nằm trong cùng transaction với tạo đơn.")]));
children.push(...img("flow.png", 600, 408, "Hình 3. Luồng tuần tự đặt hàng (Khách → API → Bếp → Khách)"));

// ───────── 9. Engine khuyến mãi ─────────
children.push(H1("9. Engine khuyến mãi"));
children.push(P([r("Quy tắc chống cộng dồn: "), b("mỗi món chỉ nhận 1 khuyến mãi tốt nhất"), r(". Hàm "), r("PromotionsService.evaluate()", { font: "Consolas", size: 18 }), r(" chạy 3 bước:")]));
children.push(...nums([
  [b("Mỗi DÒNG → 1 KM tốt nhất: "), r("PRODUCT_DISCOUNT, CATEGORY_DISCOUNT, FLASH_SALE, HAPPY_HOUR.")],
  [b("Cả GIỎ: "), r("BUY_X_GET_Y (mua X tặng Y).")],
  [b("Theo KHÁCH → 1 KM tốt nhất: "), r("FIRST_ORDER, BIRTHDAY, REACTIVATION, MEMBERSHIP_BENEFIT.")],
]));
children.push(P([r("Kết quả = "), r("campaignDiscount", { font: "Consolas", size: 18 }), r(" (lưu vết "), r("campaignInfo", { font: "Consolas", size: 18 }), r("). Sau đó OrdersService cộng tiếp Coupon → Điểm Micho → Gift card, cắt ≤ tạm tính, ra tổng tiền cuối.")]));
children.push(...img("promo.png", 600, 399, "Hình 4. Luồng engine khuyến mãi"));
children.push(H2("9.1 Các loại chương trình"));
children.push(table(["Loại (CampaignType)", "Ý nghĩa"], [
  ["PRODUCT_DISCOUNT", "Giảm giá theo sản phẩm cụ thể"],
  ["CATEGORY_DISCOUNT", "Giảm giá theo danh mục"],
  ["FLASH_SALE", "Giảm sốc trong khung thời gian ngắn"],
  ["HAPPY_HOUR", "Giảm theo khung giờ trong ngày"],
  ["BUY_X_GET_Y", "Mua X tặng/giảm Y (cấp giỏ hàng)"],
  ["FIRST_ORDER", "Ưu đãi đơn hàng đầu tiên"],
  ["BIRTHDAY", "Ưu đãi dịp sinh nhật khách"],
  ["REACTIVATION", "Kéo khách đã lâu không mua quay lại"],
  ["MEMBERSHIP_BENEFIT", "Ưu đãi theo hạng thành viên (Bronze→Platinum)"],
], [3000, 6026]));
children.push(P([r("Hệ thống liên quan: ", { italics: true }), r("Coupon (mã giảm giá), Gift card (thẻ quà), Loyalty/Micho (điểm thưởng), Bundle (combo) là các cơ chế riêng, cộng thêm sau bước campaign.", { italics: true, size: 19 })]));

// ───────── 10. Vòng đời đơn ─────────
children.push(H1("10. Vòng đời trạng thái đơn"));
children.push(P([b("Đường hạnh phúc: "), r("PENDING → ACCEPTED → IN_PREPARATION → (SENT_TO_KITCHEN nếu cần bếp) → READY_FOR_PICKUP → COMPLETED.")]));
children.push(table(["Trạng thái", "Ý nghĩa"], [
  ["PENDING", "Đơn vừa tạo, chờ cửa hàng xác nhận"],
  ["ACCEPTED", "Cửa hàng đã nhận đơn"],
  ["IN_PREPARATION", "Đang chuẩn bị"],
  ["SENT_TO_KITCHEN", "Chuyển bếp trung tâm (chỉ đơn cần bếp)"],
  ["READY_FOR_PICKUP", "Sẵn sàng — nhận tại quầy hoặc bắt đầu giao"],
  ["DELIVERING", "Đang giao hàng (nhánh giao)"],
  ["COMPLETED", "Hoàn tất"],
  ["CANCELLED", "Đã huỷ (khi còn PENDING/ACCEPTED)"],
  ["REFUNDED", "Đã hoàn tiền (sau khi hoàn tất)"],
], [2600, 6426]));
children.push(P([r("Tại READY_FOR_PICKUP rẽ 2 nhánh: "), b("nhận tại quầy"), r(" (→ COMPLETED) hoặc "), b("giao hàng"), r(" (→ DELIVERING → COMPLETED). Lane bếp chạy song song: PENDING_ACK → PREPARING → READY_DISPATCH.")]));
children.push(...img("status.png", 600, 328, "Hình 5. Vòng đời trạng thái đơn hàng"));

// ───────── 11. Thông báo & Email ─────────
children.push(H1("11. Thông báo & Email"));
children.push(...bullets([
  [b("In-app + Push (Firebase FCM): "), r("đơn mới (cửa hàng/bếp), cập nhật đơn (khách), broadcast marketing. Có chuông trên app cửa hàng/bếp.")],
  [b("Email (Resend): "), r("xác nhận đơn, newsletter, xác nhận đăng ký nhận tin, đổi email, mã giảm giá tặng. Nếu chưa cấu hình RESEND_API_KEY, hệ thống ghi log \"[email dry-run]\" thay vì gửi thật.")],
]));

// ───────── 12. Triển khai ─────────
children.push(new Paragraph({ children: [new PageBreak()] }));
children.push(H1("12. Hướng dẫn TRIỂN KHAI (Deploy)"));
children.push(H2("12.1 Thông tin máy chủ"));
children.push(...bullets([
  [b("VPS: "), r("PA Việt Nam · Ubuntu · IP 112.213.87.246")],
  [b("Thư mục dự án: "), r("/opt/banan", { font: "Consolas", size: 18 })],
  [b("Web tĩnh: "), r("/opt/banan/web/{customer,merchant,kitchen}", { font: "Consolas", size: 18 })],
  [b("Tên miền: "), r("banancakes.vn · merchant.banancakes.vn · kitchen.banancakes.vn · api.banancakes.vn")],
]));
children.push(H2("12.2 Cập nhật giao diện (Flutter web)"));
children.push(P("Trên máy phát triển (có Flutter + Git Bash), build app cần cập nhật:"));
children.push(...code([
  "cd apps/banan_merchant   # hoặc banan_customer / banan_kitchen",
  "flutter build web --release \\",
  "  --dart-define=BANAN_API_BASE_URL=https://api.banancakes.vn/api/v1 \\",
  "  --dart-define=BANAN_WS_URL=https://api.banancakes.vn \\",
  "  --dart-define=BANAN_CUSTOMER_APP_URL=https://banancakes.vn \\",
  "  --dart-define=BANAN_ENV=prod",
  "tar czf banan-web-merchant.tgz -C build/web .",
]));
children.push(P("Tải lên (PowerShell):"));
children.push(...code('scp "banan-web-merchant.tgz" root@112.213.87.246:/tmp/'));
children.push(P("Trên máy chủ (PuTTY) — thay 'merchant' bằng app tương ứng:"));
children.push(...code([
  "cd /opt/banan",
  "find web/merchant -mindepth 1 -delete",
  "tar xzf /tmp/banan-web-merchant.tgz -C web/merchant",
  "rm /tmp/banan-web-merchant.tgz",
  "docker compose -f docker-compose.prod.yml --env-file infra/.env.prod restart caddy",
]));
children.push(H2("12.3 Cập nhật Backend"));
children.push(P("Khi có thay đổi backend (kèm migration nếu có):"));
children.push(...code([
  "cd /opt/banan",
  "git pull",
  "docker compose -f docker-compose.prod.yml --env-file infra/.env.prod up -d --build backend",
  "# Dockerfile tự chạy: prisma migrate deploy",
]));
children.push(P("Kiểm tra sau deploy:"));
children.push(...code([
  'curl -sS -o /dev/null -w "merchant %{http_code}\\n" https://merchant.banancakes.vn/',
  'curl -sS -o /dev/null -w "api %{http_code}\\n" https://api.banancakes.vn/api/v1/health',
  "# Mong đợi: 200 / 200",
]));
children.push(P([b("Lưu ý: "), r("sau khi deploy web, nhấn Ctrl+Shift+R trong trình duyệt để xoá cache và thấy bản mới.")]));

// ───────── 13. Hướng dẫn sử dụng ─────────
children.push(new Paragraph({ children: [new PageBreak()] }));
children.push(H1("13. Hướng dẫn SỬ DỤNG (Cửa hàng / Admin)"));

children.push(H2("13.1 Sản phẩm & ảnh món"));
children.push(...bullets([
  [r("Vào "), b("Thực đơn → Sản phẩm"), r(" → tạo/sửa món. Mục "), b("Hình ảnh"), r(": nên dùng ảnh "), b("vuông 1200×1200px (1:1)"), r(", bánh nằm giữa khung, nền sáng; ≤ 8 MB/ảnh (server tối đa 20 MB); định dạng JPG/PNG/WebP/AVIF.")],
  [b("Thời gian báo trước (giờ): "), r("đặt số giờ khách phải đặt trước cho món cần chuẩn bị (bánh đặt). Khách sẽ thấy cảnh báo và giờ nhận sớm nhất tự động ở bước đặt.")],
]));

children.push(H2("13.2 Quản lý khách hàng"));
children.push(...bullets([
  [b("Xem: "), r("Khách hàng → Danh sách → bấm 1 khách để xem hồ sơ, địa chỉ, đơn, chi tiêu, điểm Micho.")],
  [b("Sửa: "), r("trong trang khách, nút \"Sửa thông tin\" → đổi tên / SĐT / email / ngày sinh.")],
  [b("Xuất CSV: "), r("ở danh sách, nút ⬇ \"Xuất danh sách (CSV)\" → tải file (UTF-8, mở Excel tiếng Việt chuẩn); tôn trọng ô tìm kiếm đang lọc.")],
  [b("Khác: "), r("gửi tin nhắn, điều chỉnh điểm Micho, tặng mã giảm giá, ghi chú & nhãn CRM.")],
]));

children.push(H2("13.3 Newsletter (gửi email cho khách)"));
children.push(...bullets([
  [r("Vào "), b("Marketing → Newsletter"), r(". Tab \"Người đăng ký\" xem danh sách opt-in; tab \"Đã gửi\" xem lịch sử.")],
  [b("Soạn email: "), r("nút \"Soạn email\" → thêm ảnh tiêu đề (tuỳ chọn) → nhập tiêu đề + nội dung → Xem trước → Gửi thử tới email mình → chọn đối tượng (Người đăng ký / Tất cả khách hàng / Cả hai) → bật kèm thông báo in-app (tuỳ chọn) → Gửi.")],
  [b("Lưu ý gói Resend: "), r("bản miễn phí ~100 email/ngày; danh sách lớn cần nâng gói trả phí.")],
]));

children.push(H2("13.4 Khuyến mãi"));
children.push(...bullets([
  [r("Vào "), b("Marketing → Khuyến mãi"), r(" để tạo các chương trình (giảm theo món/danh mục, flash sale, happy hour, mua X tặng Y, đơn đầu, sinh nhật, khách quay lại, ưu đãi hạng thành viên).")],
  [b("Mã giảm giá: "), r("Marketing → Mã giảm giá. "), b("Chương trình ưu đãi / Popup / Banner / Bài đăng"), r(" cũng nằm trong nhóm Marketing.")],
]));

children.push(H2("13.5 Vận hành đơn & báo cáo"));
children.push(...bullets([
  [b("Đơn hàng: "), r("VẬN HÀNH → Đơn hàng — xác nhận, chuyển bếp, đổi trạng thái, in phiếu.")],
  [b("Báo cáo: "), r("PHÂN TÍCH → Dashboard (tổng quan) và Báo cáo (xuất Excel).")],
  [b("Điều hướng: "), r("sidebar gom theo nhóm gập được — vào trang nào thì nhóm đó tự mở; bấm tên nhóm để mở/đóng.")],
]));

// ───────── 14. Môi trường & cấu hình ─────────
children.push(H1("14. Môi trường & Cấu hình"));
children.push(P([r("Cấu hình production nằm ở "), r("infra/.env.prod", { font: "Consolas", size: 18 }), r(" trên máy chủ (KHÔNG commit vào Git). Các biến chính:")]));
children.push(table(["Biến", "Ý nghĩa"], [
  ["DATABASE_URL", "Chuỗi kết nối PostgreSQL"],
  ["REDIS_URL", "Kết nối Redis"],
  ["JWT_SECRET / JWT_REFRESH_SECRET", "Khoá ký token (giữ bí mật tuyệt đối)"],
  ["BASE_DOMAIN", "banancakes.vn — dùng để tạo URL email/link"],
  ["RESEND_API_KEY", "Khoá gửi email Resend (trống = chế độ dry-run)"],
  ["EMAIL_FROM / CONTACT_TO", "Địa chỉ gửi & nhận liên hệ"],
  ["FIREBASE_* (service account)", "Cấu hình Firebase Admin cho FCM push"],
  ["CORS_ORIGINS", "Danh sách domain được phép gọi API"],
], [3200, 5826]));
children.push(P([r("App Flutter nhận URL API qua "), r("--dart-define", { font: "Consolas", size: 18 }), r(" lúc build (xem mục 12.2), không phải file .env.")]));

// ───────── 15. Bảo mật & vận hành ─────────
children.push(H1("15. Bảo mật & Lưu ý vận hành"));
children.push(...bullets([
  [b("Không bao giờ dán bí mật"), r(" (API key, mật khẩu, .env, JSON Firebase) vào chat/email/commit. Chỉ truyền qua scp hoặc nhập trực tiếp trên máy chủ.")],
  [b("Đổi mật khẩu máy chủ"), r(" định kỳ; mật khẩu dùng chung cho SSH/VNC/control panel nên đổi cả ba khi nghi lộ.")],
  [b("Sao lưu CSDL"), r(" định kỳ: pg_dump database + sao lưu volume uploads.")],
  [b("VNPay"), r(" cần khoá merchant thật (TMN code + Hash secret) mới bật thanh toán online.")],
  [b("Ảnh ví dụ"), r(" (loremflickr) chỉ là tạm — nên thay bằng ảnh thật của cửa hàng.")],
  [b("Bộ Công Thương"), r(": cần giấy ATTP + chứng minh sở hữu tên miền + ảnh chụp các trang chính sách để nộp hồ sơ.")],
]));

// ───────── 16. Phụ lục lệnh ─────────
children.push(H1("16. Phụ lục — Lệnh thường dùng (trên máy chủ)"));
children.push(P("Xem log backend:"));
children.push(...code("docker compose -f /opt/banan/docker-compose.prod.yml logs -f backend"));
children.push(P("Khởi động lại dịch vụ:"));
children.push(...code("docker compose -f /opt/banan/docker-compose.prod.yml --env-file infra/.env.prod restart backend caddy"));
children.push(P("Sao lưu cơ sở dữ liệu:"));
children.push(...code('docker exec banan-postgres pg_dump -U banan banan > /root/banan-backup-$(date +%F).sql'));
children.push(P("Trạng thái các container:"));
children.push(...code("docker compose -f /opt/banan/docker-compose.prod.yml ps"));
// ───────── 17. Ảnh chụp giao diện thật ─────────
children.push(new Paragraph({ children: [new PageBreak()] }));
children.push(H1("17. Phụ lục — Giao diện thực tế (ảnh chụp)"));
children.push(P("Ảnh chụp trực tiếp từ ứng dụng khách đang chạy tại banancakes.vn (môi trường production)."));
children.push(...imgF("screenshots/customer-hero.png", 600, 290, "Hình 6. Trang chủ app Khách — banner, nút “Đặt hàng”, chọn hình thức nhận, tìm kiếm, danh mục", "customer-hero"));
children.push(...imgF("screenshots/customer-menu.png", 600, 281, "Hình 7. Thực đơn — danh mục bộ sưu tập + lưới sản phẩm", "customer-menu"));
children.push(P([b("Ghi chú: "), r("ảnh app Cửa hàng/Admin và Bếp cần đăng nhập tài khoản nội bộ nên chưa kèm ở đây. Khi cần, chỉ việc chụp các màn hình đó (đăng nhập sẵn) và bổ sung — tài liệu này có sẵn chỗ để chèn tiếp.")]));
children.push(SP(200));
children.push(new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "— Hết —", italics: true, color: "999999" })] }));

// ───────── Build doc ─────────
const doc = new Document({
  styles: {
    default: { document: { run: { font: "Arial", size: 22 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 30, bold: true, color: GREEN, font: "Arial" },
        paragraph: { spacing: { before: 320, after: 160 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 25, bold: true, color: DARK, font: "Arial" },
        paragraph: { spacing: { before: 200, after: 100 }, outlineLevel: 1 } },
      { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 22, bold: true, color: "555555", font: "Arial" },
        paragraph: { spacing: { before: 140, after: 80 }, outlineLevel: 2 } },
    ],
  },
  numbering: {
    config: [
      { reference: "bul", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 280 } } } }] },
      { reference: "num", levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 540, hanging: 280 } } } }] },
    ],
  },
  sections: [{
    properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } } },
    headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "Banan — Tài liệu hệ thống", size: 16, color: "999999" })] })] }) },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "Trang ", size: 16, color: "999999" }), new TextRun({ children: [PageNumber.CURRENT], size: 16, color: "999999" })] })] }) },
    children,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync("Banan-He-Thong-Va-Huong-Dan.docx", buf);
  console.log("✓ Đã tạo Banan-He-Thong-Va-Huong-Dan.docx (" + buf.length + " bytes)");
});
