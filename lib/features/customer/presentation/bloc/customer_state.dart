import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../order/data/datasources/payment_remote_data_source.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/cart_optimization_entity.dart';
import '../../domain/entities/handwritten_item_match_entity.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/entities/customer_address_entity.dart';
import '../../domain/entities/hero_banner_entity.dart';
import '../../domain/entities/coupon_entity.dart';
import '../../domain/entities/cart_pricing_entity.dart';
import '../../../../core/localization/app_strings.dart';

enum ProductSortOption {
  relevance,
  priceLowToHigh,
  priceHighToLow,
  ratingHighToLow,
}

enum StoreFilterType {
  all,
  express,
}

class CustomerState extends Equatable {
  final bool isLoading;
  final FailureType failureType;
  final List<CategoryEntity> categories;
  final List<StoreEntity> stores;
  final List<StoreEntity> searchStores;
  final List<ProductEntity> allProducts;
  final List<ProductEntity> filteredProducts;
  final List<ProductEntity> recommendations;
  final String selectedCategoryId;
  final String searchQuery;
  final ProductSortOption sortOption;
  final bool inStockOnly;
  final bool fastDeliveryOnly;
  final bool dealsOnly;
  final String? selectedFoodType;
  final List<CartItemEntity> cartItems;
  final String selectedAddress;
  final List<CustomerAddressEntity> savedAddresses;
  final List<OrderEntity> myOrders;
  final OrderEntity? latestPlacedOrder;
  final bool isCartValidating;
  final Map<String, dynamic>? cartValidation;
  final Set<String> wishlistProductIds;
  final List<Map<String, dynamic>> notifications;
  final Map<String, dynamic>? latestPushNotification;
  final String? errorMessage;
  final String? successMessage;
  final bool isPaymentProcessing;
  final RazorpayOrderModel? activeRazorpayOrder;
  final PaymentVerificationModel? paymentVerification;
  final String? paymentErrorMessage;
  final ProductEntity? multiRetailerConflictProduct;
  final StoreEntity? selectedStore;
  final int currentPage;
  final bool isLoadingMoreProducts;
  final bool hasReachedMaxProducts;
  final bool isCheckingLocation;
  final bool inZone;
  final String? zoneId;
  final String? zoneName;
  final String? outOfDeliveryZoneMessage;
  final double? activeLat;
  final double? activeLng;
  final int unreadNotificationsCount;
  final Map<String, dynamic>? paymentStatus;
  final int productListVersion;
  final int storeListVersion;
  final List<HeroBannerEntity> heroBanners;
  final DateTime? heroBannersFetchedAt;
  final List<CouponEntity> availableCoupons;
  final CouponValidationEntity? appliedCoupon;
  final bool isApplyingCoupon;
  final String? couponErrorMessage;
  final StoreFilterType storeFilter;
  final Set<String> reviewedOrderIds;
  final bool isSubmittingReview;
  final CartPricingEntity? cartPricing;
  final double? zoneDeliveryFee;
  final double? zonePlatformFee;
  final double? zoneFreeDeliveryThreshold;
  final double? zoneMinOrderAmount;
  final double selectedTip;
  final bool isDownloadingInvoice;
  final String? lastDownloadedInvoicePath;
  final List<String> searchHistory;
  final AppLanguage language;
  final CartOptimizationEntity? cartOptimization;
  final bool isOptimizingCart;
  final bool isScanningHandwrittenList;
  final HandwrittenListScanResultEntity? handwrittenScanResult;
  final String? handwrittenScanError;

  const CustomerState({
    this.isLoading = false,
    this.failureType = FailureType.none,
    this.isCheckingLocation = false,
    this.inZone = true,
    this.zoneId,
    this.zoneName,
    this.outOfDeliveryZoneMessage,
    this.activeLat,
    this.activeLng,
    this.unreadNotificationsCount = 0,
    this.paymentStatus,
    this.categories = const [],
    this.stores = const [],
    this.searchStores = const [],
    this.allProducts = const [],
    this.filteredProducts = const [],
    this.recommendations = const [],
    this.selectedCategoryId = 'cat_all',
    this.searchQuery = '',
    this.sortOption = ProductSortOption.relevance,
    this.inStockOnly = false,
    this.fastDeliveryOnly = false,
    this.dealsOnly = false,
    this.selectedFoodType,
    this.cartItems = const [],
    this.selectedAddress = 'Select Delivery Address',
    this.savedAddresses = const [],
    this.myOrders = const [],
    this.latestPlacedOrder,
    this.isCartValidating = false,
    this.cartValidation,
    this.wishlistProductIds = const {},
    this.notifications = const [],
    this.latestPushNotification,
    this.errorMessage,
    this.successMessage,
    this.isPaymentProcessing = false,
    this.activeRazorpayOrder,
    this.paymentVerification,
    this.paymentErrorMessage,
    this.multiRetailerConflictProduct,
    this.selectedStore,
    this.currentPage = 1,
    this.isLoadingMoreProducts = false,
    this.hasReachedMaxProducts = false,
    this.productListVersion = 0,
    this.storeListVersion = 0,
    this.heroBanners = const [],
    this.heroBannersFetchedAt,
    this.availableCoupons = const [],
    this.appliedCoupon,
    this.isApplyingCoupon = false,
    this.couponErrorMessage,
    this.storeFilter = StoreFilterType.all,
    this.reviewedOrderIds = const {},
    this.isSubmittingReview = false,
    this.cartPricing,
    this.zoneDeliveryFee,
    this.zonePlatformFee,
    this.zoneFreeDeliveryThreshold,
    this.zoneMinOrderAmount,
    this.selectedTip = 0.0,
    this.isDownloadingInvoice = false,
    this.lastDownloadedInvoicePath,
    this.searchHistory = const [],
    this.language = AppLanguage.english,
    this.cartOptimization,
    this.isOptimizingCart = false,
    this.isScanningHandwrittenList = false,
    this.handwrittenScanResult,
    this.handwrittenScanError,
  });

  AppStrings get strings => AppStrings(language);

  bool get isOffline => failureType == FailureType.noInternet;
  bool get isServerDown => failureType == FailureType.serverDown;

  /// Deduplicated, zone-scoped stores sorted with open shops first.
  List<StoreEntity> get zoneStores {
    final result = <StoreEntity>[];
    final seenIds = <String>{};
    for (final store in stores) {
      if (zoneId != null &&
          zoneId!.isNotEmpty &&
          store.zoneId != null &&
          store.zoneId!.isNotEmpty &&
          store.zoneId != zoneId) {
        continue;
      }
      if (seenIds.add(store.id)) {
        result.add(store);
      }
    }
    if (result.isEmpty && stores.isNotEmpty) {
      for (final store in stores) {
        if (seenIds.add(store.id)) {
          result.add(store);
        }
      }
    }
    result.sort((a, b) {
      if (a.isOpen == b.isOpen) return 0;
      return a.isOpen ? -1 : 1;
    });
    return result;
  }

  /// Stores visible after applying the active [storeFilter] (`all` vs `express`).
  List<StoreEntity> get filteredZoneStores {
    final scoped = zoneStores;
    if (storeFilter == StoreFilterType.express) {
      return scoped.where((s) => s.isExpress).toList();
    }
    return scoped;
  }

  int get openStoreCount => zoneStores.where((s) => s.isOpen).length;

  int get expressStoreCount => zoneStores.where((s) => s.isExpress).length;

  bool get _hasValidBackendPricing {
    if (cartPricing == null || cartPricing!.subtotal <= 0 || cartPricing!.total <= 0) {
      return false;
    }
    // Strict integrity check: The backend pricing is ONLY valid if its subtotal
    // matches the items currently in the cart. If user added/removed items,
    // the old backend pricing is obsolete.
    final localSubtotal = cartItems.fold(0.0, (acc, item) => acc + item.total);
    return (localSubtotal - cartPricing!.subtotal).abs() < 0.05;
  }

  double get cartSubtotal {
    final localSubtotal = cartItems.fold(0.0, (acc, item) => acc + item.total);
    if (cartItems.isEmpty) return 0.0;
    if (_hasValidBackendPricing) return cartPricing!.subtotal;
    return localSubtotal;
  }

  double get effectiveZoneDeliveryFee => zoneDeliveryFee ?? 15.0;

  double get effectiveFreeDeliveryThreshold {
    if (cartPricing != null && cartPricing!.freeDeliveryThreshold > 0) {
      return cartPricing!.freeDeliveryThreshold;
    }
    if (zoneFreeDeliveryThreshold != null) {
      return zoneFreeDeliveryThreshold!;
    }
    if (cartPricing != null) {
      return cartPricing!.freeDeliveryThreshold;
    }
    return 199.0;
  }

  double get effectiveMinOrderAmount {
    if (cartPricing != null && cartPricing!.minOrderAmount > 0) {
      return cartPricing!.minOrderAmount;
    }
    return zoneMinOrderAmount ?? 0.0;
  }

  bool get isBelowMinOrder =>
      cartItems.isNotEmpty &&
      effectiveMinOrderAmount > 0 &&
      cartSubtotal < effectiveMinOrderAmount;

  double get deliveryFee {
    if (cartItems.isEmpty) return 0.0;
    if (_hasValidBackendPricing) return cartPricing!.deliveryFee;
    if (appliedCoupon?.freeDelivery == true) return 0.0;

    final baseDelivery = zoneDeliveryFee ?? 15.0;
    if (baseDelivery <= 0) return 0.0;

    final threshold = effectiveFreeDeliveryThreshold;
    if (threshold > 0 && cartSubtotal >= threshold) return 0.0;
    return baseDelivery;
  }

  double get couponDiscount => _hasValidBackendPricing
      ? cartPricing!.discount
      : (appliedCoupon?.discount ?? 0.0);

  double get platformFee => cartItems.isEmpty
      ? 0.0
      : (_hasValidBackendPricing ? cartPricing!.platformFee : (zonePlatformFee ?? 5.0));

  double get taxAmount {
    if (cartItems.isEmpty) return 0.0;
    if (_hasValidBackendPricing) {
      return cartPricing!.tax > 0 ? cartPricing!.tax : cartPricing!.taxBreakdown.total;
    }
    // High-fidelity local GST calculation matching backend order calculation
    return cartItems.fold(0.0, (acc, item) {
      final pct = item.product.taxPercent ?? 0.0;
      return acc + (item.total * pct / 100.0);
    });
  }

  double get tipAmount => (_hasValidBackendPricing && cartPricing!.tip > 0)
      ? cartPricing!.tip
      : selectedTip;

  double get cartSubtotalPlusFees {
    if (cartItems.isEmpty) return 0.0;
    if (_hasValidBackendPricing) return cartPricing!.total;
    return cartSubtotal + deliveryFee + platformFee + taxAmount;
  }

  double get cartGrandTotal {
    if (cartItems.isEmpty) return 0.0;
    if (_hasValidBackendPricing) return cartPricing!.total.clamp(0.0, 999999.0);
    // Offline / guest local calculation fallback matching backend order calculation:
    return ((cartSubtotal + deliveryFee + platformFee + taxAmount + tipAmount - couponDiscount).clamp(0.0, 999999.0));
  }
  int get cartTotalItems => cartItems.fold(0, (acc, item) => acc + item.quantity);

  CustomerState copyWith({
    bool? isLoading,
    FailureType? failureType,
    List<CategoryEntity>? categories,
    List<StoreEntity>? stores,
    List<StoreEntity>? searchStores,
    List<ProductEntity>? allProducts,
    List<ProductEntity>? filteredProducts,
    List<ProductEntity>? recommendations,
    String? selectedCategoryId,
    String? searchQuery,
    ProductSortOption? sortOption,
    bool? inStockOnly,
    bool? fastDeliveryOnly,
    bool? dealsOnly,
    String? selectedFoodType,
    bool clearFoodType = false,
    List<CartItemEntity>? cartItems,
    String? selectedAddress,
    List<CustomerAddressEntity>? savedAddresses,
    List<OrderEntity>? myOrders,
    OrderEntity? latestPlacedOrder,
    bool clearPlacedOrder = false,
    bool? isCartValidating,
    Map<String, dynamic>? cartValidation,
    Set<String>? wishlistProductIds,
    List<Map<String, dynamic>>? notifications,
    Map<String, dynamic>? latestPushNotification,
    bool clearLatestPushNotification = false,
    String? errorMessage,
    String? successMessage,
    bool? isPaymentProcessing,
    RazorpayOrderModel? activeRazorpayOrder,
    bool clearActiveRazorpayOrder = false,
    PaymentVerificationModel? paymentVerification,
    bool clearPaymentVerification = false,
    String? paymentErrorMessage,
    ProductEntity? multiRetailerConflictProduct,
    bool clearMultiRetailerConflict = false,
    StoreEntity? selectedStore,
    bool clearSelectedStore = false,
    int? currentPage,
    bool? isLoadingMoreProducts,
    bool? hasReachedMaxProducts,
    bool? isCheckingLocation,
    bool? inZone,
    String? zoneId,
    String? zoneName,
    String? outOfDeliveryZoneMessage,
    bool clearOutOfDeliveryZoneMessage = false,
    double? activeLat,
    double? activeLng,
    int? unreadNotificationsCount,
    Map<String, dynamic>? paymentStatus,
    bool clearPaymentStatus = false,
    List<HeroBannerEntity>? heroBanners,
    DateTime? heroBannersFetchedAt,
    List<CouponEntity>? availableCoupons,
    CouponValidationEntity? appliedCoupon,
    bool clearAppliedCoupon = false,
    bool? isApplyingCoupon,
    String? couponErrorMessage,
    bool clearCouponError = false,
    StoreFilterType? storeFilter,
    Set<String>? reviewedOrderIds,
    bool? isSubmittingReview,
    CartPricingEntity? cartPricing,
    bool clearCartPricing = false,
    double? zoneDeliveryFee,
    double? zonePlatformFee,
    double? zoneFreeDeliveryThreshold,
    double? zoneMinOrderAmount,
    bool clearZonePricing = false,
    double? selectedTip,
    bool? isDownloadingInvoice,
    String? lastDownloadedInvoicePath,
    bool clearLastDownloadedInvoicePath = false,
    List<String>? searchHistory,
    AppLanguage? language,
    CartOptimizationEntity? cartOptimization,
    bool clearCartOptimization = false,
    bool? isOptimizingCart,
    bool? isScanningHandwrittenList,
    HandwrittenListScanResultEntity? handwrittenScanResult,
    bool clearHandwrittenScanResult = false,
    String? handwrittenScanError,
    bool clearHandwrittenScanError = false,
  }) {
    return CustomerState(
      isLoading: isLoading ?? this.isLoading,
      failureType: failureType ?? this.failureType,
      isCheckingLocation: isCheckingLocation ?? this.isCheckingLocation,
      inZone: inZone ?? this.inZone,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      outOfDeliveryZoneMessage: clearOutOfDeliveryZoneMessage ? null : (outOfDeliveryZoneMessage ?? this.outOfDeliveryZoneMessage),
      activeLat: activeLat ?? this.activeLat,
      activeLng: activeLng ?? this.activeLng,
      unreadNotificationsCount: unreadNotificationsCount ?? this.unreadNotificationsCount,
      paymentStatus: clearPaymentStatus ? null : (paymentStatus ?? this.paymentStatus),
      categories: categories ?? this.categories,
      stores: stores ?? this.stores,
      searchStores: searchStores ?? this.searchStores,
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      recommendations: recommendations ?? this.recommendations,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      searchQuery: searchQuery ?? this.searchQuery,
      sortOption: sortOption ?? this.sortOption,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      fastDeliveryOnly: fastDeliveryOnly ?? this.fastDeliveryOnly,
      dealsOnly: dealsOnly ?? this.dealsOnly,
      selectedFoodType: clearFoodType ? null : (selectedFoodType ?? this.selectedFoodType),
      cartItems: cartItems ?? this.cartItems,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      myOrders: myOrders ?? this.myOrders,
      latestPlacedOrder: clearPlacedOrder ? null : (latestPlacedOrder ?? this.latestPlacedOrder),
      isCartValidating: isCartValidating ?? this.isCartValidating,
      cartValidation: cartValidation ?? this.cartValidation,
      wishlistProductIds: wishlistProductIds ?? this.wishlistProductIds,
      notifications: notifications ?? this.notifications,
      latestPushNotification: clearLatestPushNotification ? null : (latestPushNotification ?? this.latestPushNotification),
      errorMessage: errorMessage,
      successMessage: successMessage,
      isPaymentProcessing: isPaymentProcessing ?? this.isPaymentProcessing,
      activeRazorpayOrder: clearActiveRazorpayOrder ? null : (activeRazorpayOrder ?? this.activeRazorpayOrder),
      paymentVerification: clearPaymentVerification ? null : (paymentVerification ?? this.paymentVerification),
      paymentErrorMessage: paymentErrorMessage,
      multiRetailerConflictProduct: clearMultiRetailerConflict ? null : (multiRetailerConflictProduct ?? this.multiRetailerConflictProduct),
      selectedStore: clearSelectedStore ? null : (selectedStore ?? this.selectedStore),
      currentPage: currentPage ?? this.currentPage,
      isLoadingMoreProducts: isLoadingMoreProducts ?? this.isLoadingMoreProducts,
      hasReachedMaxProducts: hasReachedMaxProducts ?? this.hasReachedMaxProducts,
      // FIX #2: Auto-increment version counters when their respective lists change
      productListVersion: (allProducts != null || filteredProducts != null || recommendations != null)
          ? productListVersion + 1
          : productListVersion,
      storeListVersion: (stores != null || searchStores != null)
          ? storeListVersion + 1
          : storeListVersion,
      heroBanners: heroBanners ?? this.heroBanners,
      heroBannersFetchedAt: heroBannersFetchedAt ?? this.heroBannersFetchedAt,
      availableCoupons: availableCoupons ?? this.availableCoupons,
      appliedCoupon: clearAppliedCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      isApplyingCoupon: isApplyingCoupon ?? this.isApplyingCoupon,
      couponErrorMessage: clearCouponError ? null : (couponErrorMessage ?? this.couponErrorMessage),
      storeFilter: storeFilter ?? this.storeFilter,
      reviewedOrderIds: reviewedOrderIds ?? this.reviewedOrderIds,
      isSubmittingReview: isSubmittingReview ?? this.isSubmittingReview,
      cartPricing: clearCartPricing ? null : (cartPricing ?? this.cartPricing),
      zoneDeliveryFee: clearZonePricing ? null : (zoneDeliveryFee ?? this.zoneDeliveryFee),
      zonePlatformFee: clearZonePricing ? null : (zonePlatformFee ?? this.zonePlatformFee),
      zoneFreeDeliveryThreshold: clearZonePricing ? null : (zoneFreeDeliveryThreshold ?? this.zoneFreeDeliveryThreshold),
      zoneMinOrderAmount: clearZonePricing ? null : (zoneMinOrderAmount ?? this.zoneMinOrderAmount),
      selectedTip: selectedTip ?? this.selectedTip,
      isDownloadingInvoice: isDownloadingInvoice ?? this.isDownloadingInvoice,
      lastDownloadedInvoicePath: clearLastDownloadedInvoicePath ? null : (lastDownloadedInvoicePath ?? this.lastDownloadedInvoicePath),
      searchHistory: searchHistory ?? this.searchHistory,
      language: language ?? this.language,
      cartOptimization: clearCartOptimization ? null : (cartOptimization ?? this.cartOptimization),
      isOptimizingCart: isOptimizingCart ?? this.isOptimizingCart,
      isScanningHandwrittenList: isScanningHandwrittenList ?? this.isScanningHandwrittenList,
      handwrittenScanResult: clearHandwrittenScanResult ? null : (handwrittenScanResult ?? this.handwrittenScanResult),
      handwrittenScanError: clearHandwrittenScanError ? null : (handwrittenScanError ?? this.handwrittenScanError),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        categories,           // small list, safe to deep-compare
        productListVersion,   // replaces: allProducts, filteredProducts, recommendations
        storeListVersion,     // replaces: stores, searchStores
        selectedCategoryId,
        searchQuery,
        sortOption,
        inStockOnly,
        fastDeliveryOnly,
        dealsOnly,
        selectedFoodType,
        cartItems,            // small list (< 20 items typically), safe
        selectedAddress,
        savedAddresses,       // small list
        myOrders,             // small list
        latestPlacedOrder,
        isCartValidating,
        cartValidation,
        wishlistProductIds,
        notifications,
        latestPushNotification,
        errorMessage,
        successMessage,
        isPaymentProcessing,
        activeRazorpayOrder,
        paymentVerification,
        paymentErrorMessage,
        multiRetailerConflictProduct,
        selectedStore,
        currentPage,
        isLoadingMoreProducts,
        hasReachedMaxProducts,
        isCheckingLocation,
        inZone,
        zoneId,
        zoneName,
        outOfDeliveryZoneMessage,
        unreadNotificationsCount,
        paymentStatus,
        activeLat,
        activeLng,
        heroBanners,
        heroBannersFetchedAt,
        availableCoupons,
        appliedCoupon,
        isApplyingCoupon,
        couponErrorMessage,
        storeFilter,
        failureType,
        reviewedOrderIds,
        isSubmittingReview,
        cartPricing,
        zoneDeliveryFee,
        zonePlatformFee,
        zoneFreeDeliveryThreshold,
        zoneMinOrderAmount,
        selectedTip,
        isDownloadingInvoice,
        lastDownloadedInvoicePath,
        searchHistory,
        language,
        cartOptimization,
        isOptimizingCart,
        isScanningHandwrittenList,
        handwrittenScanResult,
        handwrittenScanError,
      ];
}
