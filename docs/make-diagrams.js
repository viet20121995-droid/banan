/* Dựng 5 sơ đồ SVG (màu cố định, nền trắng) rồi xuất PNG bằng sharp. */
const fs = require('fs');
const sharp = require('sharp');

const STYLE = `
text{font-family:Arial,sans-serif;}
.h{font-family:Arial,sans-serif;font-weight:700;fill:#2B2A22;}
.sub{fill:#6E6A60;}
.tag{fill:#6E6A60;font-weight:700;letter-spacing:1.1px;}
.box{fill:#FFFFFF;stroke:#D8D5CC;stroke-width:1.25;}
.bt{fill:#2B2A22;font-weight:700;}
.bs{fill:#6E6A60;}
.chip{fill:#FFFFFF;stroke:#E7E4DC;stroke-width:1;}
.ct{fill:#2B2A22;font-weight:600;}
.edge{stroke:#6E6A60;stroke-width:1.4;fill:none;}
.edged{stroke:#6E6A60;stroke-width:1.2;fill:none;stroke-dasharray:5 4;}
.lbl{fill:#6E6A60;}
.act{fill:#FFFFFF;stroke:#D8D5CC;stroke-width:1.25;}
.an{fill:#2B2A22;font-weight:700;}
.life{stroke:#E7E4DC;stroke-width:1.2;stroke-dasharray:3 4;}
.fwd{stroke:#6E6A60;stroke-width:1.4;fill:none;}
.ret{stroke:#6E6A60;stroke-width:1.2;fill:none;stroke-dasharray:5 4;}
.ml{fill:#2B2A22;}
.note{fill:#FFFFFF;stroke:#D8D5CC;stroke-width:1;}
.nt{fill:#6E6A60;font-style:italic;}
.ent{fill:#FFFFFF;stroke:#D8D5CC;stroke-width:1.25;}
.det{fill:#FFFFFF;stroke:#E7E4DC;stroke-width:1;stroke-dasharray:5 4;}
.en{fill:#2B2A22;font-weight:700;}
.fld{fill:#6E6A60;font-family:Consolas,monospace;}
.div{stroke:#E7E4DC;stroke-width:1;}
.rel{stroke:#6E6A60;stroke-width:1.4;fill:none;}
.reld{stroke:#6E6A60;stroke-width:1.2;fill:none;stroke-dasharray:5 4;}
.card{fill:#2B2A22;font-weight:700;}
.cap{fill:#6E6A60;}
.st{fill:#FFFFFF;stroke:#D8D5CC;stroke-width:1.4;}
.done{fill:#FFFFFF;stroke:#1E7A3E;stroke-width:1.6;}
.term{fill:#FFFFFF;stroke:#E7E4DC;stroke-width:1.2;stroke-dasharray:5 4;}
.sl{fill:#2B2A22;font-weight:700;}
.eng{fill:#FFFFFF;stroke:#D8D5CC;stroke-width:1.4;}
.step{fill:#2B2A22;font-weight:600;}
.tot{fill:#2B2A22;font-weight:700;}
.hd{fill:#6E6A60;font-weight:700;}
.rl{fill:#2B2A22;font-weight:600;}
.grid{stroke:#E7E4DC;stroke-width:1;}
.app{fill:#2B2A22;font-weight:600;}
.no{fill:#6E6A60;}
`;
const MK = (id) => `<marker id="${id}" markerWidth="9" markerHeight="9" refX="6.5" refY="3" orient="auto"><path d="M0,0 L6.5,3 L0,6 Z" fill="#6E6A60"/></marker>`;
const wrap = (w, h, marker, body) =>
  `<svg viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg"><defs>${marker}<style>${STYLE}</style></defs><rect x="0" y="0" width="${w}" height="${h}" fill="#FFFFFF"/>${body}</svg>`;

// ── 1. Kiến trúc ──
const arch = wrap(680, 652, MK('ar'), `
<text class="h" x="24" y="25" font-size="19">Banan — Sơ đồ hệ thống</text>
<text class="sub" x="24" y="44" font-size="11">Nền tảng đặt bánh kissaten · 3 app Flutter Web + API NestJS · banancakes.vn</text>
<text class="tag" x="24" y="73" font-size="10">ỨNG DỤNG — FLUTTER WEB · Riverpod · go_router · Dio</text>
<rect class="box" x="24" y="82" width="196" height="66" rx="8"/><rect x="31" y="94" width="3" height="42" rx="1.5" fill="#C9405C"/><text class="bt" x="42" y="110" font-size="13">Khách hàng</text><text class="bs" x="42" y="130" font-size="10.5">banancakes.vn</text>
<rect class="box" x="242" y="82" width="196" height="66" rx="8"/><rect x="249" y="94" width="3" height="42" rx="1.5" fill="#C9405C"/><text class="bt" x="260" y="110" font-size="13">Cửa hàng · Admin</text><text class="bs" x="260" y="130" font-size="10.5">merchant.banancakes.vn</text>
<rect class="box" x="460" y="82" width="196" height="66" rx="8"/><rect x="467" y="94" width="3" height="42" rx="1.5" fill="#C9405C"/><text class="bt" x="478" y="110" font-size="13">Bếp</text><text class="bs" x="478" y="130" font-size="10.5">kitchen.banancakes.vn</text>
<line class="edge" x1="340" y1="150" x2="340" y2="187" marker-end="url(#ar)"/><text class="lbl" x="348" y="172" font-size="10">HTTPS · JSON</text>
<rect class="box" x="24" y="190" width="632" height="46" rx="8"/><rect x="31" y="200" width="3" height="26" rx="1.5" fill="#C99A3C"/><text class="bt" x="42" y="210" font-size="12.5">Caddy 2 — Cổng vào (Edge)</text><text class="bs" x="42" y="227" font-size="10.5">Reverse proxy · HTTPS tự động (Let's Encrypt) · phục vụ web tĩnh</text>
<line class="edge" x1="259" y1="236" x2="259" y2="277" marker-end="url(#ar)"/><text class="lbl" x="267" y="260" font-size="10">REST /api/v1 · WebSocket</text>
<rect class="box" x="24" y="280" width="470" height="200" rx="8"/><rect x="31" y="292" width="3" height="176" rx="1.5" fill="#1E7A3E"/>
<text class="bt" x="42" y="302" font-size="13">NestJS 10 · REST API  /api/v1</text>
<text class="bs" x="42" y="319" font-size="10">+ Realtime Gateway (Socket.IO) · Prisma ORM · Scheduler (cron)</text>
<text class="bs" x="42" y="338" font-size="10">JWT · RBAC 6 vai trò · Envelope {data} · Throttler · Resend/FCM</text>
<g font-size="10.5">
<rect class="chip" x="42" y="350" width="138" height="24" rx="6"/><text class="ct" x="51" y="366">Auth · RBAC</text>
<rect class="chip" x="190" y="350" width="138" height="24" rx="6"/><text class="ct" x="199" y="366">Đơn hàng</text>
<rect class="chip" x="338" y="350" width="138" height="24" rx="6"/><text class="ct" x="347" y="366">Sản phẩm · Danh mục</text>
<rect class="chip" x="42" y="382" width="138" height="24" rx="6"/><text class="ct" x="51" y="398">Combo · Bộ sưu tập</text>
<rect class="chip" x="190" y="382" width="138" height="24" rx="6"/><text class="ct" x="199" y="398">Khuyến mãi</text>
<rect class="chip" x="338" y="382" width="138" height="24" rx="6"/><text class="ct" x="347" y="398">Loyalty · Micho</text>
<rect class="chip" x="42" y="414" width="138" height="24" rx="6"/><text class="ct" x="51" y="430">Coupon · Gift card</text>
<rect class="chip" x="190" y="414" width="138" height="24" rx="6"/><text class="ct" x="199" y="430">Khách hàng · CRM</text>
<rect class="chip" x="338" y="414" width="138" height="24" rx="6"/><text class="ct" x="347" y="430">Newsletter · Thông báo</text>
<rect class="chip" x="42" y="446" width="138" height="24" rx="6"/><text class="ct" x="51" y="462">Đánh giá</text>
<rect class="chip" x="190" y="446" width="138" height="24" rx="6"/><text class="ct" x="199" y="462">Báo cáo · Analytics</text>
<rect class="chip" x="338" y="446" width="138" height="24" rx="6"/><text class="ct" x="347" y="462">Uploads · Thanh toán</text>
</g>
<text class="tag" x="512" y="293" font-size="10">DỊCH VỤ NGOÀI</text>
<rect class="box" x="512" y="300" width="144" height="72" rx="8"/><rect x="519" y="312" width="3" height="48" rx="1.5" fill="#7A4FA3"/><text class="bt" x="530" y="332" font-size="12.5">Resend</text><text class="bs" x="530" y="351" font-size="10">Email + newsletter</text>
<rect class="box" x="512" y="384" width="144" height="72" rx="8"/><rect x="519" y="396" width="3" height="48" rx="1.5" fill="#7A4FA3"/><text class="bt" x="530" y="416" font-size="12.5">Firebase FCM</text><text class="bs" x="530" y="435" font-size="10">Web push -&gt; app</text>
<line class="edge" x1="494" y1="336" x2="510" y2="336" marker-end="url(#ar)"/><line class="edge" x1="494" y1="420" x2="510" y2="420" marker-end="url(#ar)"/>
<line class="edge" x1="259" y1="480" x2="259" y2="507" marker-end="url(#ar)"/><text class="lbl" x="267" y="497" font-size="10">đọc / ghi</text>
<text class="tag" x="24" y="502" font-size="10">DỮ LIỆU &amp; LƯU TRỮ</text>
<rect class="box" x="24" y="510" width="200" height="56" rx="8"/><rect x="31" y="520" width="3" height="36" rx="1.5" fill="#2A6F97"/><text class="bt" x="42" y="534" font-size="12.5">PostgreSQL 16</text><text class="bs" x="42" y="551" font-size="10">Dữ liệu · Prisma migrations</text>
<rect class="box" x="240" y="510" width="200" height="56" rx="8"/><rect x="247" y="520" width="3" height="36" rx="1.5" fill="#2A6F97"/><text class="bt" x="258" y="534" font-size="12.5">Redis 7</text><text class="bs" x="258" y="551" font-size="10">Cache · throttle · realtime</text>
<rect class="box" x="456" y="510" width="200" height="56" rx="8"/><rect x="463" y="520" width="3" height="36" rx="1.5" fill="#2A6F97"/><text class="bt" x="474" y="534" font-size="12.5">Uploads (volume)</text><text class="bs" x="474" y="551" font-size="10">Ảnh /uploads · CORS</text>
<text class="sub" x="24" y="590" font-size="9.5">Triển khai: Docker Compose trên 1 VPS (PA Vietnam, Ubuntu) — Caddy + Backend + PostgreSQL + Redis cùng mạng nội bộ.</text>
<text class="sub" x="24" y="604" font-size="9.5">Cập nhật: build Flutter web (dart-define API) -&gt; tar/scp -&gt; Caddy phục vụ tĩnh · Backend: git pull -&gt; docker build -&gt; prisma migrate deploy.</text>
<g font-size="9.5">
<rect x="24" y="623" width="11" height="11" rx="2" fill="#C9405C"/><text class="lbl" x="40" y="632">Ứng dụng</text>
<rect x="150" y="623" width="11" height="11" rx="2" fill="#C99A3C"/><text class="lbl" x="166" y="632">Edge/Proxy</text>
<rect x="290" y="623" width="11" height="11" rx="2" fill="#1E7A3E"/><text class="lbl" x="306" y="632">Backend</text>
<rect x="420" y="623" width="11" height="11" rx="2" fill="#2A6F97"/><text class="lbl" x="436" y="632">Dữ liệu</text>
<rect x="535" y="623" width="11" height="11" rx="2" fill="#7A4FA3"/><text class="lbl" x="551" y="632">Dịch vụ ngoài</text>
</g>`);

// ── 2. Luồng đặt hàng ──
const flow = wrap(680, 462, MK('a2'), `
<text class="h" x="24" y="24" font-size="18">Luồng đặt hàng</text>
<g font-size="11.5">
<rect class="act" x="12" y="36" width="116" height="32" rx="7"/><text class="an" x="70" y="56" text-anchor="middle">Khách</text>
<rect class="act" x="192" y="36" width="116" height="32" rx="7"/><text class="an" x="250" y="56" text-anchor="middle">API NestJS</text>
<rect class="act" x="372" y="36" width="116" height="32" rx="7"/><text class="an" x="430" y="56" text-anchor="middle">PostgreSQL</text>
<rect class="act" x="540" y="36" width="120" height="32" rx="7"/><text class="an" x="600" y="56" text-anchor="middle">Bếp / Cửa hàng</text>
</g>
<line class="life" x1="70" y1="68" x2="70" y2="424"/><line class="life" x1="250" y1="68" x2="250" y2="424"/><line class="life" x1="430" y1="68" x2="430" y2="424"/><line class="life" x1="600" y1="68" x2="600" y2="424"/>
<g font-size="10">
<line class="fwd" x1="70" y1="98" x2="250" y2="98" marker-end="url(#a2)"/><text class="ml" x="78" y="92">GET /products · duyệt menu</text>
<line class="fwd" x1="250" y1="126" x2="430" y2="126" marker-end="url(#a2)"/><text class="ml" x="258" y="120">truy vấn catalog</text>
<line class="ret" x1="430" y1="154" x2="250" y2="154" marker-end="url(#a2)"/><text class="ml" x="258" y="148">danh sách món</text>
<rect class="note" x="78" y="172" width="168" height="20" rx="5"/><text class="nt" x="86" y="186">Thêm giỏ · chọn lịch (lead-time)</text>
<line class="fwd" x1="70" y1="214" x2="250" y2="214" marker-end="url(#a2)"/><text class="ml" x="78" y="208">POST /orders {coupon·điểm·giftcard}</text>
<rect class="note" x="258" y="232" width="170" height="20" rx="5"/><text class="nt" x="266" y="246">Promotions.evaluate -&gt; giá cuối</text>
<line class="fwd" x1="250" y1="274" x2="430" y2="274" marker-end="url(#a2)"/><text class="ml" x="258" y="268">tạo Order + giảm tồn (transaction)</text>
<line class="ret" x1="430" y1="302" x2="250" y2="302" marker-end="url(#a2)"/><text class="ml" x="360" y="296">OK</text>
<line class="fwd" x1="250" y1="330" x2="600" y2="330" marker-end="url(#a2)"/><text class="ml" x="258" y="324">WebSocket + FCM đơn mới</text>
<line class="ret" x1="250" y1="358" x2="70" y2="358" marker-end="url(#a2)"/><text class="ml" x="78" y="352">201 · mã đơn · email (Resend)</text>
<line class="fwd" x1="600" y1="386" x2="250" y2="386" marker-end="url(#a2)"/><text class="ml" x="300" y="380">PATCH trạng thái (đang làm -&gt; sẵn sàng)</text>
<line class="fwd" x1="250" y1="414" x2="70" y2="414" marker-end="url(#a2)"/><text class="ml" x="78" y="408">WebSocket · đơn cập nhật</text>
</g>
<text class="sub" x="24" y="446" font-size="9.5">Nét liền = yêu cầu/sự kiện · nét đứt = phản hồi.  Realtime qua Socket.IO · email qua Resend · push qua Firebase FCM.</text>`);

// ── 3. Phân quyền ──
const rbac = wrap(680, 326, '', `
<text class="h" x="24" y="24" font-size="18">Phân quyền — 6 vai trò</text>
<g class="hd" font-size="9.5" text-anchor="middle">
<text x="193" y="62">App</text><text x="271" y="62">Đơn hàng</text><text x="349" y="62">Thực đơn</text><text x="432" y="62">Khách/CRM</text><text x="520" y="62">Marketing</text><text x="610" y="62">Cấu hình</text>
</g>
<g class="grid">
<line x1="24" y1="68" x2="656" y2="68"/><line x1="24" y1="104" x2="656" y2="104"/><line x1="24" y1="140" x2="656" y2="140"/><line x1="24" y1="176" x2="656" y2="176"/><line x1="24" y1="212" x2="656" y2="212"/><line x1="24" y1="248" x2="656" y2="248"/><line x1="24" y1="284" x2="656" y2="284"/>
<line x1="154" y1="68" x2="154" y2="284"/><line x1="232" y1="68" x2="232" y2="284"/><line x1="310" y1="68" x2="310" y2="284"/><line x1="388" y1="68" x2="388" y2="284"/><line x1="476" y1="68" x2="476" y2="284"/><line x1="564" y1="68" x2="564" y2="284"/>
</g>
<g class="rl" font-size="11">
<text x="30" y="90">Admin</text><text x="30" y="126">Chủ cửa hàng</text><text x="30" y="162">NV cửa hàng</text><text x="30" y="198">Quản lý bếp</text><text x="30" y="234">NV bếp</text><text x="30" y="270">Khách hàng</text>
</g>
<g font-size="13" text-anchor="middle" font-weight="700">
<g class="app" font-size="10">
<text x="193" y="90">Quản trị</text><text x="193" y="126">Quản trị</text><text x="193" y="162">Quản trị</text><text x="193" y="198">Bếp</text><text x="193" y="234">Bếp</text><text x="193" y="270">Khách</text>
</g>
<text x="271" y="90" fill="#1E7A3E">✓</text><text x="349" y="90" fill="#1E7A3E">✓</text><text x="432" y="90" fill="#1E7A3E">✓</text><text x="520" y="90" fill="#1E7A3E">✓</text><text x="610" y="90" fill="#1E7A3E">✓</text>
<text x="271" y="126" fill="#C99A3C">◐</text><text x="349" y="126" fill="#1E7A3E">✓</text><text x="432" y="126" fill="#1E7A3E">✓</text><text x="520" y="126" fill="#1E7A3E">✓</text><text x="610" y="126" fill="#C99A3C">◐</text>
<text x="271" y="162" fill="#C99A3C">◐</text><text x="349" y="162" fill="#C99A3C">◐</text><text x="432" y="162" fill="#C99A3C">◐</text><text class="no" x="520" y="160">—</text><text class="no" x="610" y="160">—</text>
<text x="271" y="198" fill="#C99A3C">◐</text><text class="no" x="349" y="196">—</text><text class="no" x="432" y="196">—</text><text class="no" x="520" y="196">—</text><text x="610" y="198" fill="#C99A3C">◐</text>
<text x="271" y="234" fill="#C99A3C">◐</text><text class="no" x="349" y="232">—</text><text class="no" x="432" y="232">—</text><text class="no" x="520" y="232">—</text><text class="no" x="610" y="232">—</text>
<text x="271" y="270" fill="#C99A3C">◐</text><text class="no" x="349" y="268">—</text><text class="no" x="432" y="268">—</text><text class="no" x="520" y="268">—</text><text class="no" x="610" y="268">—</text>
</g>
<text class="sub" x="24" y="304" font-size="9.5">✓ đầy đủ · ◐ giới hạn (1 cửa hàng / đơn của mình) · — không.  Admin = toàn chuỗi; cửa hàng &amp; bếp giới hạn theo phạm vi.</text>`);

// ── 4. Engine khuyến mãi ──
const promo = wrap(680, 452, MK('a3'), `
<text class="h" x="24" y="24" font-size="18">Engine khuyến mãi</text>
<rect class="box" x="170" y="44" width="340" height="42" rx="8"/><text class="bt" x="340" y="62" font-size="12" text-anchor="middle">Giỏ hàng</text><text class="bs" x="340" y="78" font-size="10" text-anchor="middle">các dòng món · tạm tính · hồ sơ khách</text>
<line class="edge" x1="340" y1="86" x2="340" y2="106" marker-end="url(#a3)"/>
<rect class="eng" x="60" y="108" width="560" height="170" rx="10"/><rect x="68" y="120" width="3" height="146" rx="1.5" fill="#1E7A3E"/>
<text class="bt" x="80" y="130" font-size="12.5">PromotionsService.evaluate()</text>
<text class="bs" x="80" y="146" font-size="9.5">Quét các chiến dịch đang chạy -&gt; chọn mức giảm tốt nhất (không cộng dồn trên cùng 1 món)</text>
<rect class="box" x="80" y="156" width="520" height="32" rx="6"/><text class="step" x="92" y="170" font-size="10.5">① Mỗi DÒNG -&gt; 1 KM tốt nhất</text><text class="bs" x="92" y="183" font-size="9">PRODUCT_DISCOUNT · CATEGORY_DISCOUNT · FLASH_SALE · HAPPY_HOUR</text>
<rect class="box" x="80" y="192" width="520" height="32" rx="6"/><text class="step" x="92" y="206" font-size="10.5">② Cả GIỎ</text><text class="bs" x="92" y="219" font-size="9">BUY_X_GET_Y (mua X tặng Y)</text>
<rect class="box" x="80" y="228" width="520" height="42" rx="6"/><text class="step" x="92" y="242" font-size="10.5">③ Theo KHÁCH -&gt; 1 KM tốt nhất</text><text class="bs" x="92" y="255" font-size="9">FIRST_ORDER · BIRTHDAY · REACTIVATION · MEMBERSHIP_BENEFIT</text><text class="bs" x="92" y="266" font-size="9">(đơn đầu · sinh nhật · khách quay lại · ưu đãi hạng thành viên)</text>
<line class="edge" x1="340" y1="278" x2="340" y2="302" marker-end="url(#a3)"/><text class="lbl" x="348" y="294" font-size="10">= campaignDiscount  (+ lưu vết campaignInfo)</text>
<rect class="box" x="100" y="304" width="480" height="46" rx="8"/><rect x="108" y="314" width="3" height="28" rx="1.5" fill="#C99A3C"/><text class="bt" x="120" y="322" font-size="11">OrdersService cộng tiếp &amp; chốt</text><text class="bs" x="120" y="340" font-size="10">+ Coupon (mã)  -&gt;  + Điểm Micho  -&gt;  + Gift card   ·   cắt ≤ tạm tính</text>
<line class="edge" x1="340" y1="350" x2="340" y2="372" marker-end="url(#a3)"/>
<rect class="box" x="240" y="374" width="200" height="44" rx="8"/><rect x="248" y="384" width="3" height="24" rx="1.5" fill="#C9405C"/><text class="tot" x="345" y="392" font-size="12.5" text-anchor="middle">Tổng tiền cuối</text><text class="bs" x="345" y="408" font-size="9.5" text-anchor="middle">backend chốt — app không tự tính</text>
<text class="sub" x="24" y="440" font-size="9.5">Mỗi món chỉ nhận 1 khuyến mãi tốt nhất; các lớp coupon / điểm / gift card cộng tuần tự và không vượt quá tạm tính.</text>`);

// ── 5. Vòng đời trạng thái đơn ──
const status = wrap(680, 372, MK('a4'), `
<text class="h" x="24" y="24" font-size="18">Vòng đời trạng thái đơn</text>
<g font-size="10" text-anchor="middle">
<rect class="st" x="24" y="58" width="130" height="36" rx="8"/><text class="sl" x="89" y="80">PENDING</text>
<rect class="st" x="190" y="58" width="130" height="36" rx="8"/><text class="sl" x="255" y="80">ACCEPTED</text>
<rect class="st" x="356" y="58" width="140" height="36" rx="8"/><text class="sl" x="426" y="80">IN_PREPARATION</text>
<rect class="st" x="520" y="58" width="136" height="36" rx="8"/><text class="sl" x="588" y="76">SENT_TO</text><text class="sl" x="588" y="88">_KITCHEN</text>
</g>
<line class="edge" x1="154" y1="76" x2="188" y2="76" marker-end="url(#a4)"/><line class="edge" x1="320" y1="76" x2="354" y2="76" marker-end="url(#a4)"/><line class="edge" x1="496" y1="76" x2="518" y2="76" marker-end="url(#a4)"/>
<text class="nt" x="520" y="112" font-size="9">Bếp: PENDING_ACK -&gt; PREPARING -&gt; READY_DISPATCH</text>
<path class="edge" d="M588,94 L588,126 L89,126 L89,150" marker-end="url(#a4)"/>
<g font-size="10" text-anchor="middle">
<rect class="st" x="24" y="152" width="150" height="36" rx="8"/><text class="sl" x="99" y="170">READY_FOR</text><text class="sl" x="99" y="182">_PICKUP</text>
<rect class="st" x="266" y="152" width="130" height="36" rx="8"/><text class="sl" x="331" y="174">DELIVERING</text>
<rect class="done" x="486" y="152" width="150" height="36" rx="8"/><text class="sl" x="561" y="174">COMPLETED</text>
</g>
<line class="edge" x1="174" y1="170" x2="264" y2="170" marker-end="url(#a4)"/><text class="lbl" x="180" y="164" font-size="9">giao hàng</text>
<line class="edge" x1="396" y1="170" x2="484" y2="170" marker-end="url(#a4)"/>
<path class="edge" d="M99,152 L99,134 L561,134 L561,150" marker-end="url(#a4)"/><text class="lbl" x="300" y="129" font-size="9">nhận tại quầy</text>
<rect class="term" x="24" y="252" width="150" height="34" rx="8"/><text class="sl" x="99" y="273" font-size="10" text-anchor="middle">CANCELLED</text>
<rect class="term" x="486" y="252" width="150" height="34" rx="8"/><text class="sl" x="561" y="273" font-size="10" text-anchor="middle">REFUNDED</text>
<path class="edged" d="M255,94 L255,230 L99,230 L99,250" marker-end="url(#a4)"/><text class="lbl" x="150" y="224" font-size="9">huỷ khi PENDING / ACCEPTED</text>
<line class="edged" x1="561" y1="188" x2="561" y2="250" marker-end="url(#a4)"/><text class="lbl" x="568" y="224" font-size="9">hoàn tiền</text>
<text class="sub" x="24" y="316" font-size="9.5">Viền xanh = kết thúc thành công · nét đứt = nhánh huỷ/hoàn.</text>
<text class="sub" x="24" y="332" font-size="9.5">SENT_TO_KITCHEN chỉ xuất hiện với đơn cần bếp trung tâm; đơn làm tại quầy đi thẳng IN_PREPARATION -&gt; READY_FOR_PICKUP.</text>`);

const set = [
  ['arch', arch, 1400],
  ['flow', flow, 1400],
  ['rbac', rbac, 1400],
  ['promo', promo, 1400],
  ['status', status, 1400],
];
fs.mkdirSync('diagrams', { recursive: true });
(async () => {
  for (const [name, svg, w] of set) {
    fs.writeFileSync(`diagrams/${name}.svg`, svg);
    await sharp(Buffer.from(svg)).resize({ width: w }).png().toFile(`diagrams/${name}.png`);
    const m = await sharp(`diagrams/${name}.png`).metadata();
    console.log(`✓ ${name}.png  ${m.width}x${m.height}`);
  }
})();
