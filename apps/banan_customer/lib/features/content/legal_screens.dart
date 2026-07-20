// Long-form legal copy is written as multi-line implicit string
// concatenation inside the section lists — deliberate, not a missing comma.
// ignore_for_file: no_adjacent_strings_in_list
import 'package:flutter/material.dart';

import 'content_page.dart';

/// Chính sách bảo mật — soạn theo tinh thần Nghị định 13/2023/NĐ-CP về
/// bảo vệ dữ liệu cá nhân. Nội dung mẫu, cần luật sư rà soát trước khi
/// phát hành chính thức ra công chúng.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentPage(
      title: 'Chính sách bảo mật',
      updatedLabel: 'Cập nhật lần cuối: 06/2026',
      intro:
          'Banan Fukuoka Saigon ("chúng tôi") tôn trọng và cam kết bảo vệ '
          'dữ liệu cá nhân của bạn theo Nghị định 13/2023/NĐ-CP và pháp luật '
          'Việt Nam hiện hành. Chính sách này giải thích chúng tôi thu thập, '
          'sử dụng và bảo vệ thông tin của bạn như thế nào.',
      sections: [
        ContentSection('1. Dữ liệu chúng tôi thu thập', [
          'Thông tin định danh: họ tên, số điện thoại, email, ngày sinh '
              '(khi bạn cung cấp để nhận ưu đãi sinh nhật).',
          'Thông tin giao hàng: địa chỉ nhận hàng, phường/xã, ghi chú giao hàng.',
          'Thông tin đơn hàng: sản phẩm, tuỳ chỉnh bánh, lịch sử mua, điểm '
              'tích luỹ và mã giảm giá đã dùng.',
          'Dữ liệu kỹ thuật: thiết bị, trình duyệt, địa chỉ IP và cookie '
              'cần thiết để vận hành website.',
        ]),
        ContentSection('2. Mục đích sử dụng', [
          'Xử lý và giao đơn hàng, hỗ trợ khách hàng, xuất hoá đơn VAT khi '
              'được yêu cầu.',
          'Quản lý chương trình tích điểm, ưu đãi sinh nhật và khuyến mãi mà '
              'bạn đã đồng ý nhận.',
          'Cải thiện sản phẩm, dịch vụ và trải nghiệm trên website.',
          'Tuân thủ nghĩa vụ pháp lý về thuế, kế toán và an toàn thực phẩm.',
        ]),
        ContentSection('3. Cơ sở pháp lý & sự đồng ý', [
          'Chúng tôi chỉ xử lý dữ liệu khi bạn đồng ý, hoặc khi cần thiết để '
              'thực hiện hợp đồng (đơn hàng của bạn), hoặc theo yêu cầu của '
              'pháp luật.',
          'Bạn có thể rút lại sự đồng ý bất kỳ lúc nào. Việc này không ảnh '
              'hưởng đến các xử lý đã thực hiện trước đó.',
        ]),
        ContentSection('4. Chia sẻ dữ liệu', [
          'Chúng tôi không bán dữ liệu cá nhân của bạn.',
          'Chúng tôi chỉ chia sẻ với: đối tác giao hàng (để giao đơn), cổng '
              'thanh toán (để xử lý giao dịch) và cơ quan nhà nước khi có yêu '
              'cầu hợp pháp.',
        ]),
        ContentSection('5. Lưu trữ & bảo mật', [
          'Dữ liệu được lưu trên hạ tầng có kiểm soát truy cập, mã hoá kết nối '
              '(HTTPS) và sao lưu định kỳ.',
          'Chúng tôi lưu dữ liệu đơn hàng theo thời hạn luật kế toán/thuế yêu '
              'cầu; dữ liệu marketing được lưu đến khi bạn huỷ đăng ký.',
        ]),
        ContentSection('6. Quyền của bạn', [
          'Bạn có quyền được biết, truy cập, chỉnh sửa, xoá, hạn chế xử lý, '
              'rút lại đồng ý và khiếu nại về dữ liệu cá nhân của mình.',
          'Để thực hiện các quyền này, vui lòng liên hệ qua trang Liên hệ '
              'hoặc hotline của chúng tôi.',
        ]),
        ContentSection('7. Cookie', [
          'Chúng tôi dùng cookie cần thiết để đăng nhập và giỏ hàng hoạt động. '
              'Cookie phân tích/không thiết yếu chỉ được bật khi bạn đồng ý '
              'trên thanh thông báo cookie.',
        ]),
        ContentSection('8. Liên hệ', [
          'Mọi yêu cầu liên quan đến dữ liệu cá nhân, vui lòng gửi qua trang '
              'Liên hệ. Chúng tôi phản hồi trong thời gian sớm nhất.',
        ]),
      ],
    );
  }
}

/// Điều khoản sử dụng / điều kiện đặt hàng.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentPage(
      title: 'Điều khoản sử dụng',
      updatedLabel: 'Cập nhật lần cuối: 06/2026',
      intro:
          'Khi đặt hàng trên Banan Fukuoka Saigon, bạn đồng ý với các điều '
          'khoản dưới đây. Vui lòng đọc kỹ trước khi sử dụng dịch vụ.',
      sections: [
        ContentSection('1. Đặt hàng', [
          'Đơn hàng được xác nhận sau khi bạn hoàn tất bước thanh toán hoặc '
              'chọn thanh toán khi nhận. Một số sản phẩm (bánh sinh nhật, set '
              'theo yêu cầu) cần đặt trước theo thời gian chuẩn bị.',
          'Chúng tôi có quyền từ chối hoặc huỷ đơn nếu sản phẩm hết hàng, '
              'thông tin không hợp lệ hoặc nghi ngờ gian lận.',
        ]),
        ContentSection('2. Giá & thanh toán', [
          'Giá hiển thị bằng VND, đã gồm thuế nếu áp dụng. Phí giao hàng được '
              'tính theo địa chỉ tại bước thanh toán.',
          'Chúng tôi hỗ trợ thanh toán khi nhận (đơn lấy tại cửa hàng) và các '
              'cổng thanh toán điện tử. Hoá đơn VAT được xuất khi bạn cung cấp '
              'đủ thông tin doanh nghiệp.',
        ]),
        ContentSection('3. Huỷ đơn & hoàn tiền', [
          'Bạn có thể huỷ đơn khi đơn còn ở trạng thái "Chờ xác nhận" hoặc '
              '"Đã nhận". Sau khi bếp bắt đầu chuẩn bị, việc huỷ có thể không '
              'được chấp nhận.',
          'Với đơn đã thanh toán online, tiền hoàn sẽ được xử lý về phương '
              'thức ban đầu theo thời gian của đơn vị thanh toán.',
        ]),
        ContentSection('4. Giao hàng & nhận tại quầy', [
          'Thời gian giao là ước tính, có thể thay đổi theo thời tiết, giao '
              'thông và lượng đơn. Vui lòng cung cấp địa chỉ và số điện thoại '
              'chính xác.',
          'Sản phẩm bánh tươi nên được bảo quản và dùng theo hướng dẫn ngay '
              'sau khi nhận.',
        ]),
        ContentSection('5. Sở hữu trí tuệ', [
          'Toàn bộ thương hiệu, hình ảnh, công thức và nội dung trên website '
              'thuộc về Banan Fukuoka Saigon. Không sao chép khi chưa có sự '
              'đồng ý bằng văn bản.',
        ]),
        ContentSection('6. Giới hạn trách nhiệm', [
          'Chúng tôi không chịu trách nhiệm với thiệt hại gián tiếp phát sinh '
              'ngoài tầm kiểm soát hợp lý. Trách nhiệm tối đa của chúng tôi '
              'giới hạn ở giá trị đơn hàng liên quan.',
        ]),
        ContentSection('7. Luật áp dụng', [
          'Các điều khoản này được điều chỉnh theo pháp luật Việt Nam. Tranh '
              'chấp được giải quyết tại toà án có thẩm quyền tại TP.HCM.',
        ]),
      ],
    );
  }
}
