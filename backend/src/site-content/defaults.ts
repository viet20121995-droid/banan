/**
 * Built-in defaults for merchant-editable pages. Served when no DB row
 * exists yet, and used as the starting point in the merchant editor.
 * Mirrors the original hardcoded customer-app content.
 */

export const SITE_CONTENT_KEYS = ['faq', 'about'] as const;
export type SiteContentKey = (typeof SITE_CONTENT_KEYS)[number];

export interface FaqData {
  items: Array<{ q: string; a: string }>;
}

export interface AboutData {
  intro: string;
  sections: Array<{ heading: string; body: string }>;
}

export const DEFAULT_FAQ: FaqData = {
  items: [
    {
      q: 'Tôi đặt bánh sinh nhật trước bao lâu?',
      a: 'Bánh sinh nhật và các set theo yêu cầu cần đặt trước theo thời gian chuẩn bị hiển thị trên trang sản phẩm (thường 1–2 ngày). Bạn chọn ngày/giờ nhận ở bước thanh toán.',
    },
    {
      q: 'Tôi có thể ghi chữ lên bánh và chọn số nến không?',
      a: 'Có. Với bánh thuộc bộ sưu tập sinh nhật, bấm dấu "+" hoặc mở trang sản phẩm để cá nhân hoá: chữ trên bánh, số nến và ghi chú cho thợ bánh. Bạn cũng sửa được ngay trong giỏ hàng.',
    },
    {
      q: 'Phí giao hàng tính thế nào?',
      a: 'Phí giao được tính theo phường/xã của địa chỉ nhận tại bước thanh toán. Đơn lấy tại cửa hàng (pickup) không mất phí giao.',
    },
    {
      q: 'Tôi có thể thanh toán bằng cách nào?',
      a: 'Đơn lấy tại cửa hàng có thể thanh toán khi nhận (tiền mặt). Đơn giao tận nơi thanh toán qua cổng điện tử. Hoá đơn VAT được xuất khi bạn cung cấp đủ thông tin doanh nghiệp.',
    },
    {
      q: 'Tôi muốn huỷ đơn thì làm sao?',
      a: 'Vào "Đơn hàng của tôi", mở đơn và bấm Huỷ khi đơn còn ở trạng thái "Chờ xác nhận" hoặc "Đã nhận". Sau khi bếp bắt đầu chuẩn bị, đơn có thể không huỷ được.',
    },
    {
      q: 'Banan có tích điểm / ưu đãi thành viên không?',
      a: 'Có. Mỗi đơn hoàn tất sẽ tích điểm Micho; bạn dùng điểm để giảm giá đơn sau và nhận ưu đãi sinh nhật. Xem mục Thành viên.',
    },
    {
      q: 'Làm sao để nhận tin khuyến mãi?',
      a: 'Đăng ký nhận bản tin ở cuối trang chủ bằng email. Chúng tôi gửi email xác nhận trước khi thêm bạn vào danh sách (double opt-in).',
    },
  ],
};

export const DEFAULT_ABOUT: AboutData = {
  intro:
    'Banan Fukuoka Saigon mang tinh thần kissaten Nhật Bản đến Sài Gòn — ' +
    'nơi mỗi chiếc bánh được làm thủ công, tươi mỗi ngày, để bạn dừng lại ' +
    'và tận hưởng một khoảnh khắc ngọt ngào.',
  sections: [
    {
      heading: 'Câu chuyện của chúng tôi',
      body:
        'Bắt đầu từ tình yêu với những tiệm cà phê – bánh ngọt nhỏ ở ' +
        'Fukuoka, Banan ra đời để mang hương vị tinh tế ấy về Việt Nam, ' +
        'pha trộn cùng nguyên liệu địa phương tươi ngon.\n\n' +
        'Từ basque cheesecake, mochi, daifuku đến macaron và bánh sinh nhật ' +
        'đặt riêng — mỗi sản phẩm là sự cân bằng giữa kỹ thuật Nhật và khẩu ' +
        'vị người Việt.',
    },
    {
      heading: 'Cam kết của Banan',
      body:
        'Làm tươi mỗi ngày tại bếp trung tâm, không dùng chất bảo quản ' +
        'không cần thiết.\n\nMinh bạch về thành phần và nguồn nguyên liệu.\n\n' +
        'Phục vụ tận tâm — từ đặt online đến nhận tại quầy hay giao tận nơi.',
    },
    {
      heading: 'Hệ thống chi nhánh',
      body:
        'Banan hiện có nhiều chi nhánh tại TP.HCM, phục vụ cả nhận tại quầy ' +
        'và giao hàng. Xem địa chỉ, giờ mở cửa và số điện thoại từng chi ' +
        'nhánh ở trang Chi nhánh.',
    },
  ],
};

export function defaultFor(key: SiteContentKey): FaqData | AboutData {
  return key === 'faq' ? DEFAULT_FAQ : DEFAULT_ABOUT;
}
