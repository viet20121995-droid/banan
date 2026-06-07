// Long-form policy copy is written as multi-line implicit string
// concatenation inside the section lists — deliberate, not a missing comma.
// ignore_for_file: no_adjacent_strings_in_list
import 'package:flutter/material.dart';

import 'content_page.dart';

/// Chính sách vận chuyển & giao nhận. Nội dung mẫu cho cửa hàng bánh,
/// hiển thị công khai (yêu cầu của Bộ Công Thương). Cần rà soát trước khi
/// phát hành chính thức.
class ShippingPolicyScreen extends StatelessWidget {
  const ShippingPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentPage(
      title: 'Chính sách vận chuyển & giao nhận',
      updatedLabel: 'Cập nhật lần cuối: 06/2026',
      intro:
          'Banan Fukuoka Saigon giao bánh tươi mỗi ngày từ các chi nhánh tại '
          'TP.HCM. Trang này mô tả phạm vi, thời gian, phí giao hàng và cách '
          'kiểm tra sản phẩm khi nhận.',
      sections: [
        ContentSection('1. Phạm vi & hình thức giao nhận', [
          'Chúng tôi giao hàng nội thành TP.HCM từ các chi nhánh của Banan '
              'Fukuoka Saigon.',
          'Bạn cũng có thể chọn nhận tại quầy (miễn phí) tại chi nhánh đã chọn '
              'khi đặt hàng.',
        ]),
        ContentSection('2. Thời gian giao hàng', [
          'Đơn được giao theo khung giờ bạn chọn lúc đặt — giao ngay hoặc đặt '
              'lịch trước.',
          'Bánh sinh nhật và đơn theo yêu cầu cần đặt trước theo thời gian '
              'chuẩn bị của sản phẩm.',
          'Thời gian giao là ước tính và có thể thay đổi do thời tiết, giao '
              'thông hoặc lượng đơn trong ngày.',
        ]),
        ContentSection('3. Phí giao hàng', [
          'Phí giao hàng được tính theo địa chỉ nhận (phường/xã) và hiển thị '
              'rõ ở bước thanh toán trước khi bạn đặt đơn.',
        ]),
        ContentSection('4. Kiểm tra khi nhận hàng', [
          'Vui lòng kiểm tra sản phẩm ngay khi nhận. Nếu giao sai sản phẩm '
              'hoặc sản phẩm bị hư hỏng, hãy báo ngay cho shop hoặc nhân viên '
              'giao hàng (shipper) để được xử lý.',
        ]),
        ContentSection('5. Bảo quản sau khi nhận', [
          'Bánh tươi nên được bảo quản lạnh và sử dụng theo hướng dẫn ngay sau '
              'khi nhận để đảm bảo chất lượng và an toàn thực phẩm.',
        ]),
      ],
    );
  }
}

/// Chính sách thanh toán. Nội dung mẫu, cần rà soát trước khi phát hành.
class PaymentPolicyScreen extends StatelessWidget {
  const PaymentPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentPage(
      title: 'Chính sách thanh toán',
      updatedLabel: 'Cập nhật lần cuối: 06/2026',
      intro:
          'Trang này mô tả các phương thức thanh toán, đơn vị tiền tệ, hoá đơn '
          'VAT và cách chúng tôi bảo mật giao dịch của bạn.',
      sections: [
        ContentSection('1. Phương thức thanh toán', [
          'Tiền mặt khi nhận hàng (COD) áp dụng cho cả đơn giao hàng và đơn '
              'lấy tại quầy.',
          'Ghi chú: thanh toán online qua VNPay / thẻ — sắp ra mắt.',
        ]),
        ContentSection('2. Đơn vị tiền tệ & giá', [
          'Toàn bộ giao dịch sử dụng đơn vị tiền tệ là VND.',
          'Giá hiển thị đã bao gồm thuế nếu áp dụng; phí giao hàng được tính '
              'riêng ở bước thanh toán.',
        ]),
        ContentSection('3. Hoá đơn VAT', [
          'Chúng tôi xuất hoá đơn VAT khi bạn cung cấp đầy đủ thông tin doanh '
              'nghiệp (tên, mã số thuế, địa chỉ, email) tại thời điểm đặt hàng.',
        ]),
        ContentSection('4. Bảo mật thanh toán', [
          'Chúng tôi không lưu thông tin thẻ của bạn trên hệ thống.',
          'Các giao dịch online được xử lý qua cổng thanh toán đạt chuẩn an '
              'toàn.',
        ]),
        ContentSection('5. Mã giảm giá, điểm thưởng & thẻ quà tặng', [
          'Mã giảm giá, điểm thưởng và thẻ quà tặng được áp dụng ở bước thanh '
              'toán.',
        ]),
      ],
    );
  }
}

/// Chính sách đổi trả & hoàn tiền. Nội dung mẫu, cần rà soát trước khi
/// phát hành.
class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentPage(
      title: 'Chính sách đổi trả & hoàn tiền',
      updatedLabel: 'Cập nhật lần cuối: 06/2026',
      intro:
          'Vì sản phẩm của chúng tôi là thực phẩm tươi, chính sách đổi trả & '
          'hoàn tiền được áp dụng có điều kiện. Vui lòng đọc kỹ các quy định '
          'dưới đây.',
      sections: [
        ContentSection('1. Nguyên tắc chung', [
          'Vì là thực phẩm tươi, chúng tôi chỉ đổi hoặc hoàn tiền khi lỗi do '
              'shop — chẳng hạn giao sai sản phẩm, hoặc sản phẩm bị hư hỏng / '
              'không đạt chất lượng khi nhận.',
        ]),
        ContentSection('2. Điều kiện & thời hạn', [
          'Vui lòng báo cho chúng tôi trong vòng 2 giờ kể từ khi nhận hàng, '
              'kèm hình ảnh sản phẩm.',
          'Sản phẩm chưa được sử dụng (trừ trường hợp lỗi rõ ràng có thể nhận '
              'biết ngay).',
        ]),
        ContentSection('3. Huỷ đơn', [
          'Bạn có thể huỷ đơn khi đơn còn ở trạng thái "Chờ xác nhận" hoặc '
              '"Đã nhận".',
          'Sau khi bếp bắt đầu chuẩn bị, đơn có thể không huỷ được.',
        ]),
        ContentSection('4. Hình thức hoàn', [
          'Đổi sang sản phẩm khác tương đương, hoặc hoàn tiền về phương thức '
              'thanh toán ban đầu.',
          'Đơn COD: hoàn tiền mặt hoặc chuyển khoản. Đơn online: hoàn về cổng '
              'thanh toán theo thời gian xử lý của đơn vị.',
        ]),
        ContentSection('5. Liên hệ hỗ trợ', [
          'Vui lòng liên hệ qua trang Liên hệ hoặc hotline của chúng tôi để '
              'được hỗ trợ đổi trả / hoàn tiền.',
        ]),
      ],
    );
  }
}
