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

/// Vietnamese table as a const default for call sites without a ref
/// (helpers shared with the VI-only staff apps).
const AppStrings viStrings = _Vi();

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

  // Auth screens
  String get backToShop;
  String get forgotPasswordQ;
  String get optionalSuffix;
  String get pwMin8;
  String get welcomeBack;
  String get helloThere;
  String get overlayHaveAccount;
  String get overlayNoAccount;
  String get birthdayHelp;
  String get birthdayOptional;
  String get birthdayPerk;
  String get tapToPick;
  String get forgotTitle;
  String get forgotIntro;
  String get forgotSent;
  String get pleaseEnterEmail;
  String get sendResetLink;
  String get resetTitle;
  String get resetLinkInvalid;
  String get requestNewLink;
  String get resetDone;
  String get resetIntro;
  String get newPassword;
  String get confirmNewPassword;
  String get pwMismatch;
  String get changePasswordTitle;
  String get passwordChanged;
  String get currentPassword;
  String get pleaseEnterCurrentPw;
  String get changeEmailTitle;
  String get linkInvalidExpired;
  String get confirmingEmailChange;
  String get emailChanged;

  // Auth failure messages
  String get authErrInvalidCredentials;
  String get authErrForbidden;
  String get authErrSessionExpired;
  String get authErrCheckInfo;
  String get authErrNetwork;
  String get authErrEmailTaken;
  String get authErrGeneric;

  // Orders list
  String get filterProcessing;
  String get filterCompleted;
  String get filterCancelled;
  String get noOrdersInFilterTitle;
  String noOrdersInFilter(String f);
  String get reorderShort;

  // Order detail
  String kitchenBadge(String label);
  String kitchenStatusLabel(KitchenStatus s);
  String paymentStatusLabel(PaymentStatus s);
  String refundStatusLabel(RefundStatus s);
  String paymentMethodLabel(PaymentMethod m);
  String get reorderThisOrder;
  String get scheduledFor;
  String get scheduleWas;
  String get prepKitchenHeadline;
  String get prepCounterHeadline;
  String get prepCounterDetail;
  String get kitchenDetailPending;
  String get kitchenDetailPreparing;
  String get kitchenDetailReady;
  String get kitchenDetailUnknown;
  String get stepPlaced;
  String get stepAccepted;
  String get stepKitchen;
  String get stepCounter;
  String get stepOnTheWay;
  String get stepReady;
  String get stepCompleted;
  String get refundLabel;
  String get reviewProduct;
  String editReview(int rating);
  String reviewTitleFor(String name);
  String get reviewShareOptional;
  String get reviewHelper;
  String get submitReview;
  String get update;
  String get vatInvoiceInfo;
  String taxIdShort(String x);
  String get giftOrder;
  String get giftWrapBadge;
  String get giftRecipientLabel;
  String get hidePriceNote;
  String get personalization;
  String textOnCakeLine(String text);
  String candleLine(String c);
  String flavorLine(String f);
  String noteLine(String n);

  // Reorder helper
  String get reorderUnavailable;
  String reorderAdded(int n);
  String reorderAddedSkipped(int n, int k);

  // Profile
  String get changeAvatar;
  String get uploadingPhoto;
  String avatarTooBig(int mb);
  String avatarBigWarn(int mb);
  String get avatarUpdated;
  String get uploadFailed;
  String get emailChangeLinkSent;
  String get genderLabel;
  String genderName(Gender g);
  String get wishlistSub;
  String get voucherWallet;
  String get voucherWalletSub;
  String get changePasswordSub;
  String get changeEmailSub;
  String get marketingOptIn;
  String get marketingOptInSub;
  String get orderUpdatesOptIn;
  String get orderUpdatesOptInSub;
  String get deleteAccount;
  String get changeEmailIntro;
  String get newEmail;
  String get pleaseEnterNewEmail;
  String get emailTaken;
  String get wrongPassword;
  String get emailInvalidOrSame;
  String get sendConfirmLink;
  String get deleteAccountWarn;
  String get pleaseEnterPwConfirm;
  String get deleteForever;

  // Addresses
  String get deliveryOnlyHcm;
  String get wardReformHelper;

  // Voucher wallet
  String get tabAvailable;
  String get tabUsed;
  String get tabExpired;
  String get noVoucherTitle;
  String get noVoucherAvailable;
  String get noVoucherUsed;
  String get noVoucherExpired;
  String discountPercent(String p);
  String discountAmount(String a);
  String codeCopied(String code);
  String get copyCode;
  String minOrder(String a);
  String usedOn(String d);
  String expiresOn(String d);

  // Membership
  String tierName(MembershipTier t);
  String tierHeading(String name);
  String get memberTiers;
  String get currentBadge;
  String fromPoints(String n);
  String pointsToTier(int n, String tier);
  String loyaltyTypeLabel(LoyaltyEventType t);

  // Wholesale
  String get whTitle;
  String get whTabOrder;
  String get whTabMyOrders;
  String get whTabDebts;
  String get whPickAtLeastOne;
  String get whNeedDeliveryDate;
  String whOrderPlaced(String code);
  String get whNotAllowed;
  String get whNoContractsTitle;
  String get whNoContractsMsg;
  String whMinOrderValue(String a);
  String whContractPrice(String a);
  String whMinQty(int n);
  String whMultipleQty(int n);
  String whOnlyDeliverOn(String days);
  String whLeadDays(int n);
  String whLeadHours(int n);
  String get whPickDateRequired;
  String get whPickDate;
  String whDeliverAt(String t);
  String whCutoffNote(String hhmm);
  String whNoDeliveryOn(String days);
  String get whPoLabel;
  String get whPoHelper;
  String get whOrderNotes;
  String whShipFee(String a);
  String whSubmit(String a);
  String get whNoOrders;
  String get whNoOrdersMsg;
  String whStatusLabel(String status);
  String get whNoDebtsTitle;
  String get whNoDebtsMsg;
  String get whOrderFallback;
  String get whDebtStartsAfterConfirm;
  String whDueDate(String d);
  String whDebtStatusLabel(String status, {required bool overdue});

  // Cake wizard
  String candleRegular(int n);
  String candleSpiral(int n);
  String candleNumber(int n);
  String get noteWord;
  String wizTitle(String name);
  String get wizIntro;
  String get wizTextOnCake;
  String get wizTextHint;
  String get wizCandles;
  String get wizCandleType;
  String get wizNoCandles;
  String get wizRegularCandles;
  String get wizNumberCandles;
  String get wizSpiralCandles;
  String get wizSpiralCount;
  String get wizCandleCount;
  String get wizAge;
  String get wizAgeHelper;
  String get wizNote;
  String get wizNoteHint;
  String get wizClear;

  // Flavor composer
  String get flavorPickTitle;
  String flavorPicked(int n, int total);
  String get flavorComplete;
  String flavorRemaining(int n);

  // Bundles
  String get viewCartShort;
  String get comboTitle;
  String get bundleIncludes;
  String get addComboToCart;
  String addedCombo(String name);
  String get productFallback;
  String bundleQty(int n);
  String saveAmount(String a);
  String get bundlesOverline;
  String get bundlesTitle;
  String get bundlesSub;
  String get allBundlesTitle;
  String get allBundlesSub;

  // Contact FAB
  String get contactTitle;
  String get needHelp;
  String get contactSub;
  String get zaloSub;
  String get messengerSub;
  String get callDirect;
  String get sendEmail;

  // Promo popup
  String get promoClose;
  String promoAutoClose(int sec);

  // Payment return
  String get paymentReceived;
  String get paymentProcessing;

  // Contact page
  String get contactHeading;
  String get contactIntro;
  String get sendMessageTitle;
  String get nameReq;
  String get enterName;
  String get emailReq;
  String get subjectLabel;
  String get messageReq;
  String get enterMessage;
  String get sending;
  String get sendMessageBtn;
  String get sendFailed;
  String get sentTitle;
  String get sentThanks;
  String get sendAnother;

  // FAQ / About
  String get faqTitle;
  String get faqNotFound;
  String get aboutTitle;
  String get viewLocations;

  // Marketing pages
  String get programNotOpen;
  String get programNotOpenMsg;
  String get loadFailed;
  String get referralTitle;
  String get referralLoginPrompt;
  String referralBonus(int referrer, int referee);
  String get referralCodeLabel;
  String get shareLinkLabel;
  String get copyLabel;
  String get copied;
  String get giftCardTitle;
  String get giftCardHeading;
  String giftCardExpiry(int months);
  String get contactToBuyGiftCard;
  String get subscriptionTitle;
  String get subscriptionHeading;
  String perPeriod(String p);
  String get contactToSubscribe;
  String get cateringTitle;
  String get cateringHeading;
  String get cateringSentTitle;
  String get cateringSentMsg;
  String cateringMinLead(int minGuests, int leadDays);
  String get fillNamePhoneContent;
  String get phoneReq;
  String get emailOptionalLabel;
  String get contentHintCatering;
  String get sendRequest;
  String get rewardsTitle;
  String yourPoints(int n);
  String get noRewards;
  String rewardPoints(int n);
  String get redeemWord;
  String get notEnough;
  String get rewardsNote;
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

  // Auth screens
  @override
  String get backToShop => 'Quay lại cửa hàng';
  @override
  String get forgotPasswordQ => 'Quên mật khẩu?';
  @override
  String get optionalSuffix => 'tuỳ chọn';
  @override
  String get pwMin8 => 'Mật khẩu phải có ít nhất 8 ký tự';
  @override
  String get welcomeBack => 'Chào mừng trở lại!';
  @override
  String get helloThere => 'Xin chào!';
  @override
  String get overlayHaveAccount =>
      'Đã có tài khoản? Đăng nhập để tiếp tục đặt bánh.';
  @override
  String get overlayNoAccount =>
      'Chưa có tài khoản? Đăng ký để tích điểm và đặt nhanh hơn.';
  @override
  String get birthdayHelp => 'Ngày sinh của bạn';
  @override
  String get birthdayOptional => 'Ngày sinh (tuỳ chọn)';
  @override
  String get birthdayPerk => 'Tặng bạn ưu đãi mỗi dịp sinh nhật.';
  @override
  String get tapToPick => 'Chạm để chọn…';
  @override
  String get forgotTitle => 'Quên mật khẩu';
  @override
  String get forgotIntro =>
      'Nhập email của bạn và chúng tôi sẽ gửi liên kết đặt lại mật khẩu.';
  @override
  String get forgotSent =>
      'Nếu email tồn tại trong hệ thống, chúng tôi đã gửi liên kết đặt lại '
      'mật khẩu. Vui lòng kiểm tra hộp thư.';
  @override
  String get pleaseEnterEmail => 'Vui lòng nhập email';
  @override
  String get sendResetLink => 'Gửi liên kết đặt lại';
  @override
  String get resetTitle => 'Đặt lại mật khẩu';
  @override
  String get resetLinkInvalid =>
      'Liên kết không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu liên '
      'kết đặt lại mật khẩu mới.';
  @override
  String get requestNewLink => 'Yêu cầu liên kết mới';
  @override
  String get resetDone =>
      'Đặt lại mật khẩu thành công. Bạn có thể đăng nhập bằng mật khẩu mới.';
  @override
  String get resetIntro => 'Nhập mật khẩu mới cho tài khoản của bạn.';
  @override
  String get newPassword => 'Mật khẩu mới';
  @override
  String get confirmNewPassword => 'Xác nhận mật khẩu mới';
  @override
  String get pwMismatch => 'Mật khẩu xác nhận không khớp';
  @override
  String get changePasswordTitle => 'Đổi mật khẩu';
  @override
  String get passwordChanged => 'Đã đổi mật khẩu';
  @override
  String get currentPassword => 'Mật khẩu hiện tại';
  @override
  String get pleaseEnterCurrentPw => 'Vui lòng nhập mật khẩu hiện tại';
  @override
  String get changeEmailTitle => 'Đổi email';
  @override
  String get linkInvalidExpired => 'Liên kết không hợp lệ hoặc đã hết hạn.';
  @override
  String get confirmingEmailChange => 'Đang xác nhận đổi email…';
  @override
  String get emailChanged => 'Đã đổi email thành công. Vui lòng đăng nhập lại.';

  // Auth failure messages
  @override
  String get authErrInvalidCredentials => 'Email hoặc mật khẩu không đúng.';
  @override
  String get authErrForbidden =>
      'Tài khoản của bạn không được phép thực hiện thao tác này.';
  @override
  String get authErrSessionExpired =>
      'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
  @override
  String get authErrCheckInfo =>
      'Vui lòng kiểm tra lại thông tin và thử lại.';
  @override
  String get authErrNetwork =>
      'Không kết nối được máy chủ, kiểm tra lại mạng của bạn.';
  @override
  String get authErrEmailTaken =>
      'Email hoặc số điện thoại này đã có tài khoản.';
  @override
  String get authErrGeneric => 'Có lỗi xảy ra. Vui lòng thử lại.';

  // Orders list
  @override
  String get filterProcessing => 'Đang xử lý';
  @override
  String get filterCompleted => 'Hoàn thành';
  @override
  String get filterCancelled => 'Đã hủy';
  @override
  String get noOrdersInFilterTitle => 'Không có đơn';
  @override
  String noOrdersInFilter(String f) => 'Không có đơn hàng nào ở mục "$f".';
  @override
  String get reorderShort => 'Đặt lại';

  // Order detail
  @override
  String kitchenBadge(String label) => 'Bếp · $label';
  @override
  String kitchenStatusLabel(KitchenStatus s) => s.label;
  @override
  String paymentStatusLabel(PaymentStatus s) => s.label;
  @override
  String refundStatusLabel(RefundStatus s) => s.label;
  @override
  String paymentMethodLabel(PaymentMethod m) => m.label;
  @override
  String get reorderThisOrder => 'Đặt lại đơn này';
  @override
  String get scheduledFor => 'Hẹn nhận lúc';
  @override
  String get scheduleWas => 'đã qua giờ hẹn';
  @override
  String get prepKitchenHeadline => 'Bếp trung tâm đang chuẩn bị';
  @override
  String get prepCounterHeadline => 'Quầy đang chuẩn bị';
  @override
  String get prepCounterDetail =>
      'Đội ngũ đang thực hiện — chúng tôi sẽ báo khi đơn sẵn sàng.';
  @override
  String get kitchenDetailPending => 'Đang chờ bếp bắt đầu.';
  @override
  String get kitchenDetailPreparing =>
      'Thợ bánh đang thực hiện đơn của bạn.';
  @override
  String get kitchenDetailReady => 'Đã xong, đang chuyển về cửa hàng.';
  @override
  String get kitchenDetailUnknown =>
      'Chúng tôi sẽ cập nhật khi đơn qua từng công đoạn.';
  @override
  String get stepPlaced => 'Đã đặt';
  @override
  String get stepAccepted => 'Đã nhận';
  @override
  String get stepKitchen => 'Bếp';
  @override
  String get stepCounter => 'Quầy';
  @override
  String get stepOnTheWay => 'Đang giao';
  @override
  String get stepReady => 'Sẵn sàng';
  @override
  String get stepCompleted => 'Hoàn tất';
  @override
  String get refundLabel => 'Hoàn tiền';
  @override
  String get reviewProduct => 'Đánh giá sản phẩm';
  @override
  String editReview(int rating) => 'Sửa đánh giá ($rating★)';
  @override
  String reviewTitleFor(String name) => 'Đánh giá: $name';
  @override
  String get reviewShareOptional => 'Chia sẻ cảm nhận (tuỳ chọn)';
  @override
  String get reviewHelper => 'Hương vị, mức độ tươi, đóng gói, …';
  @override
  String get submitReview => 'Gửi đánh giá';
  @override
  String get update => 'Cập nhật';
  @override
  String get vatInvoiceInfo => 'Thông tin hoá đơn VAT';
  @override
  String taxIdShort(String x) => 'MST: $x';
  @override
  String get giftOrder => 'Đơn quà tặng';
  @override
  String get giftWrapBadge => 'Gói quà';
  @override
  String get giftRecipientLabel => 'Người nhận';
  @override
  String get hidePriceNote => 'Phiếu giao cho người nhận sẽ ẩn giá tiền.';
  @override
  String get personalization => 'Cá nhân hoá';
  @override
  String textOnCakeLine(String text) => 'Chữ trên bánh: "$text"';
  @override
  String candleLine(String c) => 'Nến: $c';
  @override
  String flavorLine(String f) => 'Vị: $f';
  @override
  String noteLine(String n) => 'Ghi chú: $n';

  // Reorder helper
  @override
  String get reorderUnavailable => 'Các món trong đơn này hiện không còn';
  @override
  String reorderAdded(int n) => 'Đã thêm $n món vào giỏ';
  @override
  String reorderAddedSkipped(int n, int k) =>
      'Đã thêm $n món · $k món không còn bán';

  // Profile
  @override
  String get changeAvatar => 'Đổi ảnh đại diện';
  @override
  String get uploadingPhoto => 'Đang tải ảnh…';
  @override
  String avatarTooBig(int mb) =>
      'Ảnh vượt quá $mb MB, vui lòng chọn ảnh nhỏ hơn.';
  @override
  String avatarBigWarn(int mb) =>
      'Ảnh khá lớn (> $mb MB), việc tải lên có thể chậm.';
  @override
  String get avatarUpdated => 'Đã cập nhật ảnh đại diện';
  @override
  String get uploadFailed => 'Tải ảnh thất bại, thử lại';
  @override
  String get emailChangeLinkSent =>
      'Đã gửi liên kết xác nhận tới email mới. Vui lòng kiểm tra hộp thư.';
  @override
  String get genderLabel => 'Giới tính';
  @override
  String genderName(Gender g) => g.label;
  @override
  String get wishlistSub => 'Bánh & sản phẩm bạn đã lưu lại để xem sau.';
  @override
  String get voucherWallet => 'Ví voucher';
  @override
  String get voucherWalletSub => 'Mã giảm giá khả dụng, đã dùng và hết hạn.';
  @override
  String get changePasswordSub => 'Cập nhật mật khẩu đăng nhập của bạn.';
  @override
  String get changeEmailSub => 'Gửi liên kết xác nhận tới email mới của bạn.';
  @override
  String get marketingOptIn => 'Nhận khuyến mãi & tin mới';
  @override
  String get marketingOptInSub => 'Ưu đãi, sản phẩm mới và bản tin từ Banan.';
  @override
  String get orderUpdatesOptIn => 'Cập nhật trạng thái đơn hàng';
  @override
  String get orderUpdatesOptInSub =>
      'Thông báo khi đơn của bạn được xử lý & giao.';
  @override
  String get deleteAccount => 'Xoá tài khoản';
  @override
  String get changeEmailIntro =>
      'Chúng tôi sẽ gửi liên kết xác nhận tới email mới. '
      'Email chỉ thay đổi sau khi bạn xác nhận.';
  @override
  String get newEmail => 'Email mới';
  @override
  String get pleaseEnterNewEmail => 'Vui lòng nhập email mới';
  @override
  String get emailTaken => 'Email đã được sử dụng.';
  @override
  String get wrongPassword => 'Mật khẩu không đúng.';
  @override
  String get emailInvalidOrSame =>
      'Email không hợp lệ hoặc trùng email hiện tại.';
  @override
  String get sendConfirmLink => 'Gửi liên kết xác nhận';
  @override
  String get deleteAccountWarn =>
      'Hành động này không thể hoàn tác. Đơn hàng cũ được ẩn danh.';
  @override
  String get pleaseEnterPwConfirm => 'Vui lòng nhập mật khẩu để xác nhận.';
  @override
  String get deleteForever => 'Xoá vĩnh viễn';

  // Addresses
  @override
  String get deliveryOnlyHcm => 'Banan hiện chỉ giao trong TP.HCM';
  @override
  String get wardReformHelper =>
      'Sau cải cách 7/2025, chọn phường thay cho quận';

  // Voucher wallet
  @override
  String get tabAvailable => 'Khả dụng';
  @override
  String get tabUsed => 'Đã dùng';
  @override
  String get tabExpired => 'Hết hạn';
  @override
  String get noVoucherTitle => 'Chưa có voucher';
  @override
  String get noVoucherAvailable => 'Bạn chưa có voucher nào khả dụng.';
  @override
  String get noVoucherUsed => 'Bạn chưa dùng voucher nào.';
  @override
  String get noVoucherExpired => 'Không có voucher nào hết hạn.';
  @override
  String discountPercent(String p) => 'Giảm $p%';
  @override
  String discountAmount(String a) => 'Giảm $a';
  @override
  String codeCopied(String code) => 'Đã sao chép mã $code';
  @override
  String get copyCode => 'Sao chép mã';
  @override
  String minOrder(String a) => 'Đơn tối thiểu $a';
  @override
  String usedOn(String d) => 'Đã dùng $d';
  @override
  String expiresOn(String d) => 'HSD $d';

  // Membership
  @override
  String tierName(MembershipTier t) => t.label;
  @override
  String tierHeading(String name) => 'Hạng $name';
  @override
  String get memberTiers => 'Các hạng thành viên';
  @override
  String get currentBadge => 'Hiện tại';
  @override
  String fromPoints(String n) => 'Từ $n điểm';
  @override
  String pointsToTier(int n, String tier) =>
      'Còn $n điểm để lên hạng $tier';
  @override
  String loyaltyTypeLabel(LoyaltyEventType t) => switch (t) {
        LoyaltyEventType.earn => 'Tích điểm',
        LoyaltyEventType.redeem => 'Đổi điểm',
        LoyaltyEventType.expire => 'Điểm hết hạn',
        LoyaltyEventType.birthday => 'Quà sinh nhật',
        LoyaltyEventType.adjustment => 'Điều chỉnh',
      };

  // Wholesale
  @override
  String get whTitle => 'Đặt hàng sỉ';
  @override
  String get whTabOrder => 'Đặt hàng';
  @override
  String get whTabMyOrders => 'Đơn của tôi';
  @override
  String get whTabDebts => 'Công nợ';
  @override
  String get whPickAtLeastOne => 'Chọn ít nhất một sản phẩm.';
  @override
  String get whNeedDeliveryDate =>
      'Hợp đồng này yêu cầu chọn ngày giao hàng.';
  @override
  String whOrderPlaced(String code) =>
      'Đã đặt $code. Đơn đang chờ admin xác nhận.';
  @override
  String get whNotAllowed => 'Tài khoản chưa được phép đặt sỉ.';
  @override
  String get whNoContractsTitle => 'Chưa có hợp đồng hiệu lực';
  @override
  String get whNoContractsMsg =>
      'Liên hệ Banan để kiểm tra thời hạn và danh mục hợp đồng.';
  @override
  String whMinOrderValue(String a) => 'Giá trị tối thiểu $a';
  @override
  String whContractPrice(String a) => 'Giá hợp đồng $a';
  @override
  String whMinQty(int n) => 'Tối thiểu $n';
  @override
  String whMultipleQty(int n) => 'Bội số $n';
  @override
  String whOnlyDeliverOn(String days) => 'Chỉ giao $days';
  @override
  String whLeadDays(int n) => 'Đặt trước $n ngày';
  @override
  String whLeadHours(int n) => 'Đặt trước $n giờ';
  @override
  String get whPickDateRequired => 'Chọn ngày giao (bắt buộc)';
  @override
  String get whPickDate => 'Chọn thời gian cần giao';
  @override
  String whDeliverAt(String t) => 'Giao $t';
  @override
  String whCutoffNote(String hhmm) =>
      'Đặt trước $hhmm để được giao vào ngày hôm sau.';
  @override
  String whNoDeliveryOn(String days) => 'Không giao vào $days.';
  @override
  String get whPoLabel => 'Mã đơn mua hàng (PO), tuỳ chọn';
  @override
  String get whPoHelper =>
      'Mã PO nội bộ của công ty bạn, in kèm đơn để đối soát.';
  @override
  String get whOrderNotes => 'Ghi chú đơn hàng';
  @override
  String whShipFee(String a) => 'Phí giao hàng: $a';
  @override
  String whSubmit(String a) => 'Đặt theo công nợ · $a';
  @override
  String get whNoOrders => 'Chưa có đơn';
  @override
  String get whNoOrdersMsg => 'Đơn sỉ đã đặt sẽ hiển thị tại đây.';
  @override
  String whStatusLabel(String status) => switch (status) {
        'PENDING' => 'Đã đặt đơn',
        'DELIVERING' => 'Đang giao hàng',
        'CANCELLED' => 'Đã hủy',
        _ => 'Đã xác nhận',
      };
  @override
  String get whNoDebtsTitle => 'Chưa có công nợ';
  @override
  String get whNoDebtsMsg => 'Công nợ theo hợp đồng sẽ hiển thị tại đây.';
  @override
  String get whOrderFallback => 'Đơn hàng';
  @override
  String get whDebtStartsAfterConfirm =>
      'Kỳ hạn bắt đầu sau khi đơn được xác nhận';
  @override
  String whDueDate(String d) => 'Hạn thanh toán $d';
  @override
  String whDebtStatusLabel(String status, {required bool overdue}) {
    if (overdue) return 'Quá hạn';
    return switch (status) {
      'PENDING' => 'Chờ xác nhận đơn',
      'PAID' => 'Đã thanh toán',
      'CANCELLED' => 'Đã hủy',
      _ => 'Chưa thanh toán',
    };
  }

  // Cake wizard
  @override
  String candleRegular(int n) => '$n nến';
  @override
  String candleSpiral(int n) => '$n nến xoắn';
  @override
  String candleNumber(int n) => 'nến số $n';
  @override
  String get noteWord => 'ghi chú';
  @override
  String wizTitle(String name) => 'Cá nhân hoá: $name';
  @override
  String get wizIntro =>
      'Tất cả trường đều tuỳ chọn. Để trống các phần bạn không '
      'cần. Bánh sẽ làm theo mặc định.';
  @override
  String get wizTextOnCake => 'Chữ viết trên bánh';
  @override
  String get wizTextHint => 'vd: Chúc mừng sinh nhật An!';
  @override
  String get wizCandles => 'Nến';
  @override
  String get wizCandleType => 'Loại nến';
  @override
  String get wizNoCandles => 'Không nến';
  @override
  String get wizRegularCandles => 'Nến thường';
  @override
  String get wizNumberCandles => 'Nến số';
  @override
  String get wizSpiralCandles => 'Nến xoắn';
  @override
  String get wizSpiralCount => 'Số nến xoắn';
  @override
  String get wizCandleCount => 'Số nến';
  @override
  String get wizAge => 'Số tuổi';
  @override
  String get wizAgeHelper => 'Nến hình con số theo tuổi (vd: 25)';
  @override
  String get wizNote => 'Ghi chú thêm cho thợ bánh';
  @override
  String get wizNoteHint =>
      'vd: ribbon vàng, không sprinkles, kem ít ngọt …';
  @override
  String get wizClear => 'Xoá cá nhân hoá';

  // Flavor composer
  @override
  String get flavorPickTitle => 'Chọn vị macaron';
  @override
  String flavorPicked(int n, int total) => 'Đã chọn $n/$total';
  @override
  String get flavorComplete => 'Đủ rồi! Bạn có thể thêm vào giỏ.';
  @override
  String flavorRemaining(int n) =>
      'Còn $n cái, chọn thêm (có thể nhiều cái cùng vị).';

  // Bundles
  @override
  String get viewCartShort => 'Xem giỏ';
  @override
  String get comboTitle => 'Combo';
  @override
  String get bundleIncludes => 'Combo gồm';
  @override
  String get addComboToCart => 'Thêm combo vào giỏ';
  @override
  String addedCombo(String name) => 'Đã thêm combo "$name" vào giỏ.';
  @override
  String get productFallback => 'Sản phẩm';
  @override
  String bundleQty(int n) => '$n cái';
  @override
  String saveAmount(String a) => 'Tiết kiệm $a';
  @override
  String get bundlesOverline => 'Tiết kiệm hơn';
  @override
  String get bundlesTitle => 'Combo nổi bật';
  @override
  String get bundlesSub => 'Đặt set có sẵn, rẻ hơn 10-20% so với mua lẻ.';
  @override
  String get allBundlesTitle => 'Tất cả combo';
  @override
  String get allBundlesSub => 'Mọi set đang bán. Chọn combo bạn thích.';

  // Contact FAB
  @override
  String get contactTitle => 'Liên hệ';
  @override
  String get needHelp => 'Cần hỗ trợ?';
  @override
  String get contactSub =>
      'Chọn kênh phù hợp. Đội Banan trả lời nhanh nhất qua '
      'Zalo trong giờ mở cửa.';
  @override
  String get zaloSub => 'Mở Zalo và chat với đội Banan';
  @override
  String get messengerSub => 'Nhắn tin qua trang Banan';
  @override
  String get callDirect => 'Gọi trực tiếp';
  @override
  String get sendEmail => 'Gửi email';

  // Promo popup
  @override
  String get promoClose => 'Đóng';
  @override
  String promoAutoClose(int sec) => 'Tự đóng sau ${sec}s';

  // Payment return
  @override
  String get paymentReceived =>
      'Đã nhận yêu cầu thanh toán. Chúng tôi sẽ xác nhận đơn của bạn '
      'qua email/điện thoại.';
  @override
  String get paymentProcessing => 'Đang xử lý thanh toán…';

  // Contact page
  @override
  String get contactHeading => 'Liên hệ với Banan';
  @override
  String get contactIntro =>
      'Có thắc mắc về đơn hàng, đặt bánh theo yêu cầu hay hợp tác? '
      'Gửi tin nhắn cho chúng tôi, hoặc gọi hotline để được hỗ trợ ngay.';
  @override
  String get sendMessageTitle => 'Gửi tin nhắn';
  @override
  String get nameReq => 'Họ tên *';
  @override
  String get enterName => 'Nhập họ tên';
  @override
  String get emailReq => 'Email *';
  @override
  String get subjectLabel => 'Chủ đề';
  @override
  String get messageReq => 'Nội dung *';
  @override
  String get enterMessage => 'Nhập nội dung';
  @override
  String get sending => 'Đang gửi…';
  @override
  String get sendMessageBtn => 'Gửi tin nhắn';
  @override
  String get sendFailed => 'Gửi không thành công, vui lòng thử lại.';
  @override
  String get sentTitle => 'Đã gửi tin nhắn!';
  @override
  String get sentThanks =>
      'Cảm ơn bạn đã liên hệ. Chúng tôi sẽ phản hồi sớm nhất qua email.';
  @override
  String get sendAnother => 'Gửi tin nhắn khác';

  // FAQ / About
  @override
  String get faqTitle => 'Câu hỏi thường gặp';
  @override
  String get faqNotFound => 'Không thấy câu trả lời? Liên hệ chúng tôi';
  @override
  String get aboutTitle => 'Về Banan';
  @override
  String get viewLocations => 'Xem các chi nhánh';

  // Marketing pages
  @override
  String get programNotOpen => 'Chương trình chưa mở';
  @override
  String get programNotOpenMsg => 'Tính năng này hiện chưa được kích hoạt.';
  @override
  String get loadFailed => 'Không tải được.';
  @override
  String get referralTitle => 'Giới thiệu bạn bè';
  @override
  String get referralLoginPrompt =>
      'Đăng nhập để lấy mã giới thiệu của bạn.';
  @override
  String referralBonus(int referrer, int referee) =>
      'Bạn nhận $referrer điểm • Bạn bè nhận $referee điểm khi '
      'họ đặt đơn đầu tiên.';
  @override
  String get referralCodeLabel => 'Mã giới thiệu';
  @override
  String get shareLinkLabel => 'Link chia sẻ';
  @override
  String get copyLabel => 'Sao chép';
  @override
  String get copied => 'Đã sao chép';
  @override
  String get giftCardTitle => 'Thẻ quà tặng';
  @override
  String get giftCardHeading => 'Thẻ quà tặng Banan';
  @override
  String giftCardExpiry(int months) => 'Hạn sử dụng: $months tháng';
  @override
  String get contactToBuyGiftCard => 'Liên hệ để mua thẻ quà tặng';
  @override
  String get subscriptionTitle => 'Gói định kỳ';
  @override
  String get subscriptionHeading => 'Nhận bánh định kỳ';
  @override
  String perPeriod(String p) => 'mỗi $p';
  @override
  String get contactToSubscribe => 'Liên hệ đăng ký';
  @override
  String get cateringTitle => 'Đặt tiệc / Sự kiện';
  @override
  String get cateringHeading => 'Đặt tiệc & sự kiện';
  @override
  String get cateringSentTitle => 'Đã gửi yêu cầu!';
  @override
  String get cateringSentMsg =>
      'Cảm ơn bạn, cửa hàng sẽ liên hệ tư vấn sớm nhất.';
  @override
  String cateringMinLead(int minGuests, int leadDays) =>
      'Tối thiểu $minGuests khách • đặt trước $leadDays ngày';
  @override
  String get fillNamePhoneContent =>
      'Vui lòng điền tên, số điện thoại và nội dung.';
  @override
  String get phoneReq => 'Số điện thoại *';
  @override
  String get emailOptionalLabel => 'Email (tuỳ chọn)';
  @override
  String get contentHintCatering =>
      'Số khách, ngày, loại bánh / dịch vụ mong muốn…';
  @override
  String get sendRequest => 'Gửi yêu cầu';
  @override
  String get rewardsTitle => 'Đổi điểm lấy quà';
  @override
  String yourPoints(int n) => 'Điểm của bạn: $n';
  @override
  String get noRewards => 'Chưa có phần quà nào.';
  @override
  String rewardPoints(int n) => '$n điểm';
  @override
  String get redeemWord => 'Đổi';
  @override
  String get notEnough => 'Chưa đủ';
  @override
  String get rewardsNote =>
      'Để đổi quà, vui lòng liên hệ hoặc tới quầy. Nhân viên sẽ xác '
      'nhận và trừ điểm cho bạn.';
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

  // Auth screens
  @override
  String get backToShop => 'Back to the shop';
  @override
  String get forgotPasswordQ => 'Forgot password?';
  @override
  String get optionalSuffix => 'optional';
  @override
  String get pwMin8 => 'Password must be at least 8 characters';
  @override
  String get welcomeBack => 'Welcome back!';
  @override
  String get helloThere => 'Hello!';
  @override
  String get overlayHaveAccount =>
      'Already have an account? Sign in to keep ordering.';
  @override
  String get overlayNoAccount =>
      'New here? Sign up to earn points and order faster.';
  @override
  String get birthdayHelp => 'Your birthday';
  @override
  String get birthdayOptional => 'Birthday (optional)';
  @override
  String get birthdayPerk => 'A birthday treat, on us.';
  @override
  String get tapToPick => 'Tap to pick…';
  @override
  String get forgotTitle => 'Forgot password';
  @override
  String get forgotIntro =>
      'Enter your email and we will send you a password reset link.';
  @override
  String get forgotSent =>
      'If that email is registered with us, we have sent a password reset '
      'link. Please check your inbox.';
  @override
  String get pleaseEnterEmail => 'Please enter your email';
  @override
  String get sendResetLink => 'Send reset link';
  @override
  String get resetTitle => 'Reset password';
  @override
  String get resetLinkInvalid =>
      'This link is invalid or has expired. Please request a new '
      'password reset link.';
  @override
  String get requestNewLink => 'Request a new link';
  @override
  String get resetDone =>
      'Password reset successful. You can now sign in with your new password.';
  @override
  String get resetIntro => 'Enter a new password for your account.';
  @override
  String get newPassword => 'New password';
  @override
  String get confirmNewPassword => 'Confirm new password';
  @override
  String get pwMismatch => 'Passwords do not match';
  @override
  String get changePasswordTitle => 'Change password';
  @override
  String get passwordChanged => 'Password changed';
  @override
  String get currentPassword => 'Current password';
  @override
  String get pleaseEnterCurrentPw => 'Please enter your current password';
  @override
  String get changeEmailTitle => 'Change email';
  @override
  String get linkInvalidExpired => 'This link is invalid or has expired.';
  @override
  String get confirmingEmailChange => 'Confirming your email change…';
  @override
  String get emailChanged => 'Email changed. Please sign in again.';

  // Auth failure messages
  @override
  String get authErrInvalidCredentials => 'Incorrect email or password.';
  @override
  String get authErrForbidden =>
      'Your account is not allowed to perform this action.';
  @override
  String get authErrSessionExpired =>
      'Your session has expired, please sign in again.';
  @override
  String get authErrCheckInfo => 'Please check your details and try again.';
  @override
  String get authErrNetwork =>
      'Could not reach the server — check your connection.';
  @override
  String get authErrEmailTaken =>
      'An account already exists with this email or phone number.';
  @override
  String get authErrGeneric => 'Something went wrong. Please try again.';

  // Orders list
  @override
  String get filterProcessing => 'In progress';
  @override
  String get filterCompleted => 'Completed';
  @override
  String get filterCancelled => 'Cancelled';
  @override
  String get noOrdersInFilterTitle => 'No orders';
  @override
  String noOrdersInFilter(String f) => 'No orders under "$f".';
  @override
  String get reorderShort => 'Reorder';

  // Order detail
  @override
  String kitchenBadge(String label) => 'Kitchen · $label';
  @override
  String kitchenStatusLabel(KitchenStatus s) => switch (s) {
        KitchenStatus.pendingAck => 'Waiting to start',
        KitchenStatus.preparing => 'Preparing',
        KitchenStatus.readyDispatch => 'Ready to dispatch',
        KitchenStatus.unknown => 'Other',
      };
  @override
  String paymentStatusLabel(PaymentStatus s) => switch (s) {
        PaymentStatus.initiated => 'Awaiting payment',
        PaymentStatus.authorized => 'Pay on delivery',
        PaymentStatus.captured => 'Paid',
        PaymentStatus.failed => 'Payment failed',
        PaymentStatus.voided => 'Payment voided',
        PaymentStatus.refunded => 'Refunded',
        PaymentStatus.unknown => 'Other',
      };
  @override
  String refundStatusLabel(RefundStatus s) => switch (s) {
        RefundStatus.requested => 'Requested',
        RefundStatus.approved => 'Approved',
        RefundStatus.processing => 'Processing',
        RefundStatus.completed => 'Refunded',
        RefundStatus.rejected => 'Rejected',
        RefundStatus.unknown => 'Other',
      };
  @override
  String paymentMethodLabel(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Cash on delivery',
        PaymentMethod.stripe => 'International card · Stripe',
        PaymentMethod.payos => 'PayOS · QR / Bank transfer',
        PaymentMethod.momo => 'MoMo',
        PaymentMethod.ninepay => '9Pay · QR / Card / Bank transfer',
        PaymentMethod.unknown => 'Online payment',
      };
  @override
  String get reorderThisOrder => 'Reorder this order';
  @override
  String get scheduledFor => 'Scheduled for';
  @override
  String get scheduleWas => 'was scheduled';
  @override
  String get prepKitchenHeadline => 'Being prepared in our kitchen';
  @override
  String get prepCounterHeadline => 'Being prepared at the counter';
  @override
  String get prepCounterDetail =>
      "Our team is on it — we'll let you know when it's ready.";
  @override
  String get kitchenDetailPending => 'Waiting for the kitchen team to start.';
  @override
  String get kitchenDetailPreparing =>
      'Our bakers are crafting your order right now.';
  @override
  String get kitchenDetailReady => 'Ready and on its way back to the store.';
  @override
  String get kitchenDetailUnknown =>
      "We'll keep you posted as it moves through the kitchen.";
  @override
  String get stepPlaced => 'Placed';
  @override
  String get stepAccepted => 'Accepted';
  @override
  String get stepKitchen => 'Kitchen';
  @override
  String get stepCounter => 'Counter';
  @override
  String get stepOnTheWay => 'On the way';
  @override
  String get stepReady => 'Ready';
  @override
  String get stepCompleted => 'Completed';
  @override
  String get refundLabel => 'Refund';
  @override
  String get reviewProduct => 'Review product';
  @override
  String editReview(int rating) => 'Edit review ($rating★)';
  @override
  String reviewTitleFor(String name) => 'Review: $name';
  @override
  String get reviewShareOptional => 'Share your thoughts (optional)';
  @override
  String get reviewHelper => 'Taste, freshness, packaging, …';
  @override
  String get submitReview => 'Submit review';
  @override
  String get update => 'Update';
  @override
  String get vatInvoiceInfo => 'VAT invoice details';
  @override
  String taxIdShort(String x) => 'Tax ID: $x';
  @override
  String get giftOrder => 'Gift order';
  @override
  String get giftWrapBadge => 'Gift wrap';
  @override
  String get giftRecipientLabel => 'Recipient';
  @override
  String get hidePriceNote => 'The delivery slip will hide all prices.';
  @override
  String get personalization => 'Personalized';
  @override
  String textOnCakeLine(String text) => 'Text on cake: "$text"';
  @override
  String candleLine(String c) => 'Candles: $c';
  @override
  String flavorLine(String f) => 'Flavors: $f';
  @override
  String noteLine(String n) => 'Note: $n';

  // Reorder helper
  @override
  String get reorderUnavailable =>
      'The items in this order are no longer available';
  @override
  String reorderAdded(int n) => 'Added $n item${n == 1 ? '' : 's'} to your cart';
  @override
  String reorderAddedSkipped(int n, int k) =>
      'Added $n item${n == 1 ? '' : 's'} · $k no longer sold';

  // Profile
  @override
  String get changeAvatar => 'Change profile photo';
  @override
  String get uploadingPhoto => 'Uploading…';
  @override
  String avatarTooBig(int mb) =>
      'Image exceeds $mb MB, please pick a smaller one.';
  @override
  String avatarBigWarn(int mb) =>
      'Large image (> $mb MB) — the upload may be slow.';
  @override
  String get avatarUpdated => 'Profile photo updated';
  @override
  String get uploadFailed => 'Upload failed, please try again';
  @override
  String get emailChangeLinkSent =>
      'Confirmation link sent to your new email. Please check your inbox.';
  @override
  String get genderLabel => 'Gender';
  @override
  String genderName(Gender g) => switch (g) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
      };
  @override
  String get wishlistSub => 'Cakes & products you saved for later.';
  @override
  String get voucherWallet => 'Voucher wallet';
  @override
  String get voucherWalletSub => 'Available, used and expired discount codes.';
  @override
  String get changePasswordSub => 'Update your sign-in password.';
  @override
  String get changeEmailSub =>
      'We send a confirmation link to your new email.';
  @override
  String get marketingOptIn => 'Promotions & news';
  @override
  String get marketingOptInSub =>
      'Deals, new products and the Banan newsletter.';
  @override
  String get orderUpdatesOptIn => 'Order status updates';
  @override
  String get orderUpdatesOptInSub =>
      'Notifications as your order is processed & delivered.';
  @override
  String get deleteAccount => 'Delete account';
  @override
  String get changeEmailIntro =>
      'We will send a confirmation link to your new email. '
      'It only changes after you confirm.';
  @override
  String get newEmail => 'New email';
  @override
  String get pleaseEnterNewEmail => 'Please enter the new email';
  @override
  String get emailTaken => 'This email is already in use.';
  @override
  String get wrongPassword => 'Incorrect password.';
  @override
  String get emailInvalidOrSame =>
      'Invalid email, or same as your current one.';
  @override
  String get sendConfirmLink => 'Send confirmation link';
  @override
  String get deleteAccountWarn =>
      'This cannot be undone. Past orders are anonymised.';
  @override
  String get pleaseEnterPwConfirm =>
      'Please enter your password to confirm.';
  @override
  String get deleteForever => 'Delete permanently';

  // Addresses
  @override
  String get deliveryOnlyHcm =>
      'Banan currently delivers within Ho Chi Minh City only';
  @override
  String get wardReformHelper =>
      'Since the 7/2025 reform, pick a ward instead of a district';

  // Voucher wallet
  @override
  String get tabAvailable => 'Available';
  @override
  String get tabUsed => 'Used';
  @override
  String get tabExpired => 'Expired';
  @override
  String get noVoucherTitle => 'No vouchers';
  @override
  String get noVoucherAvailable => 'You have no available vouchers.';
  @override
  String get noVoucherUsed => 'You have not used any vouchers yet.';
  @override
  String get noVoucherExpired => 'No expired vouchers.';
  @override
  String discountPercent(String p) => '$p% off';
  @override
  String discountAmount(String a) => '$a off';
  @override
  String codeCopied(String code) => 'Copied code $code';
  @override
  String get copyCode => 'Copy code';
  @override
  String minOrder(String a) => 'Min. order $a';
  @override
  String usedOn(String d) => 'Used $d';
  @override
  String expiresOn(String d) => 'Expires $d';

  // Membership
  @override
  String tierName(MembershipTier t) => switch (t) {
        MembershipTier.bronze => 'Bronze',
        MembershipTier.silver => 'Silver',
        MembershipTier.gold => 'Gold',
        MembershipTier.platinum => 'Platinum',
      };
  @override
  String tierHeading(String name) => '$name tier';
  @override
  String get memberTiers => 'Membership tiers';
  @override
  String get currentBadge => 'Current';
  @override
  String fromPoints(String n) => 'From $n points';
  @override
  String pointsToTier(int n, String tier) =>
      '$n more points to reach $tier';
  @override
  String loyaltyTypeLabel(LoyaltyEventType t) => switch (t) {
        LoyaltyEventType.earn => 'Earned',
        LoyaltyEventType.redeem => 'Redeemed',
        LoyaltyEventType.expire => 'Expired',
        LoyaltyEventType.birthday => 'Birthday gift',
        LoyaltyEventType.adjustment => 'Adjustment',
      };

  // Wholesale
  @override
  String get whTitle => 'Wholesale ordering';
  @override
  String get whTabOrder => 'Order';
  @override
  String get whTabMyOrders => 'My orders';
  @override
  String get whTabDebts => 'Receivables';
  @override
  String get whPickAtLeastOne => 'Pick at least one product.';
  @override
  String get whNeedDeliveryDate =>
      'This contract requires a delivery date.';
  @override
  String whOrderPlaced(String code) =>
      'Placed $code. Awaiting admin confirmation.';
  @override
  String get whNotAllowed =>
      'Your account is not enabled for wholesale ordering.';
  @override
  String get whNoContractsTitle => 'No active contracts';
  @override
  String get whNoContractsMsg =>
      'Contact Banan to check your contract terms and catalog.';
  @override
  String whMinOrderValue(String a) => 'Minimum order value $a';
  @override
  String whContractPrice(String a) => 'Contract price $a';
  @override
  String whMinQty(int n) => 'Min $n';
  @override
  String whMultipleQty(int n) => 'Multiples of $n';
  @override
  String whOnlyDeliverOn(String days) => 'Delivers only $days';
  @override
  String whLeadDays(int n) => 'Order $n days ahead';
  @override
  String whLeadHours(int n) => 'Order $n hours ahead';
  @override
  String get whPickDateRequired => 'Pick a delivery date (required)';
  @override
  String get whPickDate => 'Pick a delivery time';
  @override
  String whDeliverAt(String t) => 'Deliver $t';
  @override
  String whCutoffNote(String hhmm) =>
      'Order before $hhmm for next-day delivery.';
  @override
  String whNoDeliveryOn(String days) => 'No delivery on $days.';
  @override
  String get whPoLabel => 'Purchase order (PO) code, optional';
  @override
  String get whPoHelper =>
      "Your company's internal PO code, printed on the order "
      'for reconciliation.';
  @override
  String get whOrderNotes => 'Order notes';
  @override
  String whShipFee(String a) => 'Delivery fee: $a';
  @override
  String whSubmit(String a) => 'Order on credit · $a';
  @override
  String get whNoOrders => 'No orders yet';
  @override
  String get whNoOrdersMsg => 'Wholesale orders you place appear here.';
  @override
  String whStatusLabel(String status) => switch (status) {
        'PENDING' => 'Placed',
        'DELIVERING' => 'Delivering',
        'CANCELLED' => 'Cancelled',
        _ => 'Confirmed',
      };
  @override
  String get whNoDebtsTitle => 'No receivables';
  @override
  String get whNoDebtsMsg => 'Contract receivables appear here.';
  @override
  String get whOrderFallback => 'Order';
  @override
  String get whDebtStartsAfterConfirm =>
      'Terms start once the order is confirmed';
  @override
  String whDueDate(String d) => 'Due $d';
  @override
  String whDebtStatusLabel(String status, {required bool overdue}) {
    if (overdue) return 'Overdue';
    return switch (status) {
      'PENDING' => 'Awaiting confirmation',
      'PAID' => 'Paid',
      'CANCELLED' => 'Cancelled',
      _ => 'Unpaid',
    };
  }

  // Cake wizard
  @override
  String candleRegular(int n) => '$n candle${n == 1 ? '' : 's'}';
  @override
  String candleSpiral(int n) => '$n spiral candle${n == 1 ? '' : 's'}';
  @override
  String candleNumber(int n) => 'number candle $n';
  @override
  String get noteWord => 'note';
  @override
  String wizTitle(String name) => 'Personalize: $name';
  @override
  String get wizIntro =>
      "Everything is optional. Leave blank what you don't need — "
      "we'll use our defaults.";
  @override
  String get wizTextOnCake => 'Text on the cake';
  @override
  String get wizTextHint => 'e.g. Happy birthday An!';
  @override
  String get wizCandles => 'Candles';
  @override
  String get wizCandleType => 'Candle type';
  @override
  String get wizNoCandles => 'No candles';
  @override
  String get wizRegularCandles => 'Regular';
  @override
  String get wizNumberCandles => 'Number';
  @override
  String get wizSpiralCandles => 'Spiral';
  @override
  String get wizSpiralCount => 'Spiral candle count';
  @override
  String get wizCandleCount => 'Candle count';
  @override
  String get wizAge => 'Age';
  @override
  String get wizAgeHelper => 'Digit candles spelling the age (e.g. 25)';
  @override
  String get wizNote => 'Extra note for the baker';
  @override
  String get wizNoteHint =>
      'e.g. gold ribbon, no sprinkles, less-sweet cream …';
  @override
  String get wizClear => 'Clear personalization';

  // Flavor composer
  @override
  String get flavorPickTitle => 'Pick macaron flavors';
  @override
  String flavorPicked(int n, int total) => 'Picked $n/$total';
  @override
  String get flavorComplete => 'All set! You can add to cart.';
  @override
  String flavorRemaining(int n) =>
      '$n more to pick (repeats allowed).';

  // Bundles
  @override
  String get viewCartShort => 'View cart';
  @override
  String get comboTitle => 'Combo';
  @override
  String get bundleIncludes => 'What you get';
  @override
  String get addComboToCart => 'Add combo to cart';
  @override
  String addedCombo(String name) => 'Added combo "$name" to your cart.';
  @override
  String get productFallback => 'Product';
  @override
  String bundleQty(int n) => '$n pc${n == 1 ? '' : 's'}';
  @override
  String saveAmount(String a) => 'Save $a';
  @override
  String get bundlesOverline => 'Better value';
  @override
  String get bundlesTitle => 'Featured combos';
  @override
  String get bundlesSub =>
      'Ready-made sets, 10-20% cheaper than buying separately.';
  @override
  String get allBundlesTitle => 'All combos';
  @override
  String get allBundlesSub => 'Every set on sale. Pick your favorite.';

  // Contact FAB
  @override
  String get contactTitle => 'Contact';
  @override
  String get needHelp => 'Need help?';
  @override
  String get contactSub =>
      'Pick a channel. The Banan team replies fastest on Zalo '
      'during opening hours.';
  @override
  String get zaloSub => 'Open Zalo and chat with the Banan team';
  @override
  String get messengerSub => 'Message us via the Banan page';
  @override
  String get callDirect => 'Call us directly';
  @override
  String get sendEmail => 'Send an email';

  // Promo popup
  @override
  String get promoClose => 'Close';
  @override
  String promoAutoClose(int sec) => 'Auto-closes in ${sec}s';

  // Payment return
  @override
  String get paymentReceived =>
      'Payment request received. We will confirm your order '
      'by email or phone.';
  @override
  String get paymentProcessing => 'Processing payment…';

  // Contact page
  @override
  String get contactHeading => 'Contact Banan';
  @override
  String get contactIntro =>
      'Questions about an order, a custom cake or a partnership? '
      'Send us a message, or call the hotline for immediate help.';
  @override
  String get sendMessageTitle => 'Send a message';
  @override
  String get nameReq => 'Full name *';
  @override
  String get enterName => 'Please enter your name';
  @override
  String get emailReq => 'Email *';
  @override
  String get subjectLabel => 'Subject';
  @override
  String get messageReq => 'Message *';
  @override
  String get enterMessage => 'Please enter a message';
  @override
  String get sending => 'Sending…';
  @override
  String get sendMessageBtn => 'Send message';
  @override
  String get sendFailed => 'Sending failed, please try again.';
  @override
  String get sentTitle => 'Message sent!';
  @override
  String get sentThanks =>
      'Thanks for reaching out. We will reply by email as soon as we can.';
  @override
  String get sendAnother => 'Send another message';

  // FAQ / About
  @override
  String get faqTitle => 'Frequently asked questions';
  @override
  String get faqNotFound => "Didn't find your answer? Contact us";
  @override
  String get aboutTitle => 'About Banan';
  @override
  String get viewLocations => 'See our locations';

  // Marketing pages
  @override
  String get programNotOpen => 'Program not open yet';
  @override
  String get programNotOpenMsg => 'This feature is not enabled yet.';
  @override
  String get loadFailed => 'Could not load.';
  @override
  String get referralTitle => 'Refer a friend';
  @override
  String get referralLoginPrompt => 'Sign in to get your referral code.';
  @override
  String referralBonus(int referrer, int referee) =>
      'You get $referrer points • Your friend gets $referee points '
      'on their first order.';
  @override
  String get referralCodeLabel => 'Referral code';
  @override
  String get shareLinkLabel => 'Share link';
  @override
  String get copyLabel => 'Copy';
  @override
  String get copied => 'Copied';
  @override
  String get giftCardTitle => 'Gift cards';
  @override
  String get giftCardHeading => 'Banan gift cards';
  @override
  String giftCardExpiry(int months) => 'Valid for $months months';
  @override
  String get contactToBuyGiftCard => 'Contact us to buy a gift card';
  @override
  String get subscriptionTitle => 'Subscriptions';
  @override
  String get subscriptionHeading => 'Cakes on a schedule';
  @override
  String perPeriod(String p) => 'every $p';
  @override
  String get contactToSubscribe => 'Contact us to subscribe';
  @override
  String get cateringTitle => 'Catering / Events';
  @override
  String get cateringHeading => 'Catering & events';
  @override
  String get cateringSentTitle => 'Request sent!';
  @override
  String get cateringSentMsg =>
      'Thank you — the store will contact you shortly.';
  @override
  String cateringMinLead(int minGuests, int leadDays) =>
      'Minimum $minGuests guests • order $leadDays days ahead';
  @override
  String get fillNamePhoneContent =>
      'Please fill in your name, phone number and message.';
  @override
  String get phoneReq => 'Phone number *';
  @override
  String get emailOptionalLabel => 'Email (optional)';
  @override
  String get contentHintCatering =>
      'Guest count, date, cakes / services you have in mind…';
  @override
  String get sendRequest => 'Send request';
  @override
  String get rewardsTitle => 'Redeem points';
  @override
  String yourPoints(int n) => 'Your points: $n';
  @override
  String get noRewards => 'No rewards yet.';
  @override
  String rewardPoints(int n) => '$n points';
  @override
  String get redeemWord => 'Redeem';
  @override
  String get notEnough => 'Not enough';
  @override
  String get rewardsNote =>
      'To redeem, please contact us or visit the counter. Our staff '
      'will confirm and deduct your points.';
}
