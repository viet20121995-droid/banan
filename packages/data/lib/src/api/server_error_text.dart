/// The API answers in Vietnamese only, with a stable error `code`. The
/// customer app sets [apiLocale] to its UI language; for English / Japanese
/// every server error message is replaced here — once, where all API errors
/// are built — by a translation for its code. Vietnamese keeps the server's
/// own, more detailed message. Staff apps never set it, so they're unchanged.
String apiLocale = 'vi';

/// The message to keep on a failure built from an API error.
String? localizeServerMessage(String? code, String? message) {
  if (apiLocale != 'en' && apiLocale != 'ja') return message;
  final t = code == null ? null : _text[code];
  if (t != null) return apiLocale == 'ja' ? t.$2 : t.$1;
  // Untranslated Vietnamese text: lead with a generic line in the customer's
  // language and keep the original for the details.
  if (message != null && _vietnamese.hasMatch(message)) {
    final generic = apiLocale == 'ja'
        ? '問題が発生しました。もう一度お試しください。'
        : 'Something went wrong. Please try again.';
    return '$generic\n($message)';
  }
  return message;
}

final _vietnamese = RegExp(
  '[ăâđêôơưạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ]',
  caseSensitive: false,
);

// ponytail: generic per-code text — the server's details (product name, open
// hour…) are not repeated. Add placeholders if customers need them.
const Map<String, (String, String)> _text = {
  // Checkout — cart & products
  'OPTION_REQUIRED': (
    'Please choose all options (sugar, ice…) for your drinks.',
    'ドリンクのオプション（甘さ・氷など）をすべてお選びください。',
  ),
  'PRODUCT_NOT_FOUND': (
    'An item in your cart is no longer available. Please reload the page.',
    'カート内の商品が見つかりません。ページを再読み込みしてください。',
  ),
  'PRODUCT_UNAVAILABLE': (
    'An item in your cart has just become unavailable. Please remove it.',
    'カート内の商品が販売終了となりました。カートから削除してください。',
  ),
  'VARIANT_UNAVAILABLE': (
    'An option you picked is no longer available. Please check your cart.',
    '選択したオプションは現在ご利用いただけません。カートをご確認ください。',
  ),
  'OUT_OF_STOCK': (
    'An item is out of stock or not enough is left. Please reduce the quantity.',
    '在庫切れ、または在庫が不足している商品があります。数量を減らしてください。',
  ),
  'DAILY_LIMIT_EXCEEDED': (
    'An item is fully booked for that day. Please pick another day or reduce the quantity.',
    'この日のご予約枠が埋まっている商品があります。別の日を選ぶか数量を減らしてください。',
  ),
  'FLAVOR_COUNT_MISMATCH': (
    'Please pick the exact number of flavours for each set.',
    '各セットのフレーバーを指定の数だけお選びください。',
  ),
  'FLAVOR_UNKNOWN': (
    'A flavour you picked is no longer offered. Please choose again.',
    '選択したフレーバーは現在ご用意していません。選び直してください。',
  ),
  'CART_MULTI_STORE': (
    'All items must come from the same shop.',
    'カート内の商品は同じ店舗のものにしてください。',
  ),
  'BUNDLE_UNAVAILABLE': (
    'A set in your cart is no longer sold. Please remove it.',
    'カート内のセットは販売終了となりました。削除してください。',
  ),
  'BUNDLE_CHANGED': (
    'A set in your cart has just been updated. Please add it again.',
    'カート内のセット内容が更新されました。もう一度追加してください。',
  ),
  'BUNDLE_PRICE_ABOVE_SUM': (
    'A set in your cart is temporarily unavailable. Please order the items separately.',
    'カート内のセットは一時的にご利用いただけません。単品でご注文ください。',
  ),
  'MIN_ORDER_NOT_MET': (
    'Your order is below this shop’s minimum. Please add a little more.',
    'この店舗の最低注文金額に達していません。商品を追加してください。',
  ),
  // Checkout — timing & shop
  'STORE_CLOSED': (
    'The shop is closed at the time you picked. Please choose a time within opening hours.',
    'ご指定の時間は営業時間外です。営業時間内の日時をお選びください。',
  ),
  'STORE_LEAD_TIME': (
    'This order needs more preparation time. Please pick a later time.',
    'ご注文の準備にお時間をいただきます。より遅い日時をお選びください。',
  ),
  'ORDER_ITEMS_TIMELINE': (
    'Some items can’t be ready at the time you picked. Please choose a later time.',
    'ご指定の日時に準備できない商品があります。より遅い日時をお選びください。',
  ),
  'STORE_BLACKOUT': (
    'The shop is closed on that day. Please pick another day.',
    'その日は休業日です。別の日をお選びください。',
  ),
  'STORE_PAUSED': (
    'This shop is not taking orders right now. Please choose another branch.',
    'この店舗は現在ご注文を受け付けていません。別の店舗をお選びください。',
  ),
  'STORE_PICKUP_PAUSED': (
    'This shop has paused pickup orders. Please choose delivery or another branch.',
    'この店舗は現在店頭受け取りを停止しています。配達または別の店舗をお選びください。',
  ),
  'STORE_DELIVERY_PAUSED': (
    'This shop has paused delivery. Please choose pickup or another branch.',
    'この店舗は現在配達を停止しています。店頭受け取りまたは別の店舗をお選びください。',
  ),
  'STORE_CANNOT_SERVE': (
    'This shop can’t prepare some items in your cart. Please choose another branch.',
    'この店舗ではご用意できない商品があります。別の店舗をお選びください。',
  ),
  'PICKUP_STORE_NOT_FOUND': (
    'The pickup shop you chose is no longer available. Please choose another.',
    '選択した受け取り店舗は現在ご利用いただけません。別の店舗をお選びください。',
  ),
  'DELIVERY_STORE_NOT_FOUND': (
    'No shop can deliver this order right now. Please try again later.',
    '現在この注文を配達できる店舗がありません。しばらくしてからお試しください。',
  ),
  // Checkout — address & customer
  'ADDRESS_REQUIRED': (
    'Please enter the delivery address.',
    '配達先住所を入力してください。',
  ),
  'WARD_REQUIRED': (
    'Please choose the ward for the delivery address.',
    '配達先の地区を選択してください。',
  ),
  'WARD_RESELECTION_REQUIRED': (
    'Your saved ward was split by the 2025 reform. Please choose it again.',
    '保存された地区は2025年の行政区画再編で分割されました。もう一度お選びください。',
  ),
  'WARD_NOT_FOUND': (
    'Invalid ward. Please choose one from the list.',
    '地区が正しくありません。リストからお選びください。',
  ),
  'WARD_OUTSIDE_DELIVERY_AREA': (
    'We only deliver within (former) Ho Chi Minh City.',
    '配達はホーチミン市（旧市域）内のみとなります。',
  ),
  'WARD_NOT_SERVICEABLE': (
    'We don’t deliver to this area yet. Pickup is still available.',
    'このエリアへの配達は現在承っておりません。店頭受け取りはご利用いただけます。',
  ),
  'GUEST_INFO_REQUIRED': (
    'Please enter your name and phone number to order.',
    'ご注文にはお名前と電話番号の入力が必要です。',
  ),
  'PHONE_HAS_ACCOUNT': (
    'This phone number already has an account. Please sign in to order.',
    'この電話番号はすでに登録されています。ログインしてご注文ください。',
  ),
  'INVOICE_FIELDS_REQUIRED': (
    'Please fill in all company details for the VAT invoice.',
    'VATインボイスの会社情報をすべてご入力ください。',
  ),
  // Discounts & payment
  'COUPON_INVALID': ('Invalid discount code.', 'クーポンコードが正しくありません。'),
  'COUPON_WRONG_STORE': (
    'This code can’t be used at this branch.',
    'このクーポンはこの店舗ではご利用いただけません。',
  ),
  'COUPON_EXPIRED': (
    'This code is not active yet or has expired.',
    'このクーポンは有効期間外です。',
  ),
  'COUPON_LIMIT_REACHED': (
    'This code has been fully used.',
    'このクーポンは利用上限に達しました。',
  ),
  'COUPON_MIN_SUBTOTAL': (
    'Your order doesn’t reach this code’s minimum yet.',
    'ご注文金額がこのクーポンの最低利用金額に達していません。',
  ),
  'COUPON_USER_LIMIT': (
    'You have already used this code.',
    'このクーポンはすでにご利用済みです。',
  ),
  'COUPON_LOGIN_REQUIRED': (
    'This phone number has an account — please sign in to use a discount code, or remove the code.',
    'この電話番号は登録済みです。クーポンをご利用になるにはログインするか、コードを削除してください。',
  ),
  'MEMBER_DISCOUNT_EXCLUSIVE': (
    'The member discount can’t be combined with a discount code.',
    '会員割引はクーポンと併用できません。',
  ),
  'MEMBER_DISCOUNT_INELIGIBLE': (
    'You don’t have enough Micho for the member discount yet.',
    '会員割引に必要なMichoが不足しています。',
  ),
  'LOYALTY_INSUFFICIENT_POINTS': (
    'You don’t have enough Micho points.',
    'Michoポイントが不足しています。',
  ),
  'CAMPAIGN_LIMIT_REACHED': (
    'This promotion has run out.',
    'このキャンペーンは終了しました。',
  ),
  'CAMPAIGN_USER_LIMIT': (
    'You have already used this promotion.',
    'このキャンペーンはすでにご利用済みです。',
  ),
  'GIFT_CARD_INVALID': (
    'The gift card code is invalid, expired or has no balance left.',
    'ギフトカードのコードが無効か、有効期限切れ、または残高がありません。',
  ),
  'PAYMENT_INIT_FAILED': (
    'We couldn’t start the payment, so the order was cancelled. Please try again.',
    'お支払いを開始できなかったため、ご注文はキャンセルされました。もう一度お試しください。',
  ),
  'PAYMENT_PROVIDER_UNAVAILABLE': (
    'This payment method is not available right now.',
    'このお支払い方法は現在ご利用いただけません。',
  ),
  'COD_DISABLED': (
    'We only accept online payment at the moment.',
    '現在オンライン決済のみ承っております。',
  ),
  'ORDER_NOT_PAYABLE': (
    'This order has already been paid or cancelled. Please place a new order.',
    'このご注文はお支払い済みまたはキャンセル済みです。新しくご注文ください。',
  ),
  'ORDER_NOT_CANCELLABLE': (
    'This order can no longer be cancelled.',
    'このご注文はキャンセルできません。',
  ),
  'ORDER_NOT_FOUND': ('Order not found.', 'ご注文が見つかりません。'),
  // Account
  'AUTH_INVALID_CREDENTIALS': (
    'Wrong email/phone or password.',
    'メールアドレス・電話番号またはパスワードが正しくありません。',
  ),
  'AUTH_TOKEN_EXPIRED': (
    'Your session has expired. Please sign in again.',
    'ログインの有効期限が切れました。もう一度ログインしてください。',
  ),
  'AUTH_REFRESH_INVALID': (
    'Your session has expired. Please sign in again.',
    'ログインの有効期限が切れました。もう一度ログインしてください。',
  ),
  'AUTH_ACCOUNT_DISABLED': (
    'This account has been locked. Please contact us.',
    'このアカウントはロックされています。お問い合わせください。',
  ),
  'AUTH_EMAIL_TAKEN': (
    'This email is already registered.',
    'このメールアドレスはすでに登録されています。',
  ),
  'AUTH_PHONE_TAKEN': (
    'This phone number is already registered.',
    'この電話番号はすでに登録されています。',
  ),
  'AUTH_CURRENT_PASSWORD_WRONG': (
    'The password is incorrect.',
    'パスワードが正しくありません。',
  ),
  'AUTH_RESET_INVALID': (
    'This password-reset link is invalid or has expired.',
    'パスワード再設定リンクが無効か、有効期限が切れています。',
  ),
  'AUTH_EMAIL_SAME': (
    'The new email is the same as the current one.',
    '新しいメールアドレスが現在のものと同じです。',
  ),
  'AUTH_EMAIL_CHANGE_INVALID': (
    'This email-change link is invalid or has expired.',
    'メールアドレス変更リンクが無効か、有効期限が切れています。',
  ),
  'AUTH_CANNOT_DELETE_STAFF': (
    'Staff accounts can’t be deleted here.',
    'スタッフアカウントはここでは削除できません。',
  ),
  'ORDER_NOT_ELIGIBLE_FOR_REVIEW': (
    'You can review once the order has been delivered or picked up.',
    'レビューはご注文の受け取り・配達完了後に投稿できます。',
  ),
  'PRODUCT_NOT_IN_ORDER': (
    'This product is not in that order.',
    'この商品はそのご注文に含まれていません。',
  ),
  'INVALID_EMAIL': ('Invalid email address.', 'メールアドレスが正しくありません。'),
  'TOKEN_NOT_FOUND': (
    'This link is invalid or has expired.',
    'このリンクは無効か、有効期限が切れています。',
  ),
};
