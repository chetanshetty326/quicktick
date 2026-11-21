class ApiEndpoints {
  // Base URLs
  static const String baseUrl = 'https://api.quicktick.shop/api/v1';
  static const String liveBaseUrl = 'https://api.quicktick.shop/api/v1';
  static const String localBaseUrl = 'http://localhost:5000/api/v1';

  // WebSocket URLs
  static const String productionWebSocketUrl = 'wss://api.quicktick.shop/socket.io';
  static const String localWebSocketUrl = 'ws://localhost:5000/socket.io';
  static const String webSocketUrl = productionWebSocketUrl;

  // Auth Module
  static const String checkMobile = '/auth/check-mobile';
  static const String checkMobileAdmin = '/admin/check-mobile';
  static const String checkMobileLegacy = '/auth/check-mobile';
  static const String registerDeviceToken = '/users/register-device';
  static const String registerDeviceTokenAdmin = '/users/register-device';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String sendEmailOtp = '/auth/email/send-otp';
  static const String registerWithEmail = '/auth/email/register';
  static const String loginWithEmail = '/auth/email/login';
  static const String googleAuth = '/auth/google';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String userMe = '/users/me';

  // Customer Module - Products & Catalog
  static const String products = '/products';
  static const String productsSearch = '/products/search';
  static const String customerCatalogSearch = '/products/search';
  static const String productsFeatured = '/products/featured';
  static String productById(String id) => '/products/$id';
  static const String categories = '/categories';
  static String categoryById(String id) => '/categories/$id';
  static const String customerCategories = '/categories';
  static const String retailersNearby = '/retailers/nearby';
  static const String customerNearbyStores = '/retailers/nearby';
  static String retailerById(String id) => '/retailers/$id';
  static String customerStoreDetails(String storeId) => '/retailers/$storeId';
  static const String customerRecommendations = '/products/featured';
  static const String heroBanners = '/hero-banners';
  static String heroBannersForApp(String app) => '/hero-banners?app=$app';

  // Coupons Module
  static const String coupons = '/coupons';
  static const String couponsValidate = '/coupons/validate';
  static String couponsByRetailer(String retailerId) => '/coupons?retailerId=$retailerId';
  static String couponByCode(String code) => '/coupons/validate/$code';

  // Customer Support Tickets Module
  static const String supportTickets = '/support/tickets';
  static String supportTicketsWithFilter({String? status, int page = 1, int limit = 20}) {
    final query = <String>[
      if (status != null && status.isNotEmpty) 'status=$status',
      'page=$page',
      'limit=$limit',
    ];
    return '/support/tickets?${query.join('&')}';
  }
  static String supportTicketDetails(String id) => '/support/tickets/$id';
  static String supportTicketMessages(String id) => '/support/tickets/$id/messages';
  static const String supportAgentStats = '/support/agent/stats';

  // Customer Module - Cart
  static const String cart = '/cart';
  static const String cartItems = '/cart/items';
  static String cartItemById(String itemId) => '/cart/items/$itemId';

  // Customer Module - Orders
  static const String orders = '/orders';
  static String orderById(String id) => '/orders/$id';
  static String orderCancel(String id) => '/orders/$id/cancel';
  static const String customerValidateCart = '/customer/cart/validate';
  static const String customerCreateOrder = '/orders';
  static const String customerActiveOrders = '/orders';
  static const String customerOrderHistory = '/orders';
  static String customerTrackOrder(String orderId) => '/orders/$orderId';
  static String orderTracking(String orderId) => '/orders/$orderId/tracking';
  static String customerCancelOrder(String orderId) => '/orders/$orderId/cancel';
  static String customerReviewOrder(String orderId) => '/customer/orders/$orderId/review';
  static String orderInvoice(String id) => '/orders/$id/invoice';
  static const String customerOrderUpdates = '/customer/order/updates';

  // Customer Module - Addresses
  static const String addresses = '/addresses';
  static String addressById(String id) => '/addresses/$id';
  static String addressDefault(String id) => '/addresses/$id/default';
  static const String customerAddresses = '/addresses';
  static const String customerAddAddress = '/addresses';
  static String customerAddressById(String id) => '/addresses/$id';
  static String customerSetDefaultAddress(String id) => '/addresses/$id/default';

  // Customer Module - Wishlist
  static const String wishlist = '/wishlist';
  static String wishlistProduct(String productId) => '/wishlist/$productId';
  static const String customerWishlist = '/wishlist';
  static const String customerAddToWishlist = '/wishlist';
  static String customerRemoveWishlist(String productId) => '/wishlist/$productId';

  // Customer Module - Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread/count';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';
  static const String customerNotifications = '/notifications';
  static const String customerRegisterDevice = '/customer/notifications/register-device';
  static String customerNotificationRead(String id) => '/notifications/$id/read';
  static const String customerNotificationsReadAll = '/notifications/read-all';

  // Retailer Module - Store & Profile
  static const String retailerRegister = '/retailers/register';
  static const String retailerCheckStoreName = '/retailers/check-name';
  static const String retailerCheckRegistered = '/retailers/check-registered';
  static const String retailerRejection = '/retailers/me/rejection';
  static const String retailerMe = '/retailers/me';
  static const String retailerProfile = '/retailers/me';
  static const String retailerStatus = '/retailers/me/status';
  static const String retailerToggleStatus = '/retailers/me/status';
  static const String retailerRegisterDevice = '/users/register-device';
  static const String retailerRegisterDeviceLegacy = '/retailer/notifications/register-device';
  static const String adminRetailersSearch = '/admin/retailers-search';
  static const String retailerDashboardStats = '/retailer/dashboard/stats';
  static const String retailerSubscription = '/retailers/me/subscription';

  // Uploads Module
  static const String uploadsSingle = '/uploads/upload';
  static const String uploadsMultiple = '/uploads/upload-multiple';
  static String uploadsDelete(String publicId) => '/uploads/delete?publicId=$publicId';

  // Retailer Module - Products / Catalog
  static const String retailerProducts = '/retailer/products';
  static const String retailerCatalogItems = '/retailer/products';
  static String retailerProductById(String id) => '/products/$id';
  static String retailerCatalogItemById(String id) => '/products/$id';
  static String retailerProductStock(String id) => '/products/$id/stock';
  static String retailerCatalogStock(String id) => '/products/$id/stock';

  // Retailer Module - Orders
  static const String retailerOrders = '/retailer/orders';
  static const String retailerLiveOrders = '/retailer/orders';
  static const String retailerOrderHistory = '/retailer/orders';
  static String retailerOrderStatus(String id) => '/retailer/orders/$id/status';
  static String retailerAcceptOrder(String id) => '/retailer/orders/$id/status';
  static String retailerPreparingOrder(String id) => '/retailer/orders/$id/status';
  static String retailerReadyOrder(String id) => '/retailer/orders/$id/status';
  static String retailerRejectOrder(String id) => '/retailer/orders/$id/status';

  // Delivery Partner Module (v1.0 Spec)
  static const String deliveryRegister = '/delivery/register';
  static const String deliveryMe = '/delivery/me';
  static const String deliveryAvailability = '/delivery/me/availability';
  static const String deliveryJobs = '/delivery/jobs';
  static const String deliveryOfferedJobs = '/delivery/jobs?filter=offered';
  static String deliveryJobStatus(String id) => '/delivery/jobs/$id/status';
  static String deliveryJobReject(String id) => '/delivery/jobs/$id/reject';
  static String deliveryRequestQr(String orderId) => '/delivery/jobs/$orderId/request-qr';
  static String deliveryQrStatus(String orderId) => '/delivery/jobs/$orderId/qr-status';
  static const String deliveryMeEarnings = '/delivery/me/earnings';
  static String deliveryEarningsBreakdown({int limit = 50}) => '/delivery/me/earnings/breakdown?limit=$limit';
  static String deliveryAssignmentDelivered(String assignmentId) => '/delivery/assignments/$assignmentId/delivered';
  static const String deliveryAssignments = '/delivery/assignments';
  static const String deliveryCashCollected = '/delivery/me/cash-collected';
  // Legacy aliases
  static const String deliveryKycSubmit = '/delivery/register';
  static const String deliveryKycStatus = '/delivery/me';
  static const String deliveryVerifyFace = '/delivery/biometrics/verify-face';
  static const String deliveryToggleDuty = '/delivery/me/availability';
  static const String deliveryAvailableJobs = '/delivery/jobs';
  static String deliveryAcceptJob(String orderId) => '/delivery/jobs/$orderId/status';
  static String deliveryDeclineJob(String orderId) => '/delivery/jobs/$orderId/reject';
  static String deliveryArrivedStore(String orderId) => '/delivery/jobs/$orderId/status';
  static String deliveryPickup(String orderId) => '/delivery/jobs/$orderId/status';
  static String deliveryArrivedCustomer(String orderId) => '/delivery/jobs/$orderId/status';
  static String deliveryVerifyOtp(String orderId) => '/delivery/jobs/$orderId/status';
  static const String deliveryWalletBalance = '/wallet/balance';
  static const String deliveryWalletTransactions = '/wallet/transactions';
  static const String deliveryInstantPayout = '/wallet/withdrawals';
  static const String walletBalance = '/wallet/balance';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletBankAccounts = '/wallet/bank-accounts';
  static String walletBankAccount(String id) => '/wallet/bank-accounts/$id';
  static const String walletWithdrawals = '/wallet/withdrawals';
  static String walletWithdrawalCancel(String id) => '/wallet/withdrawals/$id/cancel';
  static const String deliveryActiveJob = '/delivery/jobs';
  static const String deliveryJobHistory = '/delivery/jobs';
  static const String deliveryUpdateLocation = '/delivery/me/location';

  // Retailer Payouts & Finance Spec
  static const String retailerPayouts = '/retailer/payouts';
  static const String retailerBankAccount = '/retailers/me/bank-account';
  static const String retailerEarningsSummary = '/retailers/me/earnings/summary';
  static String retailerEarnings({String? status, int? limit, int? skip}) {
    final query = <String>[
      if (status != null && status.isNotEmpty) 'status=$status',
      if (limit != null) 'limit=$limit',
      if (skip != null) 'skip=$skip',
    ];
    return query.isEmpty ? '/retailers/me/earnings' : '/retailers/me/earnings?${query.join('&')}';
  }
  static String retailerSettlements({int? limit, int? skip}) {
    final query = <String>[
      if (limit != null) 'limit=$limit',
      if (skip != null) 'skip=$skip',
    ];
    return query.isEmpty ? '/retailers/me/settlements' : '/retailers/me/settlements?${query.join('&')}';
  }

  // Payments Module
  // Razorpay Public Gateway Key (Client-side Key ID is public & safe for SDK checkout)
  // Injected at compile-time via --dart-define=RAZORPAY_KEY_ID=... or .env
  // NOTE: Key Secret must NEVER be stored in the mobile app; it resides strictly on the backend.
  static const String razorpayLiveKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );
  static const String defaultRazorpayKeyId = razorpayLiveKeyId;

  static const String paymentsCod = '/payments/cod';
  static const String paymentsRazorpayOrder = '/payments/razorpay/order';
  static const String paymentsRazorpayCreateOrder = '/payments/razorpay/order';
  static const String paymentsRazorpayVerify = '/payments/razorpay/verify';
  static const String paymentsRazorpayVerifySignature = '/payments/razorpay/verify';
  static const String paymentsRefund = '/payments/refund';
  static String paymentsRazorpayRefund(String razorpayPaymentId) => '/payments/$razorpayPaymentId/refund';
  static String paymentStatus(String id) => '/payments/$id/status';

  // Zones & Location Modules
  static const String zones = '/zones';
  static const String zonesCheckLocation = '/zones/check-location';
  static const String zonesServiceability = '/zones/serviceability';
  static String zoneByPincode(String pincode) => '/zones/pincode/$pincode';
  static const String locationGeocode = '/location/geocode';
  static const String locationReverseGeocode = '/location/reverse-geocode';
  static const String locationRoute = '/location/route';
  static const String locationOptimalRoute = '/location/optimal-route';

  // Legacy route aliases for backwards compatibility
  static const String customerSearchCatalog = products;
  static const String nearbyStores = customerNearbyStores;
}

