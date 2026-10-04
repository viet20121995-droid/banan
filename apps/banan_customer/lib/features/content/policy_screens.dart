// Long-form policy copy is written as multi-line implicit string
// concatenation inside the section lists — deliberate, not a missing comma.
// Japanese copy has no spaces between words, so adjacent JA strings join
// without whitespace on purpose.
// ignore_for_file: no_adjacent_strings_in_list
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_page.dart';

/// Chính sách vận chuyển & giao nhận. Nội dung mẫu cho cửa hàng bánh,
/// hiển thị công khai (yêu cầu của Bộ Công Thương). Bản EN/JA là bản dịch
/// tham khảo; bản VI có giá trị pháp lý.
class ShippingPolicyScreen extends ConsumerWidget {
  const ShippingPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (ref.watch(localeProvider)) {
      case AppLocale.en:
        return const ContentPage(
          title: 'Shipping & delivery policy',
          updatedLabel: 'Last updated: 06/2026',
          intro: 'Banan Fukuoka Saigon delivers fresh cakes daily from our '
              'stores in Ho Chi Minh City. This page describes coverage, '
              'timing, delivery fees and how to check your order on receipt.',
          sections: [
            ContentSection('1. Coverage & fulfilment options', [
              'We deliver within Ho Chi Minh City from Banan Fukuoka Saigon '
                  'stores.',
              'You can also pick up at the counter (free) at the store you '
                  'chose when ordering.',
            ]),
            ContentSection('2. Delivery times', [
              'Orders are delivered in the window you chose at checkout: '
                  'as soon as possible, or scheduled ahead.',
              'Birthday cakes and custom orders must be ordered ahead per '
                  "the product's preparation time.",
              'Delivery times are estimates and may vary with weather, '
                  'traffic or daily order volume.',
            ]),
            ContentSection('3. Delivery fees', [
              'The delivery fee is calculated from the delivery address '
                  '(ward) and shown clearly at checkout before you place '
                  'the order.',
            ]),
            ContentSection('4. Checking on receipt', [
              'Please check your order right away. If the wrong item was '
                  'delivered or a product is damaged, tell the shop or the '
                  'delivery rider immediately so we can resolve it.',
            ]),
            ContentSection('5. Storage after receipt', [
              'Fresh cakes should be refrigerated and consumed per the '
                  'instructions right after receipt for quality and food '
                  'safety.',
            ]),
          ],
        );
      case AppLocale.ja:
        return const ContentPage(
          title: '配送・お受け取りポリシー',
          updatedLabel: '最終更新日：2026年6月',
          intro: 'Banan Fukuoka Saigonは、ホーチミン市内の店舗から毎日新鮮な'
              'ケーキをお届けしています。このページでは、配送エリア、お届け時間、'
              '配送料、お受け取り時の確認方法についてご説明します。',
          sections: [
            ContentSection('1. 配送エリアとお受け取り方法', [
              'Banan Fukuoka Saigonの店舗から、ホーチミン市内へお届けします。',
              'ご注文時に選択した店舗の店頭で、お受け取り（無料）いただくことも'
                  'できます。',
            ]),
            ContentSection('2. お届け時間', [
              'ご注文は、お会計時に選択された時間帯（できるだけ早く、または'
                  '事前予約）にお届けします。',
              'バースデーケーキやオーダーメイドのご注文は、商品の準備期間に'
                  '合わせて事前にご注文ください。',
              'お届け時間は目安であり、天候、交通状況、その日の注文数により'
                  '前後する場合があります。',
            ]),
            ContentSection('3. 配送料', [
              '配送料はお届け先住所（坊・社）に応じて計算され、ご注文の確定前に'
                  'お会計画面で明示されます。',
            ]),
            ContentSection('4. お受け取り時の確認', [
              'お受け取り後すぐに商品をご確認ください。商品の間違いや破損が'
                  'あった場合は、対応のため、ただちに店舗または配達員にお知らせ'
                  'ください。',
            ]),
            ContentSection('5. お受け取り後の保存', [
              '品質と食品安全のため、生ケーキはお受け取り後すぐに冷蔵し、'
                  '案内に従ってお召し上がりください。',
            ]),
          ],
        );
      case AppLocale.vi:
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
              'Đơn được giao theo khung giờ bạn chọn lúc đặt: giao ngay hoặc đặt '
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
}

/// Chính sách thanh toán. Bản EN/JA là bản dịch tham khảo.
class PaymentPolicyScreen extends ConsumerWidget {
  const PaymentPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (ref.watch(localeProvider)) {
      case AppLocale.en:
        return const ContentPage(
          title: 'Payment policy',
          updatedLabel: 'Last updated: 06/2026',
          intro: 'This page describes our payment methods, currency, VAT '
              'invoices and how we keep your transactions secure.',
          sections: [
            ContentSection('1. Payment methods', [
              'Cash on delivery (COD) for both delivery and counter-pickup '
                  'orders.',
              'Online payment via 9Pay: QR code, domestic / international '
                  'cards, or bank transfer.',
            ]),
            ContentSection('2. Currency & prices', [
              'All transactions are in VND.',
              'Displayed prices include tax where applicable; delivery fees '
                  'are calculated separately at checkout.',
            ]),
            ContentSection('3. VAT invoices', [
              'We issue VAT invoices when you provide full company details '
                  '(name, tax ID, address, email) at order time.',
            ]),
            ContentSection('4. Payment security', [
              'We do not store your card details on our systems.',
              'Online transactions are processed through a certified secure '
                  'payment gateway.',
            ]),
            ContentSection('5. Discount codes, points & gift cards', [
              'Discount codes, loyalty points and gift cards are applied at '
                  'checkout.',
            ]),
          ],
        );
      case AppLocale.ja:
        return const ContentPage(
          title: 'お支払いポリシー',
          updatedLabel: '最終更新日：2026年6月',
          intro: 'このページでは、お支払い方法、通貨、VAT請求書、および取引の'
              '安全を守る方法についてご説明します。',
          sections: [
            ContentSection('1. お支払い方法', [
              '代金引換（COD）：配送・店頭受け取りのどちらのご注文にも'
                  'ご利用いただけます。',
              '9Payによるオンライン決済：QRコード、国内／国際カード、'
                  'または銀行振込。',
            ]),
            ContentSection('2. 通貨と価格', [
              'すべての取引はベトナムドン（VND）で行われます。',
              '表示価格は該当する場合は税込です。配送料はお会計時に別途計算'
                  'されます。',
            ]),
            ContentSection('3. VAT請求書', [
              'ご注文時に会社情報（会社名、税コード、住所、メールアドレス）を'
                  'すべてご提供いただいた場合、VAT請求書を発行します。',
            ]),
            ContentSection('4. お支払いのセキュリティ', [
              '当店のシステムにお客様のカード情報を保存することはありません。',
              'オンライン取引は、認証を受けた安全な決済ゲートウェイを通じて'
                  '処理されます。',
            ]),
            ContentSection('5. 割引コード、ポイント、ギフトカード', [
              '割引コード、ポイントおよびギフトカードはお会計時に適用されます。',
            ]),
          ],
        );
      case AppLocale.vi:
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
              'Thanh toán online qua 9Pay: quét mã QR, thẻ ngân hàng / quốc tế, hoặc chuyển khoản.',
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
}

/// Chính sách đổi trả & hoàn tiền. Bản EN/JA là bản dịch tham khảo.
class RefundPolicyScreen extends ConsumerWidget {
  const RefundPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (ref.watch(localeProvider)) {
      case AppLocale.en:
        return const ContentPage(
          title: 'Returns & refund policy',
          updatedLabel: 'Last updated: 06/2026',
          intro: 'Because our products are fresh food, returns and refunds are '
              'conditional. Please read the rules below.',
          sections: [
            ContentSection('1. General principle', [
              'As fresh food, we only exchange or refund when the fault is '
                  'ours — for example the wrong item was delivered, or the '
                  'product was damaged / below quality on receipt.',
            ]),
            ContentSection('2. Conditions & timeframe', [
              'Please notify us within 2 hours of receipt, with photos of '
                  'the product.',
              'The product must be unused (except for clearly visible '
                  'defects).',
            ]),
            ContentSection('3. Cancellations', [
              'You may cancel while the order is still "Pending" or '
                  '"Accepted".',
              'Once the kitchen starts preparing, the order may no longer '
                  'be cancellable.',
            ]),
            ContentSection('4. Refund methods', [
              'Exchange for an equivalent product, or refund to the original '
                  'payment method.',
              'COD orders: cash refund or bank transfer. Online orders: '
                  'refund via the payment gateway within its processing '
                  'time.',
            ]),
            ContentSection('5. Support', [
              'Please reach out via our Contact page or hotline for any '
                  'return / refund request.',
            ]),
          ],
        );
      case AppLocale.ja:
        return const ContentPage(
          title: '返品・返金ポリシー',
          updatedLabel: '最終更新日：2026年6月',
          intro: '当店の商品は生鮮食品であるため、返品・返金には条件があります。'
              '以下の規定をお読みください。',
          sections: [
            ContentSection('1. 基本方針', [
              '生鮮食品のため、交換または返金は当店の過失による場合に限ります。'
                  '例えば、商品の間違い、またはお受け取り時に商品の破損や品質不良が'
                  'あった場合です。',
            ]),
            ContentSection('2. 条件と期限', [
              'お受け取りから2時間以内に、商品の写真を添えてご連絡ください。',
              '商品が未使用であること（明らかに目視できる不良がある場合を除く）。',
            ]),
            ContentSection('3. キャンセル', [
              'ご注文が「確認待ち」または「受付済み」の間はキャンセルできます。',
              'キッチンで準備を開始した後は、キャンセルできない場合があります。',
            ]),
            ContentSection('4. 返金方法', [
              '同等の商品との交換、または元のお支払い方法への返金。',
              '代金引換（COD）のご注文：現金または銀行振込で返金します。'
                  'オンライン決済のご注文：決済ゲートウェイを通じて、その処理期間内に'
                  '返金します。',
            ]),
            ContentSection('5. サポート', [
              '返品・返金のご要望は、お問い合わせページまたはホットラインから'
                  'ご連絡ください。',
            ]),
          ],
        );
      case AppLocale.vi:
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
                  'shop, chẳng hạn giao sai sản phẩm, hoặc sản phẩm bị hư hỏng / '
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
}
