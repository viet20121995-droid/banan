/// Thông tin chủ sở hữu website / đơn vị vận hành.
///
/// Đây là phần "Thông tin người sở hữu website" mà Bộ Công Thương
/// (online.gov.vn) yêu cầu hiển thị công khai. Các giá trị dưới đây là
/// PLACEHOLDER — vui lòng thay bằng thông tin thật từ Giấy chứng nhận
/// đăng ký kinh doanh (ĐKKD) / đăng ký hộ kinh doanh của bạn.
class LegalInfo {
  const LegalInfo._();

  // TODO(owner): điền tên doanh nghiệp / hộ kinh doanh theo ĐKKD.
  static const businessName = '[TÊN DOANH NGHIỆP / HỘ KINH DOANH]';

  // TODO(owner): điền mã số thuế.
  static const taxCode = '[MÃ SỐ THUẾ]';

  // TODO(owner): điền số ĐKKD + ngày cấp + nơi cấp.
  static const bizRegNo = '[SỐ ĐKKD] (cấp ngày … tại …)';

  // TODO(owner): điền địa chỉ đăng ký kinh doanh.
  static const address = '[ĐỊA CHỈ ĐĂNG KÝ KINH DOANH]';

  // TODO(owner): điền số hotline.
  static const hotline = '[HOTLINE]';

  static const email = 'ai@vesta-group.org';
}
