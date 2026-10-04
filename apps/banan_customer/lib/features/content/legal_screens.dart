// Long-form legal copy is written as multi-line implicit string
// concatenation inside the section lists — deliberate, not a missing comma.
// Japanese copy has no spaces between words, so adjacent JA strings join
// without whitespace on purpose.
// ignore_for_file: no_adjacent_strings_in_list
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_page.dart';

/// Chính sách bảo mật — soạn theo tinh thần Nghị định 13/2023/NĐ-CP về
/// bảo vệ dữ liệu cá nhân. Nội dung mẫu, cần luật sư rà soát trước khi
/// phát hành chính thức. Bản EN/JA là bản dịch tham khảo; bản VI có giá trị
/// pháp lý.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (ref.watch(localeProvider)) {
      case AppLocale.en:
        return const ContentPage(
          title: 'Privacy policy',
          updatedLabel: 'Last updated: 06/2026',
          intro: 'Banan Fukuoka Saigon ("we") respects and is committed to '
              'protecting your personal data under Decree 13/2023/NĐ-CP and '
              'applicable Vietnamese law. This policy explains what we collect, '
              'how we use it and how we protect it. The Vietnamese version '
              'prevails legally.',
          sections: [
            ContentSection('1. Data we collect', [
              'Identity details: full name, phone number, email, birthday '
                  '(when you provide it for birthday offers).',
              'Delivery details: delivery address, ward, delivery notes.',
              'Order details: products, cake customizations, purchase history, '
                  'loyalty points and discount codes used.',
              'Technical data: device, browser, IP address and cookies '
                  'required to run the website.',
            ]),
            ContentSection('2. How we use it', [
              'To process and deliver orders, support customers, and issue VAT '
                  'invoices on request.',
              'To run the loyalty program, birthday offers and promotions you '
                  'have opted into.',
              'To improve our products, services and website experience.',
              'To meet legal obligations on tax, accounting and food safety.',
            ]),
            ContentSection('3. Legal basis & consent', [
              'We only process data with your consent, when necessary to '
                  'fulfil a contract (your order), or when required by law.',
              'You may withdraw consent at any time. This does not affect '
                  'processing already carried out.',
            ]),
            ContentSection('4. Sharing', [
              'We do not sell your personal data.',
              'We only share it with: delivery partners (to deliver orders), '
                  'payment gateways (to process transactions) and state '
                  'authorities on lawful request.',
            ]),
            ContentSection('5. Storage & security', [
              'Data is stored on access-controlled infrastructure with '
                  'encrypted connections (HTTPS) and regular backups.',
              'Order data is kept for the period required by accounting/tax '
                  'law; marketing data is kept until you unsubscribe.',
            ]),
            ContentSection('6. Your rights', [
              'You have the right to know, access, correct, delete, restrict '
                  'processing, withdraw consent and complain about your '
                  'personal data.',
              'To exercise these rights, please reach out via our Contact page '
                  'or hotline.',
            ]),
            ContentSection('7. Cookies', [
              'We use essential cookies so sign-in and the cart work. '
                  'Analytics/non-essential cookies are only enabled when you '
                  'agree on the cookie banner.',
            ]),
            ContentSection('8. Contact', [
              'For any personal-data request, please use our Contact page. '
                  'We respond as soon as possible.',
            ]),
          ],
        );
      case AppLocale.ja:
        return const ContentPage(
          title: 'プライバシーポリシー',
          updatedLabel: '最終更新日：2026年6月',
          intro: 'Banan Fukuoka Saigon（以下「当店」）は、政令13/2023/NĐ-CPおよび'
              'ベトナムの関係法令に基づき、お客様の個人データを尊重し、保護することを'
              'お約束します。本ポリシーでは、当店が収集する情報、その利用方法および'
              '保護方法についてご説明します。法的にはベトナム語版が優先されます。',
          sections: [
            ContentSection('1. 収集するデータ', [
              '本人確認情報：氏名、電話番号、メールアドレス、生年月日'
                  '（誕生日特典のためにご提供いただいた場合）。',
              '配送情報：お届け先住所、坊・社（区画）、配送時のメモ。',
              '注文情報：商品、ケーキのカスタマイズ内容、購入履歴、'
                  'ポイントおよびご利用の割引コード。',
              '技術データ：ウェブサイトの運営に必要な端末、ブラウザ、'
                  'IPアドレスおよびCookie。',
            ]),
            ContentSection('2. 利用目的', [
              'ご注文の処理・配送、お客様サポート、ご要望に応じたVAT請求書の発行。',
              'ポイントプログラム、誕生日特典、およびお客様が受け取りに同意された'
                  'キャンペーンの運営。',
              '商品、サービスおよびウェブサイトの利便性の向上。',
              '税務、会計および食品安全に関する法的義務の遵守。',
            ]),
            ContentSection('3. 法的根拠と同意', [
              '当店は、お客様の同意がある場合、契約（お客様のご注文）の履行に'
                  '必要な場合、または法令により求められる場合にのみデータを'
                  '処理します。',
              'お客様はいつでも同意を撤回できます。撤回前に行われた処理には'
                  '影響しません。',
            ]),
            ContentSection('4. データの共有', [
              '当店はお客様の個人データを販売しません。',
              'データの共有先は、配送パートナー（ご注文の配送のため）、'
                  '決済代行会社（取引の処理のため）、および法令に基づく要請が'
                  'あった場合の国家機関に限られます。',
            ]),
            ContentSection('5. 保管とセキュリティ', [
              'データはアクセス管理されたインフラ上に保管され、通信は暗号化'
                  '（HTTPS）され、定期的にバックアップされます。',
              '注文データは会計・税務法令で定められた期間保管し、マーケティング'
                  'データは配信停止のお手続きをされるまで保管します。',
            ]),
            ContentSection('6. お客様の権利', [
              'お客様は、ご自身の個人データについて、知る権利、アクセス、訂正、'
                  '削除、処理の制限、同意の撤回および苦情申立ての権利を有します。',
              'これらの権利を行使される場合は、お問い合わせページまたは'
                  'ホットラインからご連絡ください。',
            ]),
            ContentSection('7. Cookie', [
              'ログインやカートを機能させるため、必須のCookieを使用しています。'
                  '分析用・必須でないCookieは、Cookieバナーで同意いただいた場合に'
                  'のみ有効になります。',
            ]),
            ContentSection('8. お問い合わせ', [
              '個人データに関するご要望は、お問い合わせページからお寄せください。'
                  'できるだけ早くご返信いたします。',
            ]),
          ],
        );
      case AppLocale.vi:
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
}

/// Điều khoản sử dụng / điều kiện đặt hàng. Bản EN/JA là bản dịch tham khảo.
class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (ref.watch(localeProvider)) {
      case AppLocale.en:
        return const ContentPage(
          title: 'Terms of service',
          updatedLabel: 'Last updated: 06/2026',
          intro: 'By ordering on Banan Fukuoka Saigon you agree to the terms '
              'below. Please read them before using the service. The '
              'Vietnamese version prevails legally.',
          sections: [
            ContentSection('1. Ordering', [
              'An order is confirmed once you complete payment or choose pay '
                  'on receipt. Some products (birthday cakes, custom sets) '
                  'must be ordered ahead per their preparation time.',
              'We may decline or cancel an order if a product is out of '
                  'stock, the details are invalid, or fraud is suspected.',
            ]),
            ContentSection('2. Prices & payment', [
              'Prices are shown in VND, tax included where applicable. '
                  'Delivery fees are calculated by address at checkout.',
              'We support pay on receipt (store pickup) and online payment '
                  'gateways. VAT invoices are issued when you provide full '
                  'company details.',
            ]),
            ContentSection('3. Cancellations & refunds', [
              'You may cancel while the order is still "Pending" or '
                  '"Accepted". Once the kitchen starts preparing, a '
                  'cancellation may not be accepted.',
              'For orders paid online, refunds are returned to the original '
                  "payment method within the payment provider's timeframe.",
            ]),
            ContentSection('4. Delivery & pickup', [
              'Delivery times are estimates and may vary with weather, '
                  'traffic and order volume. Please provide an accurate '
                  'address and phone number.',
              'Fresh cakes should be stored and consumed per the '
                  'instructions right after receipt.',
            ]),
            ContentSection('5. Intellectual property', [
              'All trademarks, images, recipes and content on this website '
                  'belong to Banan Fukuoka Saigon. Do not copy without '
                  'written consent.',
            ]),
            ContentSection('6. Limitation of liability', [
              'We are not liable for indirect damages beyond our reasonable '
                  'control. Our maximum liability is limited to the value of '
                  'the related order.',
            ]),
            ContentSection('7. Governing law', [
              'These terms are governed by Vietnamese law. Disputes are '
                  'settled by the competent court in Ho Chi Minh City.',
            ]),
          ],
        );
      case AppLocale.ja:
        return const ContentPage(
          title: '利用規約',
          updatedLabel: '最終更新日：2026年6月',
          intro: 'Banan Fukuoka Saigonでご注文いただくことにより、お客様は以下の'
              '規約に同意したものとみなされます。サービスをご利用になる前に'
              'お読みください。法的にはベトナム語版が優先されます。',
          sections: [
            ContentSection('1. ご注文', [
              'ご注文は、お支払いを完了されるか、受け取り時払いを選択された時点で'
                  '確定します。一部の商品（バースデーケーキ、オーダーメイドの'
                  'セット）は、準備期間に合わせて事前にご注文いただく必要が'
                  'あります。',
              '商品の在庫切れ、情報の不備、または不正の疑いがある場合、当店は'
                  'ご注文をお断りまたはキャンセルすることがあります。',
            ]),
            ContentSection('2. 価格とお支払い', [
              '価格はベトナムドン（VND）で表示され、該当する場合は税込です。'
                  '配送料はお会計時にお届け先住所に応じて計算されます。',
              '受け取り時払い（店頭受け取り）およびオンライン決済に対応して'
                  'います。VAT請求書は、会社情報をすべてご提供いただいた場合に'
                  '発行します。',
            ]),
            ContentSection('3. キャンセルと返金', [
              'ご注文が「確認待ち」または「受付済み」の間はキャンセルできます。'
                  'キッチンで準備を開始した後は、キャンセルをお受けできない場合が'
                  'あります。',
              'オンラインでお支払い済みのご注文の返金は、決済事業者の所定の期間内に'
                  '元のお支払い方法へ返金されます。',
            ]),
            ContentSection('4. 配送と店頭受け取り', [
              'お届け時間は目安であり、天候、交通状況、注文数により前後する'
                  '場合があります。正確な住所と電話番号をご入力ください。',
              '生ケーキは、お受け取り後すぐに案内に従って保存し、お召し上がり'
                  'ください。',
            ]),
            ContentSection('5. 知的財産', [
              '本ウェブサイト上のすべての商標、画像、レシピおよびコンテンツは'
                  'Banan Fukuoka Saigonに帰属します。書面による同意なく複製'
                  'しないでください。',
            ]),
            ContentSection('6. 責任の制限', [
              '当店は、当店の合理的な管理を超える間接的な損害について責任を'
                  '負いません。当店の責任の上限は、該当するご注文の金額とします。',
            ]),
            ContentSection('7. 準拠法', [
              '本規約はベトナム法に準拠します。紛争はホーチミン市の管轄裁判所に'
                  'おいて解決されます。',
            ]),
          ],
        );
      case AppLocale.vi:
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
}
