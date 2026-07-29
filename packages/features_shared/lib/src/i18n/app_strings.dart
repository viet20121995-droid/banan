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

  // Product cards / badges (shared with design_system via parameters)
  String get fromLabel;
  String get soldOutBadge;
  String get pausedBadge;
  String get seasonalBadge;
  String stockLeft(int n);

  /// Product tags are stored in the DB in Vietnamese (the merchant editor's
  /// curated chips). Map the known ones for EN; unknown tags pass through.
  String localizeTag(String tag) => tag;

  // Menu / home extras
  String get menuOverline;
  String get menuSub;
  String get storyOverline;
  String get categoriesOverline;
  String get quickOverline;
  String get reorderTitle;
  String get reorderSub;
  String get reorderBtn;
  String orderCode(String code);
  String plusOtherItems(int n);
  String get chooseVariant;
  String get quantity;
  String get viewProductDetail;
  String get offlineMenuFresh;
  String offlineMenuAged(String age);
  String get justNow;
  String minutesAgo(int n);
  String hoursAgo(int n);
  String daysAgo(int n);
  String get pausedAll;
  String get pausedSome;
  String get pausedOrdersAll;
  String get pausePickup;
  String get pauseDelivery;
  String pausedKinds(String parts);
  String get bannerPrev;
  String get bannerNext;
  String get wholesaleTitle;
  String get genericError;

  // Newsletter
  String get newsletterTitle;
  String get newsletterSub;
  String get newsletterAlready;
  String get newsletterSent;
  String get subscribe;
  String get emailPlaceholder;

  // Footer
  String get footAbout;
  String get footLocations;
  String get footFaq;
  String get footContact;
  String get footPrivacy;
  String get footTerms;
  String get footShipping;
  String get footPayment;
  String get footRefund;
  String get footReferral;
  String get footGiftCards;
  String get footSubscription;
  String get footCatering;
  String get footRewards;
  String bizReg(String no);
  String bizAddress(String a);

  // Cookie consent
  String get cookieText;
  String get privacyPolicy;
  String get cookieEssential;
  String get cookieAcceptAll;

  // Cart extras
  String get viewMenu;
  String itemsCount(int n);
  String get feesAtCheckout;
  String get continueLabel;
  String get addressAtCheckout;
  String get itemsInCart;
  String get addToOrderTitle;
  String get youMayLike;
  String get add;
  String leadTimeChipH(int h);
  String onlyOnDays(String days);
  String get notPersonalized;
  String get personalize;
  String addedToOrder(String name);

  // Checkout extras
  String get giftInvalid;
  String get fillMissing;
  String get orderSuccess;
  String get mixedDaysError;
  String get addressHelperEx;
  String get cityHelper;
  String get giftCardCode;
  String giftApplied(String code, String balance, String deduct);
  String get vatTitle;
  String get vatOnSub;
  String get vatOffSub;
  String get companyName;
  String get taxCode;
  String get taxCodeHelper;
  String get companyAddress;
  String get invoiceEmail;
  String get giftTitle;
  String get giftOnSub;
  String get giftOffSub;
  String get giftMessage;
  String get giftMessageHint;
  String get giftRecipientName;
  String get giftRecipientHelper;
  String get giftRecipientPhone;
  String get giftPhoneHelper;
  String get giftWrap;
  String get hidePrices;
  String get hidePricesSub;
  String get useMicho;
  String michoBalanceApprox(String balance, String value);
  String get orderTooSmallPoints;
  String pointsChip(int v);
  String redeemPoints(int v, int max);
  String get clearSelection;
  String get ninepayLabel;
  String get decrease;
  String get increase;
  String get wardLabel;
  String get wardLoadError;
  String get wardHelper;
  String get chooseWard;
  String get chooseWardTitle;
  String get wardSearchHint;
  String get noWardMatch;
  String oldAreaLabel(String a);
  String feeError(String e);
  String get birthdayTier;
  String get regularTier;
  String get otherWard;
  String get sameWard;
  String deliverFrom(String store);
  String get noStoreForWard;
  String get estimatedFee;
  String feeBreakTier(String tier, String band);
  String get feeBirthdaySchedule;
  String feeDistanceKm(String km);
  String get feePickWard;
  String needLeadHours(int h);
  String onlySoldOnDays(String days);
  String get itemsDontFit;
  String get pickEarliest;
  String get removeThese;

  // Fulfillment widgets
  String get onBreak;
  String get useSavedAddress;
  String get someCakes;
  String andOthers(String list, int n);
  String onlySoldDaysNote(String who, String days);
  String leadDaysSpan(int n);
  String leadHoursSpan(int n);
  String leadNote(String who, String span);
  String readyAt(String t);
  String get choosePickupTime;
  String earliestAt(String t);
  String get pickupTimeLabel;
  String get noSlotsToday;
  String confirmTime(String t);
  String get today;
  String get change;

  // Product detail extras
  String variantStock(String label, int n);
  String variantSoldOut(String label);
  String almostGone(int n);
  String chooseNFlavors(int n);
  String get reviewsTitle;
  String reviewsLoadError(String e);
  String get noReviewsYet;
  String reviewsCount(int n);
  String get anonymousCustomer;
  String get alsoBought;
  String get personalizedCake;
  String get personalizeCake;
  String get personalizeSub;

  /// Short weekday label, 0=Sunday..6=Saturday ("CN"/"T2" — "Sun"/"Mon").
  String weekdayShort(int d);

  // Wishlist
  String get wishlistTitle;
  String get wishlistLoginTitle;
  String get wishlistLoginMsg;
  String get wishlistEmptyTitle;
  String get wishlistEmptyMsg;
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

  @override
  String get fromLabel => 'Từ';
  @override
  String get soldOutBadge => 'Hết hàng';
  @override
  String get pausedBadge => 'Tạm ngưng';
  @override
  String get seasonalBadge => 'Theo mùa';
  @override
  String stockLeft(int n) => 'Còn $n';

  @override
  String get menuOverline => 'Thực đơn';
  @override
  String get menuSub =>
      'Mỗi mẻ bánh ra lò tươi mỗi ngày trong các cửa hàng Banan.';
  @override
  String get storyOverline => 'Câu chuyện';
  @override
  String get categoriesOverline => 'Danh mục';
  @override
  String get quickOverline => 'Nhanh gọn';
  @override
  String get reorderTitle => '🔁 Đặt lại';
  @override
  String get reorderSub => 'Thêm lại nhanh những món bạn đã đặt gần đây.';
  @override
  String get reorderBtn => 'Đặt lại';
  @override
  String orderCode(String code) => 'Đơn $code';
  @override
  String plusOtherItems(int n) => '+$n món khác';
  @override
  String get chooseVariant => 'Chọn phiên bản';
  @override
  String get quantity => 'Số lượng';
  @override
  String get viewProductDetail => 'Xem chi tiết sản phẩm';
  @override
  String get offlineMenuFresh =>
      'Bạn đang offline. Đang hiển thị thực đơn đã tải gần nhất.';
  @override
  String offlineMenuAged(String age) =>
      'Bạn đang offline. Thực đơn đã cũ $age.';
  @override
  String get justNow => 'vừa xong';
  @override
  String minutesAgo(int n) => '$n phút trước';
  @override
  String hoursAgo(int n) => '$n giờ trước';
  @override
  String daysAgo(int n) => '$n ngày trước';
  @override
  String get pausedAll => 'Toàn hệ thống đang tạm ngừng nhận đơn';
  @override
  String get pausedSome => 'Một số chi nhánh đang tạm dừng';
  @override
  String get pausedOrdersAll => 'tạm dừng nhận đơn';
  @override
  String get pausePickup => 'tự lấy';
  @override
  String get pauseDelivery => 'giao hàng';
  @override
  String pausedKinds(String parts) => 'tạm dừng $parts';
  @override
  String get bannerPrev => 'Banner trước';
  @override
  String get bannerNext => 'Banner kế tiếp';
  @override
  String get wholesaleTitle => 'Đặt sỉ';
  @override
  String get genericError => 'Có lỗi xảy ra, vui lòng thử lại.';

  @override
  String get newsletterTitle => 'Nhận khuyến mãi từ Banan';
  @override
  String get newsletterSub =>
      'Đăng ký email để nhận thông tin bánh mới + ưu đãi mùa lễ. '
      'Tối đa 2 email mỗi tháng, không spam.';
  @override
  String get newsletterAlready => 'Bạn đã đăng ký rồi, cảm ơn!';
  @override
  String get newsletterSent => 'Đã gửi email xác nhận, mời kiểm tra hộp thư.';
  @override
  String get subscribe => 'Đăng ký';
  @override
  String get emailPlaceholder => 'ban@email.com';

  @override
  String get footAbout => 'Về Banan';
  @override
  String get footLocations => 'Chi nhánh';
  @override
  String get footFaq => 'Câu hỏi thường gặp';
  @override
  String get footContact => 'Liên hệ';
  @override
  String get footPrivacy => 'Chính sách bảo mật';
  @override
  String get footTerms => 'Điều khoản';
  @override
  String get footShipping => 'Vận chuyển & giao nhận';
  @override
  String get footPayment => 'Thanh toán';
  @override
  String get footRefund => 'Đổi trả & hoàn tiền';
  @override
  String get footReferral => 'Giới thiệu bạn';
  @override
  String get footGiftCards => 'Thẻ quà tặng';
  @override
  String get footSubscription => 'Gói định kỳ';
  @override
  String get footCatering => 'Đặt tiệc';
  @override
  String get footRewards => 'Đổi điểm';
  @override
  String bizReg(String no) => 'ĐKKD: $no';
  @override
  String bizAddress(String a) => 'Địa chỉ: $a';

  @override
  String get cookieText =>
      'Chúng tôi dùng cookie cần thiết để website hoạt động. '
      'Bạn có thể chọn bật thêm cookie phân tích. Xem ';
  @override
  String get privacyPolicy => 'Chính sách bảo mật';
  @override
  String get cookieEssential => 'Chỉ cần thiết';
  @override
  String get cookieAcceptAll => 'Chấp nhận tất cả';

  @override
  String get viewMenu => 'Xem thực đơn';
  @override
  String itemsCount(int n) => '$n món';
  @override
  String get feesAtCheckout => 'Phí giao & khuyến mãi tính ở bước thanh toán';
  @override
  String get continueLabel => 'Tiếp tục';
  @override
  String get addressAtCheckout => 'Bạn sẽ nhập địa chỉ ở bước thanh toán.';
  @override
  String get itemsInCart => 'Món trong giỏ';
  @override
  String get addToOrderTitle => 'Thêm vào đơn 🧁';
  @override
  String get youMayLike => 'Có thể bạn cũng thích';
  @override
  String get add => 'Thêm';
  @override
  String leadTimeChipH(int h) => 'Đặt trước ${h}h';
  @override
  String onlyOnDays(String days) => 'Chỉ bán $days';
  @override
  String get notPersonalized => 'Chưa cá nhân hoá';
  @override
  String get personalize => 'Cá nhân hoá';
  @override
  String addedToOrder(String name) => 'Đã thêm $name vào đơn.';

  @override
  String get giftInvalid => 'Mã không hợp lệ, đã hết hạn hoặc hết số dư.';
  @override
  String get fillMissing =>
      'Vui lòng điền đầy đủ các thông tin còn thiếu phía trên.';
  @override
  String get orderSuccess =>
      'Đặt hàng thành công! Chúng tôi sẽ liên hệ xác nhận đơn của bạn.';
  @override
  String get mixedDaysError =>
      'Các món trong giỏ không bán cùng một ngày. Vui lòng bỏ bớt món để '
      'đặt được, hoặc tách thành nhiều đơn.';
  @override
  String get addressHelperEx => 'VD: 15B8 Lê Thánh Tôn';
  @override
  String get cityHelper => 'Hiện Banan chỉ giao trong TP.HCM';
  @override
  String get giftCardCode => 'Mã thẻ quà tặng';
  @override
  String giftApplied(String code, String balance, String deduct) =>
      'Thẻ $code · số dư $balance · trừ $deduct vào đơn này.';
  @override
  String get vatTitle => 'Xuất hoá đơn VAT (hoá đơn đỏ)';
  @override
  String get vatOnSub => 'Hoá đơn sẽ được gửi qua email sau khi đơn hoàn tất.';
  @override
  String get vatOffSub => 'Bật khi cần hoá đơn cho công ty.';
  @override
  String get companyName => 'Tên công ty';
  @override
  String get taxCode => 'Mã số thuế';
  @override
  String get taxCodeHelper => '8–13 chữ số.';
  @override
  String get companyAddress => 'Địa chỉ công ty';
  @override
  String get invoiceEmail => 'Email nhận hoá đơn';
  @override
  String get giftTitle => '🎁 Gửi tặng / Đây là quà tặng';
  @override
  String get giftOnSub => 'Kèm thiệp chúc, người nhận và tuỳ chọn gói quà.';
  @override
  String get giftOffSub => 'Bật khi bạn muốn gửi đơn này làm quà tặng.';
  @override
  String get giftMessage => 'Lời chúc';
  @override
  String get giftMessageHint => 'Lời chúc gửi kèm thiệp…';
  @override
  String get giftRecipientName => 'Tên người nhận';
  @override
  String get giftRecipientHelper =>
      'Người sẽ nhận món quà này (không bắt buộc).';
  @override
  String get giftRecipientPhone => 'SĐT người nhận';
  @override
  String get giftPhoneHelper =>
      'Để shipper liên hệ người nhận (không bắt buộc).';
  @override
  String get giftWrap => 'Gói quà / hộp quà';
  @override
  String get hidePrices => 'Ẩn giá trên phiếu giao';
  @override
  String get hidePricesSub => 'Người nhận sẽ không thấy giá tiền.';
  @override
  String get useMicho => 'Dùng điểm Micho';
  @override
  String michoBalanceApprox(String balance, String value) =>
      'Bạn có $balance điểm (≈ $value)';
  @override
  String get orderTooSmallPoints => 'Giá trị đơn hàng chưa đủ để đổi điểm.';
  @override
  String pointsChip(int v) => '$v điểm';
  @override
  String redeemPoints(int v, int max) => 'Đổi $v/$max điểm';
  @override
  String get clearSelection => 'Bỏ chọn';
  @override
  String get ninepayLabel => 'Quét QR / Thẻ / Chuyển khoản (9Pay)';
  @override
  String get decrease => 'Giảm';
  @override
  String get increase => 'Tăng';
  @override
  String get wardLabel => 'Phường (TP.HCM)';
  @override
  String get wardLoadError => 'Không tải được danh sách phường';
  @override
  String get wardHelper =>
      'Sau cải cách 7/2025, chọn phường để tính phí giao hàng';
  @override
  String get chooseWard => 'Chọn phường…';
  @override
  String get chooseWardTitle => 'Chọn phường (TP.HCM)';
  @override
  String get wardSearchHint => 'Tìm theo tên phường hoặc quận cũ';
  @override
  String get noWardMatch => 'Không tìm thấy phường khớp.';
  @override
  String oldAreaLabel(String a) => 'Quận/khu vực cũ: $a';
  @override
  String feeError(String e) => 'Không tính được phí: $e';
  @override
  String get birthdayTier => 'Bánh sinh nhật';
  @override
  String get regularTier => 'Sản phẩm thường';
  @override
  String get otherWard => 'phường khác';
  @override
  String get sameWard => 'cùng phường';
  @override
  String deliverFrom(String store) => 'Giao từ: $store';
  @override
  String get noStoreForWard =>
      'Hiện không có cửa hàng nào nhận giao hàng tới phường này.';
  @override
  String get estimatedFee => 'Phí giao hàng dự kiến';
  @override
  String feeBreakTier(String tier, String band) =>
      '• Phân loại: $tier · $band';
  @override
  String get feeBirthdaySchedule =>
      '• Đơn có bánh sinh nhật, áp dụng biểu phí riêng';
  @override
  String feeDistanceKm(String km) =>
      '• Khoảng cách từ cửa hàng đến phường: $km';
  @override
  String get feePickWard => '• Chọn phường ở trên để tính chính xác';
  @override
  String needLeadHours(int h) => 'cần đặt trước $h giờ';
  @override
  String onlySoldOnDays(String days) => 'chỉ bán $days';
  @override
  String get itemsDontFit => 'Một số món không kịp thời gian bạn chọn';
  @override
  String get pickEarliest => 'Chọn giờ sớm nhất phù hợp';
  @override
  String get removeThese => 'Xoá các món này';

  @override
  String get onBreak => 'Đang tạm nghỉ';
  @override
  String get useSavedAddress => 'Dùng địa chỉ đã lưu';
  @override
  String get someCakes => 'Một số bánh';
  @override
  String andOthers(String list, int n) => '$list và $n món khác';
  @override
  String onlySoldDaysNote(String who, String days) =>
      '$who chỉ bán vào $days, lịch nhận chỉ hiện các ngày này.';
  @override
  String leadDaysSpan(int n) => '$n ngày';
  @override
  String leadHoursSpan(int n) => '$n giờ';
  @override
  String leadNote(String who, String span) =>
      '$who cần đặt trước $span để chuẩn bị. Chúng tôi đã chọn sẵn '
      'thời gian nhận sớm nhất. Bạn có thể đổi sang giờ muộn hơn.';
  @override
  String readyAt(String t) => 'Dự kiến sẵn sàng lúc $t';
  @override
  String get choosePickupTime => 'Chọn giờ nhận';
  @override
  String earliestAt(String t) => 'Sớm nhất: $t';
  @override
  String get pickupTimeLabel => 'Giờ nhận';
  @override
  String get noSlotsToday =>
      'Hết khung giờ nhận trong ngày này. Vui lòng chọn ngày khác.';
  @override
  String confirmTime(String t) => 'Xác nhận $t';
  @override
  String get today => 'Hôm nay';
  @override
  String get change => 'Đổi';

  @override
  String variantStock(String label, int n) => '$label · còn $n';
  @override
  String variantSoldOut(String label) => '$label · hết hàng';
  @override
  String almostGone(int n) => 'Sắp hết, còn $n cái';
  @override
  String chooseNFlavors(int n) => 'Chọn đủ $n vị';
  @override
  String get reviewsTitle => 'Đánh giá';
  @override
  String reviewsLoadError(String e) => 'Không tải được đánh giá: $e';
  @override
  String get noReviewsYet =>
      'Chưa có đánh giá nào. Hãy là người đầu tiên đánh giá '
      'sản phẩm sau khi nhận hàng nhé.';
  @override
  String reviewsCount(int n) => '· $n đánh giá';
  @override
  String get anonymousCustomer => 'Khách hàng';
  @override
  String get alsoBought => 'Khách cũng mua';
  @override
  String get personalizedCake => 'Đã cá nhân hoá bánh';
  @override
  String get personalizeCake => 'Cá nhân hoá bánh';
  @override
  String get personalizeSub => 'Chữ trên bánh, số nến, ảnh tham khảo, ghi chú …';

  @override
  String weekdayShort(int d) =>
      const {0: 'CN', 1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7'}[d] ??
      '?$d';

  @override
  String get wishlistTitle => 'Yêu thích';
  @override
  String get wishlistLoginTitle => 'Đăng nhập để lưu yêu thích';
  @override
  String get wishlistLoginMsg =>
      'Đăng nhập để giữ danh sách bánh yêu thích đồng bộ giữa các thiết bị.';
  @override
  String get wishlistEmptyTitle => 'Chưa có sản phẩm yêu thích';
  @override
  String get wishlistEmptyMsg => 'Bấm trái tim trên bánh bạn thích để lưu lại.';
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

  static const _tagEn = <String, String>{
    'Không gluten': 'Gluten-free',
    'Thuần chay': 'Vegan',
    'Không sữa': 'Dairy-free',
    'Không trứng': 'Egg-free',
    'Không hạt': 'Nut-free',
    'Không đường': 'Sugar-free',
    'Ít ngọt': 'Less sweet',
    'Halal': 'Halal',
    'Hữu cơ': 'Organic',
    'Bán chạy': 'Best seller',
    'Mới': 'New',
    'Đầu bếp gợi ý': "Chef's pick",
    'Giới hạn': 'Limited',
  };

  @override
  String localizeTag(String tag) => _tagEn[tag] ?? tag;

  @override
  String get fromLabel => 'From';
  @override
  String get soldOutBadge => 'Sold out';
  @override
  String get pausedBadge => 'Unavailable';
  @override
  String get seasonalBadge => 'Seasonal';
  @override
  String stockLeft(int n) => '$n left';

  @override
  String get menuOverline => 'Menu';
  @override
  String get menuSub => 'Every batch baked fresh daily in Banan stores.';
  @override
  String get storyOverline => 'Our story';
  @override
  String get categoriesOverline => 'Categories';
  @override
  String get quickOverline => 'Quick';
  @override
  String get reorderTitle => '🔁 Reorder';
  @override
  String get reorderSub => 'Quickly re-add items from your recent orders.';
  @override
  String get reorderBtn => 'Reorder';
  @override
  String orderCode(String code) => 'Order $code';
  @override
  String plusOtherItems(int n) => '+$n more';
  @override
  String get chooseVariant => 'Choose a variant';
  @override
  String get quantity => 'Quantity';
  @override
  String get viewProductDetail => 'View product details';
  @override
  String get offlineMenuFresh =>
      'You are offline. Showing the last loaded menu.';
  @override
  String offlineMenuAged(String age) => 'You are offline. Menu is $age old.';
  @override
  String get justNow => 'just now';
  @override
  String minutesAgo(int n) => '$n min ago';
  @override
  String hoursAgo(int n) => '$n h ago';
  @override
  String daysAgo(int n) => '$n d ago';
  @override
  String get pausedAll => 'Ordering is temporarily paused system-wide';
  @override
  String get pausedSome => 'Some branches are temporarily paused';
  @override
  String get pausedOrdersAll => 'orders paused';
  @override
  String get pausePickup => 'pickup';
  @override
  String get pauseDelivery => 'delivery';
  @override
  String pausedKinds(String parts) => '$parts paused';
  @override
  String get bannerPrev => 'Previous banner';
  @override
  String get bannerNext => 'Next banner';
  @override
  String get wholesaleTitle => 'Wholesale';
  @override
  String get genericError => 'Something went wrong, please try again.';

  @override
  String get newsletterTitle => 'Get Banan offers';
  @override
  String get newsletterSub =>
      'Sign up for new cakes + seasonal offers. '
      'At most 2 emails a month, no spam.';
  @override
  String get newsletterAlready => 'You are already subscribed — thank you!';
  @override
  String get newsletterSent =>
      'Confirmation email sent — please check your inbox.';
  @override
  String get subscribe => 'Subscribe';
  @override
  String get emailPlaceholder => 'you@email.com';

  @override
  String get footAbout => 'About Banan';
  @override
  String get footLocations => 'Locations';
  @override
  String get footFaq => 'FAQ';
  @override
  String get footContact => 'Contact';
  @override
  String get footPrivacy => 'Privacy policy';
  @override
  String get footTerms => 'Terms';
  @override
  String get footShipping => 'Shipping & delivery';
  @override
  String get footPayment => 'Payment';
  @override
  String get footRefund => 'Returns & refunds';
  @override
  String get footReferral => 'Refer a friend';
  @override
  String get footGiftCards => 'Gift cards';
  @override
  String get footSubscription => 'Subscriptions';
  @override
  String get footCatering => 'Catering';
  @override
  String get footRewards => 'Rewards';
  @override
  String bizReg(String no) => 'Business reg. no.: $no';
  @override
  String bizAddress(String a) => 'Address: $a';

  @override
  String get cookieText =>
      'We use essential cookies to run this website. '
      'You can opt in to analytics cookies. See our ';
  @override
  String get privacyPolicy => 'Privacy policy';
  @override
  String get cookieEssential => 'Essential only';
  @override
  String get cookieAcceptAll => 'Accept all';

  @override
  String get viewMenu => 'Browse the menu';
  @override
  String itemsCount(int n) => '$n items';
  @override
  String get feesAtCheckout =>
      'Delivery fees & promotions are calculated at checkout';
  @override
  String get continueLabel => 'Continue';
  @override
  String get addressAtCheckout => 'You will enter the address at checkout.';
  @override
  String get itemsInCart => 'Items in your cart';
  @override
  String get addToOrderTitle => 'Add to your order 🧁';
  @override
  String get youMayLike => 'You might also like';
  @override
  String get add => 'Add';
  @override
  String leadTimeChipH(int h) => '${h}h notice';
  @override
  String onlyOnDays(String days) => 'Only on $days';
  @override
  String get notPersonalized => 'Not personalized';
  @override
  String get personalize => 'Personalize';
  @override
  String addedToOrder(String name) => 'Added $name to your order.';

  @override
  String get giftInvalid => 'Code invalid, expired, or out of balance.';
  @override
  String get fillMissing => 'Please fill in the missing details above.';
  @override
  String get orderSuccess =>
      'Order placed! We will contact you to confirm it.';
  @override
  String get mixedDaysError =>
      'Items in your cart are not sold on the same day. Remove some items '
      'or split them into separate orders.';
  @override
  String get addressHelperEx => 'e.g. 15B8 Le Thanh Ton';
  @override
  String get cityHelper => 'Banan currently delivers within HCMC only';
  @override
  String get giftCardCode => 'Gift card code';
  @override
  String giftApplied(String code, String balance, String deduct) =>
      'Card $code · balance $balance · $deduct applied to this order.';
  @override
  String get vatTitle => 'VAT invoice (red invoice)';
  @override
  String get vatOnSub =>
      'The invoice will be emailed once the order completes.';
  @override
  String get vatOffSub => 'Turn on if you need a company invoice.';
  @override
  String get companyName => 'Company name';
  @override
  String get taxCode => 'Tax code';
  @override
  String get taxCodeHelper => '8–13 digits.';
  @override
  String get companyAddress => 'Company address';
  @override
  String get invoiceEmail => 'Invoice email';
  @override
  String get giftTitle => '🎁 This is a gift';
  @override
  String get giftOnSub =>
      'Add a card message, a recipient, and optional gift wrap.';
  @override
  String get giftOffSub => 'Turn on to send this order as a gift.';
  @override
  String get giftMessage => 'Card message';
  @override
  String get giftMessageHint => 'Message to include on the card…';
  @override
  String get giftRecipientName => 'Recipient name';
  @override
  String get giftRecipientHelper => 'Who receives this gift (optional).';
  @override
  String get giftRecipientPhone => 'Recipient phone';
  @override
  String get giftPhoneHelper =>
      'So the courier can reach the recipient (optional).';
  @override
  String get giftWrap => 'Gift wrap / gift box';
  @override
  String get hidePrices => 'Hide prices on the delivery slip';
  @override
  String get hidePricesSub => 'The recipient will not see any prices.';
  @override
  String get useMicho => 'Use Micho points';
  @override
  String michoBalanceApprox(String balance, String value) =>
      'You have $balance points (≈ $value)';
  @override
  String get orderTooSmallPoints =>
      'Order value is too small to redeem points.';
  @override
  String pointsChip(int v) => '$v pts';
  @override
  String redeemPoints(int v, int max) => 'Redeem $v/$max points';
  @override
  String get clearSelection => 'Clear';
  @override
  String get ninepayLabel => 'QR / Card / Bank transfer (9Pay)';
  @override
  String get decrease => 'Decrease';
  @override
  String get increase => 'Increase';
  @override
  String get wardLabel => 'Ward (HCMC)';
  @override
  String get wardLoadError => 'Could not load the ward list';
  @override
  String get wardHelper => 'Pick a ward to calculate the delivery fee';
  @override
  String get chooseWard => 'Choose a ward…';
  @override
  String get chooseWardTitle => 'Choose a ward (HCMC)';
  @override
  String get wardSearchHint => 'Search by ward or former district';
  @override
  String get noWardMatch => 'No matching ward.';
  @override
  String oldAreaLabel(String a) => 'Former district: $a';
  @override
  String feeError(String e) => 'Could not calculate the fee: $e';
  @override
  String get birthdayTier => 'Birthday cake';
  @override
  String get regularTier => 'Regular items';
  @override
  String get otherWard => 'different ward';
  @override
  String get sameWard => 'same ward';
  @override
  String deliverFrom(String store) => 'Ships from: $store';
  @override
  String get noStoreForWard => 'No store currently delivers to this ward.';
  @override
  String get estimatedFee => 'Estimated delivery fee';
  @override
  String feeBreakTier(String tier, String band) => '• Type: $tier · $band';
  @override
  String get feeBirthdaySchedule =>
      '• Contains a birthday cake — a separate fee table applies';
  @override
  String feeDistanceKm(String km) => '• Distance from store to ward: $km';
  @override
  String get feePickWard => '• Pick a ward above for an exact fee';
  @override
  String needLeadHours(int h) => 'needs $h hours notice';
  @override
  String onlySoldOnDays(String days) => 'only sold on $days';
  @override
  String get itemsDontFit => 'Some items do not fit the time you chose';
  @override
  String get pickEarliest => 'Pick the earliest suitable time';
  @override
  String get removeThese => 'Remove these items';

  @override
  String get onBreak => 'On a break right now';
  @override
  String get useSavedAddress => 'Use a saved address';
  @override
  String get someCakes => 'Some cakes';
  @override
  String andOthers(String list, int n) => '$list and $n more';
  @override
  String onlySoldDaysNote(String who, String days) =>
      '$who only sold on $days — the schedule shows those days only.';
  @override
  String leadDaysSpan(int n) => '$n days';
  @override
  String leadHoursSpan(int n) => '$n hours';
  @override
  String leadNote(String who, String span) =>
      '$who needs $span notice to prepare. We picked the earliest slot — '
      'you can switch to a later one.';
  @override
  String readyAt(String t) => 'Estimated ready at $t';
  @override
  String get choosePickupTime => 'Choose a time';
  @override
  String earliestAt(String t) => 'Earliest: $t';
  @override
  String get pickupTimeLabel => 'Time';
  @override
  String get noSlotsToday =>
      'No slots left on this day. Please pick another day.';
  @override
  String confirmTime(String t) => 'Confirm $t';
  @override
  String get today => 'Today';
  @override
  String get change => 'Change';

  @override
  String variantStock(String label, int n) => '$label · $n left';
  @override
  String variantSoldOut(String label) => '$label · sold out';
  @override
  String almostGone(int n) => 'Almost gone — $n left';
  @override
  String chooseNFlavors(int n) => 'Pick $n flavors';
  @override
  String get reviewsTitle => 'Reviews';
  @override
  String reviewsLoadError(String e) => 'Could not load reviews: $e';
  @override
  String get noReviewsYet =>
      'No reviews yet. Be the first to review this product '
      'after your order arrives.';
  @override
  String reviewsCount(int n) => '· $n reviews';
  @override
  String get anonymousCustomer => 'Customer';
  @override
  String get alsoBought => 'Customers also bought';
  @override
  String get personalizedCake => 'Cake personalized';
  @override
  String get personalizeCake => 'Personalize this cake';
  @override
  String get personalizeSub =>
      'Message on the cake, candles, reference photo, notes…';

  @override
  String weekdayShort(int d) =>
      const {
        0: 'Sun',
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
      }[d] ??
      '?$d';

  @override
  String get wishlistTitle => 'Wishlist';
  @override
  String get wishlistLoginTitle => 'Sign in to save favorites';
  @override
  String get wishlistLoginMsg =>
      'Sign in to keep your favorite cakes synced across devices.';
  @override
  String get wishlistEmptyTitle => 'No favorites yet';
  @override
  String get wishlistEmptyMsg =>
      'Tap the heart on a cake you love to save it here.';
}
