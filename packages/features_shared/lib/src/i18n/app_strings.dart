import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported UI languages. Vietnamese is the default — the brand is a
/// Saigon patisserie — with English as an opt-in for the customer site.
enum AppLocale {
  vi,
  en;

  Locale get locale => switch (this) {
        AppLocale.vi => const Locale('vi'),
        AppLocale.en => const Locale('en'),
      };

  String get label => switch (this) {
        AppLocale.vi => 'Tiếng Việt',
        AppLocale.en => 'English',
      };

  String get shortLabel => switch (this) {
        AppLocale.vi => 'VI',
        AppLocale.en => 'EN',
      };
}

/// Active UI language. In-memory (resets on a fresh page load, consistent
/// with the app's kiosk-style preference model). Defaults to Vietnamese.
final localeProvider = StateProvider<AppLocale>((_) => AppLocale.vi);

/// The string table for the active locale. Watch this in any ConsumerWidget:
/// `final s = ref.watch(stringsProvider);`
final stringsProvider = Provider<AppStrings>((ref) {
  return ref.watch(localeProvider) == AppLocale.en
      ? const _En()
      : const _Vi();
});

/// All user-facing UI copy. Product / category / cake names come from the
/// API and are intentionally NOT translated.
abstract class AppStrings {
  const AppStrings();

  // Common
  String get appTagline;
  String get signIn;
  String get signUp;
  String get signOut;
  String get save;
  String get cancel;
  String get delete;
  String get confirm;
  String get retry;
  String get edit;
  String get close;
  String get required;
  String get loading;
  String get language;

  // Menu / home
  String get searchHint;
  String get pickup;
  String get pickupSub;
  String get delivery;
  String get deliverySub;
  String get all;
  String get allCakes;
  String get fromTheBakery;
  String get noPostsYet;
  String greetingMorning(String name);
  String greetingAfternoon(String name);
  String greetingEvening(String name);
  String michoBalance(int n);
  String earnedMicho(int n);
  String get noCakesTitle;
  String get noCakesMsg;
  String viewCart(int n);
  String get installApp;
  String get locations;
  String get notifications;
  String get myProfile;
  String get membership;
  String get myOrders;
  String get myAddresses;
  String get shopThisProduct;
  String get orderNow;
  String get navMenu;
  String get trackOrders;
  String get markAllRead;
  String get noNotificationsTitle;
  String get noNotificationsMsg;
  String get chooseSizeFlavor;
  String readyInMin(int n);
  String get addToCart;
  String addedToCart(String name);

  // Cart / checkout
  String get cart;
  String get yourCart;
  String get removeItem;
  String get noOrdersTitle;
  String get noOrdersMsg;
  String get checkout;
  String get emptyCartTitle;
  String get emptyCartMsg;
  String get subtotal;
  String get deliveryFee;
  String get total;
  String get campaignDiscount;
  String get bundleDiscount;
  String get pointsDiscount;
  String get placeOrder;
  String get deliveryAddress;
  String get recipientName;
  String get phone;
  String get addressLine;
  String get city;
  String get district;
  String get notesOptional;
  String get haveAccount;
  String get fulfillment;
  String get payment;
  String get summary;
  String get yourDetails;
  String get apply;
  String get couponCode;
  String get scheduleNow;
  String get scheduleLater;
  String get emailOptional;
  String get recipient;
  String get pickupBranch;
  String get whenDeliver;
  String get whenReady;
  String get savings;
  String get freeDelivery;
  String get coupon;
  String get couldNotLoadBranches;
  String get openNow;
  String get closedNow;
  String get phoneTooShort;
  String get invalidEmail;
  String inMinutes(int n);
  String inHours(int n);
  String get tomorrow;
  String inDays(int n);
  String get weWillText;
  String orderStatusLabel(OrderStatus status);
  String get orderTitle;
  String get backToMenu;
  String get items;
  String get timeline;
  String get cancelOrder;
  String get cancelOrderQ;
  String get keep;
  String get orderMoreCakes;
  String get deliveryOnWay;
  String get readyPickupBang;
  String get courierNote;
  String get pickupNote;

  // Auth
  String get loginTitle;
  String get loginSubtitle;
  String get email;
  String get emailOrPhone;
  String get password;
  String get fullName;
  String get birthday;
  String get createAccount;
  String get backToLogin;
  String get noAccount;
  String get registerTitle;
  String get registerSubtitle;

  // Profile / addresses
  String get profileTitle;
  String get emailSignIn;
  String get avatarUrlOptional;
  String get saveChanges;
  String get savedAddresses;
  String get savedAddressesSub;
  String get addAddress;
  String get newAddress;
  String get editAddress;
  String get label;
  String get setDefault;
  String get defaultBadge;
  String get noAddressesTitle;
  String get noAddressesMsg;
  String get deleteAddressQ;
  String get cannotUndo;
  String get labelFieldHint;
  String get apartmentOptional;
  String get districtOptional;
  String get postalOptional;
  String get setAsDefaultAddress;
  String get profileUpdated;
  String get notSet;
  String get pleaseEnterName;

  // Membership
  String get membershipTitle;
  String get howItWorks;
  String get history;
  String get noLoyaltyActivity;
  String michoUntilNextTier(int n);
  String get topTier;
  String loyaltyHowText(String earn, String value);

  // Staff (merchant / kitchen) chrome
  String get orders;
  String get dashboard;
  String get refunds;
  String get menuMgmt;
  String get customers;
  String get promoCodes;
  String get collections;
  String get threads;
  String get refresh;
  String get kitchenQueue;
  String get kitchenBrand;
  String get productionBoard;
  String get analytics;
  String get kanban;
  String get kitchenAnalytics;
}

class _Vi extends AppStrings {
  const _Vi();

  @override
  String get appTagline => 'Đặt bánh tươi mỗi ngày.';
  @override
  String get signIn => 'Đăng nhập';
  @override
  String get signUp => 'Đăng ký';
  @override
  String get signOut => 'Đăng xuất';
  @override
  String get save => 'Lưu';
  @override
  String get cancel => 'Huỷ';
  @override
  String get delete => 'Xoá';
  @override
  String get confirm => 'Xác nhận';
  @override
  String get retry => 'Thử lại';
  @override
  String get edit => 'Sửa';
  @override
  String get close => 'Đóng';
  @override
  String get required => 'Bắt buộc';
  @override
  String get loading => 'Đang tải…';
  @override
  String get language => 'Ngôn ngữ';

  @override
  String get searchHint => 'Tìm bánh, hương vị, dịp lễ';
  @override
  String get pickup => 'Lấy tại quầy';
  @override
  String get pickupSub => 'Nhận tại chi nhánh';
  @override
  String get delivery => 'Giao hàng';
  @override
  String get deliverySub => 'Giao tận nơi';
  @override
  String get all => 'Tất cả';
  @override
  String get allCakes => 'Tất cả bánh';
  @override
  String get fromTheBakery => 'Từ tiệm bánh';
  @override
  String get noPostsYet => 'Chưa có bài viết.';
  @override
  String greetingMorning(String name) => 'Chào buổi sáng, $name';
  @override
  String greetingAfternoon(String name) => 'Chào buổi chiều, $name';
  @override
  String greetingEvening(String name) => 'Chào buổi tối, $name';
  @override
  String michoBalance(int n) => '$n Micho';
  @override
  String earnedMicho(int n) => 'Bạn đã tích lũy được $n Micho';
  @override
  String get noCakesTitle => 'Không có bánh phù hợp';
  @override
  String get noCakesMsg => 'Thử danh mục khác hoặc xoá tìm kiếm.';
  @override
  String viewCart(int n) => 'Xem giỏ · $n món';
  @override
  String get installApp => 'Cài ứng dụng';
  @override
  String get locations => 'Chi nhánh';
  @override
  String get notifications => 'Thông báo';
  @override
  String get myProfile => 'Hồ sơ';
  @override
  String get membership => 'Thành viên';
  @override
  String get myOrders => 'Đơn của tôi';
  @override
  String get myAddresses => 'Địa chỉ của tôi';
  @override
  String get shopThisProduct => 'Xem sản phẩm';
  @override
  String get orderNow => 'Đặt hàng';
  @override
  String get navMenu => 'Thực đơn';
  @override
  String get trackOrders => 'Theo dõi đơn hàng';
  @override
  String get markAllRead => 'Đánh dấu đã đọc';
  @override
  String get noNotificationsTitle => 'Chưa có thông báo';
  @override
  String get noNotificationsMsg =>
      'Cập nhật đơn hàng và ưu đãi sẽ hiện ở đây.';
  @override
  String get chooseSizeFlavor => 'Chọn kích thước & hương vị';
  @override
  String readyInMin(int n) => 'Sẵn sàng sau ~$n phút';
  @override
  String get addToCart => 'Thêm vào giỏ';
  @override
  String addedToCart(String name) => 'Đã thêm $name vào giỏ';

  @override
  String get cart => 'Giỏ hàng';
  @override
  String get yourCart => 'Giỏ hàng của bạn';
  @override
  String get removeItem => 'Xoá';
  @override
  String get noOrdersTitle => 'Chưa có đơn hàng';
  @override
  String get noOrdersMsg => 'Các đơn bánh của bạn sẽ hiện ở đây.';
  @override
  String get checkout => 'Thanh toán';
  @override
  String get emptyCartTitle => 'Giỏ hàng trống';
  @override
  String get emptyCartMsg => 'Thêm vài chiếc bánh để bắt đầu.';
  @override
  String get subtotal => 'Tạm tính';
  @override
  String get deliveryFee => 'Phí giao hàng';
  @override
  String get total => 'Tổng cộng';
  @override
  String get campaignDiscount => 'Khuyến mãi';
  @override
  String get bundleDiscount => 'Giảm combo';
  @override
  String get pointsDiscount => 'Đổi điểm';
  @override
  String get placeOrder => 'Đặt hàng';
  @override
  String get deliveryAddress => 'Địa chỉ giao hàng';
  @override
  String get recipientName => 'Tên người nhận';
  @override
  String get phone => 'Số điện thoại';
  @override
  String get addressLine => 'Địa chỉ';
  @override
  String get city => 'Thành phố';
  @override
  String get district => 'Quận/Huyện';
  @override
  String get notesOptional => 'Ghi chú (tuỳ chọn)';
  @override
  String get haveAccount => 'Đã có tài khoản?';
  @override
  String get fulfillment => 'Hình thức nhận';
  @override
  String get payment => 'Thanh toán';
  @override
  String get summary => 'Tóm tắt';
  @override
  String get yourDetails => 'Thông tin của bạn';
  @override
  String get apply => 'Áp dụng';
  @override
  String get couponCode => 'Mã giảm giá';
  @override
  String get scheduleNow => 'Bây giờ';
  @override
  String get scheduleLater => 'Hẹn giờ sau';
  @override
  String get emailOptional => 'Email (tuỳ chọn)';
  @override
  String get recipient => 'Người nhận';
  @override
  String get pickupBranch => 'Chi nhánh lấy hàng';
  @override
  String get whenDeliver => 'Khi nào giao hàng?';
  @override
  String get whenReady => 'Khi nào cần sẵn sàng?';
  @override
  String get savings => 'Ưu đãi';
  @override
  String get freeDelivery => 'Miễn phí giao hàng';
  @override
  String get coupon => 'Mã giảm';
  @override
  String get couldNotLoadBranches => 'Không tải được chi nhánh';
  @override
  String get openNow => 'Đang mở';
  @override
  String get closedNow => 'Đã đóng';
  @override
  String get phoneTooShort => 'Số điện thoại quá ngắn';
  @override
  String get invalidEmail => 'Email không hợp lệ';
  @override
  String inMinutes(int n) => 'Sau $n phút';
  @override
  String inHours(int n) => 'Sau $n giờ';
  @override
  String get tomorrow => 'Ngày mai';
  @override
  String inDays(int n) => 'Sau $n ngày';
  @override
  String get weWillText => 'Chúng tôi sẽ nhắn cập nhật đơn vào số này.';
  @override
  String orderStatusLabel(OrderStatus status) => switch (status) {
        OrderStatus.pending => 'Chờ xác nhận',
        OrderStatus.accepted => 'Đã nhận đơn',
        OrderStatus.inPreparation => 'Đang chuẩn bị',
        OrderStatus.sentToKitchen => 'Đã chuyển bếp',
        OrderStatus.readyForPickup => 'Sẵn sàng để lấy',
        OrderStatus.delivering => 'Đang giao',
        OrderStatus.completed => 'Hoàn tất',
        OrderStatus.cancelled => 'Đã huỷ',
        OrderStatus.refunded => 'Đã hoàn tiền',
      };
  @override
  String get orderTitle => 'Đơn hàng';
  @override
  String get backToMenu => 'Về thực đơn';
  @override
  String get items => 'Sản phẩm';
  @override
  String get timeline => 'Tiến trình';
  @override
  String get cancelOrder => 'Huỷ đơn';
  @override
  String get cancelOrderQ => 'Huỷ đơn này?';
  @override
  String get keep => 'Giữ lại';
  @override
  String get orderMoreCakes => 'Đặt thêm bánh';
  @override
  String get deliveryOnWay => 'Đơn của bạn đang trên đường!';
  @override
  String get readyPickupBang => 'Sẵn sàng để lấy!';
  @override
  String get courierNote =>
      'Tài xế vừa lên đường với chiếc bánh của bạn. Chúng tôi sẽ '
      'báo "đã giao" ngay khi đến nơi.';
  @override
  String get pickupNote =>
      'Ghé cửa hàng bất cứ lúc nào, đơn đã sẵn ở quầy.';

  @override
  String get loginTitle => 'Banan Fukuoka Saigon';
  @override
  String get loginSubtitle => 'Đăng nhập để đặt bánh hôm nay.';
  @override
  String get email => 'Email';
  @override
  String get emailOrPhone => 'Email hoặc số điện thoại';
  @override
  String get password => 'Mật khẩu';
  @override
  String get fullName => 'Họ và tên';
  @override
  String get birthday => 'Ngày sinh';
  @override
  String get createAccount => 'Tạo tài khoản';
  @override
  String get backToLogin => 'Quay lại đăng nhập';
  @override
  String get noAccount => 'Chưa có tài khoản? Tạo ngay';
  @override
  String get registerTitle => 'Tạo tài khoản Banan';
  @override
  String get registerSubtitle =>
      'Tích điểm cho mỗi đơn hàng. Miễn phí tham gia.';

  @override
  String get profileTitle => 'Hồ sơ của tôi';
  @override
  String get emailSignIn => 'Email (đăng nhập)';
  @override
  String get avatarUrlOptional => 'Ảnh đại diện (URL, tuỳ chọn)';
  @override
  String get saveChanges => 'Lưu thay đổi';
  @override
  String get savedAddresses => 'Địa chỉ đã lưu';
  @override
  String get savedAddressesSub => 'Quản lý địa chỉ giao hàng để đặt nhanh hơn';
  @override
  String get addAddress => 'Thêm địa chỉ';
  @override
  String get newAddress => 'Địa chỉ mới';
  @override
  String get editAddress => 'Sửa địa chỉ';
  @override
  String get label => 'Nhãn';
  @override
  String get setDefault => 'Đặt làm mặc định';
  @override
  String get defaultBadge => 'Mặc định';
  @override
  String get noAddressesTitle => 'Chưa có địa chỉ';
  @override
  String get noAddressesMsg => 'Thêm địa chỉ để lần sau đặt nhanh hơn.';
  @override
  String get deleteAddressQ => 'Xoá địa chỉ này?';
  @override
  String get cannotUndo => 'Hành động này không thể hoàn tác.';
  @override
  String get labelFieldHint => 'Nhãn (Nhà, Công ty…)';
  @override
  String get apartmentOptional => 'Căn hộ, toà nhà (tuỳ chọn)';
  @override
  String get districtOptional => 'Quận/Huyện (tuỳ chọn)';
  @override
  String get postalOptional => 'Mã bưu chính (tuỳ chọn)';
  @override
  String get setAsDefaultAddress => 'Đặt làm địa chỉ mặc định';
  @override
  String get profileUpdated => 'Đã cập nhật hồ sơ';
  @override
  String get notSet => 'Chưa đặt';
  @override
  String get pleaseEnterName => 'Vui lòng nhập tên';

  @override
  String get membershipTitle => 'Thành viên';
  @override
  String get howItWorks => 'Cách hoạt động';
  @override
  String get history => 'Lịch sử';
  @override
  String get noLoyaltyActivity =>
      'Chưa có hoạt động. Đặt hàng để bắt đầu tích Micho.';
  @override
  String michoUntilNextTier(int n) => 'Còn $n Micho để lên hạng tiếp theo';
  @override
  String get topTier => 'Bạn đang ở hạng cao nhất, cảm ơn bạn!';
  @override
  String loyaltyHowText(String earn, String value) =>
      'Tích 1 Micho cho mỗi $earn chi tiêu. '
      'Khi có trên 100 Micho, mỗi đơn được giảm 5%.';

  @override
  String get orders => 'Đơn hàng';
  @override
  String get dashboard => 'Bảng điều khiển';
  @override
  String get refunds => 'Hoàn tiền';
  @override
  String get menuMgmt => 'Thực đơn';
  @override
  String get customers => 'Khách hàng';
  @override
  String get promoCodes => 'Mã khuyến mãi';
  @override
  String get collections => 'Bộ sưu tập';
  @override
  String get threads => 'Bài viết';
  @override
  String get refresh => 'Làm mới';
  @override
  String get kitchenQueue => 'Hàng chờ bếp';
  @override
  String get kitchenBrand => 'Banan · Bếp';
  @override
  String get productionBoard => 'Bảng sản xuất';
  @override
  String get analytics => 'Thống kê';
  @override
  String get kanban => 'Kanban';
  @override
  String get kitchenAnalytics => 'Thống kê bếp';
}

class _En extends AppStrings {
  const _En();

  @override
  String get appTagline => "Order today's fresh creations.";
  @override
  String get signIn => 'Sign in';
  @override
  String get signUp => 'Sign up';
  @override
  String get signOut => 'Sign out';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get confirm => 'Confirm';
  @override
  String get retry => 'Retry';
  @override
  String get edit => 'Edit';
  @override
  String get close => 'Close';
  @override
  String get required => 'Required';
  @override
  String get loading => 'Loading…';
  @override
  String get language => 'Language';

  @override
  String get searchHint => 'Search cakes, flavors, occasions';
  @override
  String get pickup => 'Pickup';
  @override
  String get pickupSub => 'Collect at a branch';
  @override
  String get delivery => 'Delivery';
  @override
  String get deliverySub => 'Bring it to me';
  @override
  String get all => 'All';
  @override
  String get allCakes => 'All cakes';
  @override
  String get fromTheBakery => 'From the bakery';
  @override
  String get noPostsYet => 'No posts yet.';
  @override
  String greetingMorning(String name) => 'Good morning, $name';
  @override
  String greetingAfternoon(String name) => 'Good afternoon, $name';
  @override
  String greetingEvening(String name) => 'Good evening, $name';
  @override
  String michoBalance(int n) => '$n Micho';
  @override
  String earnedMicho(int n) => "You've earned $n Micho";
  @override
  String get noCakesTitle => 'No cakes match';
  @override
  String get noCakesMsg => 'Try a different category or clear your search.';
  @override
  String viewCart(int n) => 'View cart · $n item${n == 1 ? '' : 's'}';
  @override
  String get installApp => 'Install app';
  @override
  String get locations => 'Locations';
  @override
  String get notifications => 'Notifications';
  @override
  String get myProfile => 'My profile';
  @override
  String get membership => 'Membership';
  @override
  String get myOrders => 'My orders';
  @override
  String get myAddresses => 'My addresses';
  @override
  String get shopThisProduct => 'Shop this product';
  @override
  String get orderNow => 'Order now';
  @override
  String get navMenu => 'Menu';
  @override
  String get trackOrders => 'Track order';
  @override
  String get markAllRead => 'Mark all read';
  @override
  String get noNotificationsTitle => 'No notifications yet';
  @override
  String get noNotificationsMsg => 'Order updates and offers land here.';
  @override
  String get chooseSizeFlavor => 'Choose a size & flavor';
  @override
  String readyInMin(int n) => 'Ready in ~$n min';
  @override
  String get addToCart => 'Add to cart';
  @override
  String addedToCart(String name) => '$name added to cart';

  @override
  String get cart => 'Cart';
  @override
  String get yourCart => 'Your cart';
  @override
  String get removeItem => 'Remove';
  @override
  String get noOrdersTitle => 'No orders yet';
  @override
  String get noOrdersMsg => 'Your cake adventures will appear here.';
  @override
  String get checkout => 'Checkout';
  @override
  String get emptyCartTitle => 'Your cart is empty';
  @override
  String get emptyCartMsg => 'Add a few cakes to get started.';
  @override
  String get subtotal => 'Subtotal';
  @override
  String get deliveryFee => 'Delivery fee';
  @override
  String get total => 'Total';
  @override
  String get campaignDiscount => 'Promotion';
  @override
  String get bundleDiscount => 'Combo discount';
  @override
  String get pointsDiscount => 'Points redemption';
  @override
  String get placeOrder => 'Place order';
  @override
  String get deliveryAddress => 'Delivery address';
  @override
  String get recipientName => 'Recipient name';
  @override
  String get phone => 'Phone';
  @override
  String get addressLine => 'Address line';
  @override
  String get city => 'City';
  @override
  String get district => 'District';
  @override
  String get notesOptional => 'Notes (optional)';
  @override
  String get haveAccount => 'Have an account?';
  @override
  String get fulfillment => 'Fulfillment';
  @override
  String get payment => 'Payment';
  @override
  String get summary => 'Summary';
  @override
  String get yourDetails => 'Your details';
  @override
  String get apply => 'Apply';
  @override
  String get couponCode => 'Coupon code';
  @override
  String get scheduleNow => 'Now';
  @override
  String get scheduleLater => 'Schedule for later';
  @override
  String get emailOptional => 'Email (optional)';
  @override
  String get recipient => 'Recipient';
  @override
  String get pickupBranch => 'Pickup branch';
  @override
  String get whenDeliver => 'When should we deliver?';
  @override
  String get whenReady => 'When should it be ready?';
  @override
  String get savings => 'Savings';
  @override
  String get freeDelivery => 'Free delivery';
  @override
  String get coupon => 'Coupon';
  @override
  String get couldNotLoadBranches => 'Could not load branches';
  @override
  String get openNow => 'Open';
  @override
  String get closedNow => 'Closed';
  @override
  String get phoneTooShort => 'Phone is too short';
  @override
  String get invalidEmail => 'Invalid email';
  @override
  String inMinutes(int n) => 'In $n minutes';
  @override
  String inHours(int n) => 'In $n hours';
  @override
  String get tomorrow => 'Tomorrow';
  @override
  String inDays(int n) => 'In $n days';
  @override
  String get weWillText => "We'll text you order updates at this number.";
  @override
  String orderStatusLabel(OrderStatus status) => switch (status) {
        OrderStatus.pending => 'Pending',
        OrderStatus.accepted => 'Accepted',
        OrderStatus.inPreparation => 'In preparation',
        OrderStatus.sentToKitchen => 'Sent to kitchen',
        OrderStatus.readyForPickup => 'Ready for pickup',
        OrderStatus.delivering => 'Delivering',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.refunded => 'Refunded',
      };
  @override
  String get orderTitle => 'Order';
  @override
  String get backToMenu => 'Back to menu';
  @override
  String get items => 'Items';
  @override
  String get timeline => 'Timeline';
  @override
  String get cancelOrder => 'Cancel order';
  @override
  String get cancelOrderQ => 'Cancel this order?';
  @override
  String get keep => 'Keep';
  @override
  String get orderMoreCakes => 'Order more cakes';
  @override
  String get deliveryOnWay => 'Your order is on the way!';
  @override
  String get readyPickupBang => 'Ready for pickup!';
  @override
  String get courierNote =>
      "Our courier just left with your cake. We'll mark it delivered "
      'as soon as it lands.';
  @override
  String get pickupNote =>
      'Come by the store any time — your order is ready at the counter.';

  @override
  String get loginTitle => 'Banan Fukuoka Saigon';
  @override
  String get loginSubtitle => "Sign in to order today's creations.";
  @override
  String get email => 'Email';
  @override
  String get emailOrPhone => 'Email or phone';
  @override
  String get password => 'Password';
  @override
  String get fullName => 'Full name';
  @override
  String get birthday => 'Birthday';
  @override
  String get createAccount => 'Create account';
  @override
  String get backToLogin => 'Back to sign in';
  @override
  String get noAccount => "Don't have an account? Create one";
  @override
  String get registerTitle => 'Create your Banan account';
  @override
  String get registerSubtitle => 'Earn points on every order. Free to join.';

  @override
  String get profileTitle => 'My profile';
  @override
  String get emailSignIn => 'Email (sign-in)';
  @override
  String get avatarUrlOptional => 'Avatar image URL (optional)';
  @override
  String get saveChanges => 'Save changes';
  @override
  String get savedAddresses => 'Saved addresses';
  @override
  String get savedAddressesSub =>
      'Manage delivery addresses for faster checkout';
  @override
  String get addAddress => 'Add address';
  @override
  String get newAddress => 'New address';
  @override
  String get editAddress => 'Edit address';
  @override
  String get label => 'Label';
  @override
  String get setDefault => 'Set as default';
  @override
  String get defaultBadge => 'Default';
  @override
  String get noAddressesTitle => 'No saved addresses';
  @override
  String get noAddressesMsg => 'Add an address to check out faster next time.';
  @override
  String get deleteAddressQ => 'Delete address?';
  @override
  String get cannotUndo => 'This cannot be undone.';
  @override
  String get labelFieldHint => 'Label (Home, Office…)';
  @override
  String get apartmentOptional => 'Apartment, suite (optional)';
  @override
  String get districtOptional => 'District (optional)';
  @override
  String get postalOptional => 'Postal code (optional)';
  @override
  String get setAsDefaultAddress => 'Set as default address';
  @override
  String get profileUpdated => 'Profile updated';
  @override
  String get notSet => 'Not set';
  @override
  String get pleaseEnterName => 'Please enter your name';

  @override
  String get membershipTitle => 'Membership';
  @override
  String get howItWorks => 'How it works';
  @override
  String get history => 'History';
  @override
  String get noLoyaltyActivity =>
      'No activity yet. Place an order to start earning.';
  @override
  String michoUntilNextTier(int n) => '$n more Micho until next tier';
  @override
  String get topTier => "You're at the top tier — thank you!";
  @override
  String loyaltyHowText(String earn, String value) =>
      'Earn 1 Micho for every $earn you spend. '
      'Hold over 100 Micho to get 5% off every order.';

  @override
  String get orders => 'Orders';
  @override
  String get dashboard => 'Dashboard';
  @override
  String get refunds => 'Refunds';
  @override
  String get menuMgmt => 'Menu';
  @override
  String get customers => 'Customers';
  @override
  String get promoCodes => 'Promo codes';
  @override
  String get collections => 'Collections';
  @override
  String get threads => 'Threads';
  @override
  String get refresh => 'Refresh';
  @override
  String get kitchenQueue => 'Kitchen queue';
  @override
  String get kitchenBrand => 'Banan · Kitchen';
  @override
  String get productionBoard => 'Production board';
  @override
  String get analytics => 'Analytics';
  @override
  String get kanban => 'Kanban';
  @override
  String get kitchenAnalytics => 'Kitchen Analytics';
}
