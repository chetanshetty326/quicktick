import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../customer/domain/entities/catalog_entities.dart';
import '../../../customer/domain/entities/hero_banner_entity.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/retailer_entities.dart';
import '../../domain/entities/retailer_finance_entities.dart';
import '../../domain/entities/retailer_registration_status_entity.dart';

enum RetailerRegistrationStatus {
  initial,
  checking,
  notRegistered,
  pendingApproval,
  approved,
  rejected,
  suspended,
}

class RetailerState extends Equatable {
  final bool isLoading;
  final FailureType failureType;
  final bool isStoreOpen;
  final List<OrderEntity> orders;
  final List<ProductEntity> storeProducts;
  final RetailerStoreProfileEntity? profile;
  final RetailerDashboardStatsEntity? dashboardStats;
  final Map<String, dynamic>? latestPushNotification;
  final RetailerSubscriptionEntity? subscription;
  final bool isLoadingSubscription;
  final String? errorMessage;
  final String? successMessage;

  // Registration & Routing State
  final RetailerRegistrationStatus registrationStatus;
  final String? registeredShopName;
  final String? rejectionRemarks;
  final List<RejectedDocumentEntity> rejectedDocuments;
  final String? duplicateShopNameError;
  final Map<String, String> uploadedDocUrls;
  final bool isUploadingDoc;
  final String? uploadDocError;

  // Store Name Availability Check
  final bool isCheckingStoreName;
  final bool? isStoreNameAvailable;
  final String? storeNameCheckMessage;
  // FIX #5: Version counters replace expensive DeepCollectionEquality on large lists.
  final int orderListVersion;
  final int productListVersion;

  // Notifications State
  final int unreadNotificationsCount;
  final List<Map<String, dynamic>> notifications;

  // Finance State (Spec R2 - R5)
  final RetailerEarningsSummaryEntity? earningsSummary;
  final List<RetailerEarningEntity> earningsList;
  final List<RetailerSettlementEntity> settlements;
  final RetailerBankAccountEntity? bankAccount;
  final bool isLoadingFinance;
  final String? financeErrorMessage;
  final String? financeSuccessMessage;
  final bool showSubscriptionRequiredSheet;
  final List<HeroBannerEntity> heroBanners;

  const RetailerState({
    this.isLoading = false,
    this.failureType = FailureType.none,
    this.isStoreOpen = true,
    this.orders = const [],
    this.storeProducts = const [],
    this.profile,
    this.dashboardStats,
    this.latestPushNotification,
    this.subscription,
    this.isLoadingSubscription = false,
    this.errorMessage,
    this.successMessage,
    this.registrationStatus = RetailerRegistrationStatus.initial,
    this.registeredShopName,
    this.rejectionRemarks,
    this.rejectedDocuments = const [],
    this.duplicateShopNameError,
    this.uploadedDocUrls = const {},
    this.isUploadingDoc = false,
    this.uploadDocError,
    this.isCheckingStoreName = false,
    this.isStoreNameAvailable,
    this.storeNameCheckMessage,
    this.orderListVersion = 0,
    this.productListVersion = 0,
    this.unreadNotificationsCount = 0,
    this.notifications = const [],
    this.earningsSummary,
    this.earningsList = const [],
    this.settlements = const [],
    this.bankAccount,
    this.isLoadingFinance = false,
    this.financeErrorMessage,
    this.financeSuccessMessage,
    this.showSubscriptionRequiredSheet = false,
    this.heroBanners = const [],
  });

  bool get isOffline => failureType == FailureType.noInternet;
  bool get isServerDown => failureType == FailureType.serverDown;

  List<OrderEntity> get newOrders =>
      orders.where((o) => o.status == OrderStatus.placed).toList();
  List<OrderEntity> get activePreparingOrders => orders
      .where((o) =>
          o.status == OrderStatus.accepted ||
          o.status == OrderStatus.preparing ||
          o.status == OrderStatus.readyForPickup ||
          o.status == OrderStatus.assigned ||
          o.status == OrderStatus.pickedUp ||
          o.status == OrderStatus.outForDelivery)
      .toList();
  List<OrderEntity> get completedOrders =>
      orders.where((o) => o.status == OrderStatus.delivered).toList();

  double get todayRevenue =>
      completedOrders.fold(0.0, (acc, o) => acc + o.subtotal);

  /// Computes comprehensive real-time dashboard analytics for today's orders & top seller
  RetailerOrderAnalyticsEntity get orderAnalytics {
    final now = DateTime.now();
    // Orders placed today
    final todayList = orders.where((o) {
      final dt = o.createdAt;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }).toList();

    // Effective orders for stats (falls back to orders if test data has older dates)
    final effectiveOrders = todayList.isNotEmpty ? todayList : orders;

    // Today's total count
    final count = todayList.isNotEmpty
        ? todayList.length
        : (dashboardStats?.totalOrders != null && dashboardStats!.totalOrders > 0
            ? dashboardStats!.totalOrders
            : orders.length);

    // Today's revenue: sum of grandTotal for valid (non-cancelled, non-rejected) orders
    double rev = 0.0;
    if (todayList.isNotEmpty) {
      rev = todayList
          .where((o) => o.status != OrderStatus.cancelled && o.status != OrderStatus.rejected && o.status != OrderStatus.failed)
          .fold(0.0, (acc, o) => acc + (o.grandTotal > 0 ? o.grandTotal : o.subtotal));
    } else if (dashboardStats?.todayEarnings != null && dashboardStats!.todayEarnings > 0) {
      rev = dashboardStats!.todayEarnings;
    } else {
      rev = orders
          .where((o) => o.status != OrderStatus.cancelled && o.status != OrderStatus.rejected && o.status != OrderStatus.failed)
          .fold(0.0, (acc, o) => acc + (o.grandTotal > 0 ? o.grandTotal : o.subtotal));
    }

    // Identify Most Ordered Product
    final Map<String, TopOrderedItemEntity> productStats = {};
    for (final order in effectiveOrders) {
      if (order.status == OrderStatus.cancelled || order.status == OrderStatus.rejected) continue;
      for (final item in order.items) {
        final key = item.productId.isNotEmpty ? item.productId : item.nameSnapshot;
        if (key.trim().isEmpty) continue;
        final existing = productStats[key];
        if (existing == null) {
          productStats[key] = TopOrderedItemEntity(
            productId: item.productId,
            name: item.nameSnapshot.isNotEmpty ? item.nameSnapshot : 'Store Item',
            totalQuantity: item.quantity,
            totalRevenue: item.total,
            imageUrl: item.imageUrl,
          );
        } else {
          productStats[key] = TopOrderedItemEntity(
            productId: existing.productId.isNotEmpty ? existing.productId : item.productId,
            name: existing.name.isNotEmpty ? existing.name : item.nameSnapshot,
            totalQuantity: existing.totalQuantity + item.quantity,
            totalRevenue: existing.totalRevenue + item.total,
            imageUrl: existing.imageUrl ?? item.imageUrl,
          );
        }
      }
    }

    TopOrderedItemEntity? topItem;
    if (productStats.isNotEmpty) {
      final sorted = productStats.values.toList()
        ..sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
      topItem = sorted.first;
    }

    return RetailerOrderAnalyticsEntity(
      todayOrdersCount: count,
      todayRevenue: rev,
      mostOrderedItem: topItem,
      pendingOrdersCount: orders.where((o) => o.status == OrderStatus.placed).length,
      preparingOrdersCount: orders.where((o) => o.status == OrderStatus.accepted || o.status == OrderStatus.preparing).length,
      readyOrdersCount: orders.where((o) => o.status == OrderStatus.readyForPickup || o.status == OrderStatus.assigned || o.status == OrderStatus.pickedUp || o.status == OrderStatus.outForDelivery).length,
      deliveredOrdersCount: orders.where((o) => o.status == OrderStatus.delivered).length,
    );
  }

  RetailerState copyWith({
    bool? isLoading,
    FailureType? failureType,
    bool? isStoreOpen,
    List<OrderEntity>? orders,
    List<ProductEntity>? storeProducts,
    RetailerStoreProfileEntity? profile,
    RetailerDashboardStatsEntity? dashboardStats,
    Map<String, dynamic>? latestPushNotification,
    bool clearLatestPushNotification = false,
    RetailerSubscriptionEntity? subscription,
    bool? isLoadingSubscription,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
    RetailerRegistrationStatus? registrationStatus,
    String? registeredShopName,
    String? rejectionRemarks,
    List<RejectedDocumentEntity>? rejectedDocuments,
    String? duplicateShopNameError,
    bool clearDuplicateShopNameError = false,
    Map<String, String>? uploadedDocUrls,
    bool? isUploadingDoc,
    String? uploadDocError,
    bool clearUploadDocError = false,
    bool? isCheckingStoreName,
    bool? isStoreNameAvailable,
    bool clearStoreNameAvailable = false,
    String? storeNameCheckMessage,
    bool clearStoreNameCheckMessage = false,
    int? unreadNotificationsCount,
    List<Map<String, dynamic>>? notifications,
    RetailerEarningsSummaryEntity? earningsSummary,
    List<RetailerEarningEntity>? earningsList,
    List<RetailerSettlementEntity>? settlements,
    RetailerBankAccountEntity? bankAccount,
    bool? isLoadingFinance,
    String? financeErrorMessage,
    String? financeSuccessMessage,
    bool clearFinanceMessages = false,
    bool? showSubscriptionRequiredSheet,
    List<HeroBannerEntity>? heroBanners,
  }) {
    return RetailerState(
      isLoading: isLoading ?? this.isLoading,
      failureType: failureType ?? this.failureType,
      isStoreOpen: isStoreOpen ?? this.isStoreOpen,
      orders: orders ?? this.orders,
      storeProducts: storeProducts ?? this.storeProducts,
      profile: profile ?? this.profile,
      dashboardStats: dashboardStats ?? this.dashboardStats,
      latestPushNotification: clearLatestPushNotification ? null : (latestPushNotification ?? this.latestPushNotification),
      subscription: subscription ?? this.subscription,
      isLoadingSubscription: isLoadingSubscription ?? this.isLoadingSubscription,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
      registrationStatus: registrationStatus ?? this.registrationStatus,
      registeredShopName: registeredShopName ?? this.registeredShopName,
      rejectionRemarks: rejectionRemarks ?? this.rejectionRemarks,
      rejectedDocuments: rejectedDocuments ?? this.rejectedDocuments,
      duplicateShopNameError: clearDuplicateShopNameError ? null : (duplicateShopNameError ?? this.duplicateShopNameError),
      uploadedDocUrls: uploadedDocUrls ?? this.uploadedDocUrls,
      isUploadingDoc: isUploadingDoc ?? this.isUploadingDoc,
      uploadDocError: clearUploadDocError ? null : (uploadDocError ?? this.uploadDocError),
      isCheckingStoreName: isCheckingStoreName ?? this.isCheckingStoreName,
      isStoreNameAvailable: clearStoreNameAvailable ? null : (isStoreNameAvailable ?? this.isStoreNameAvailable),
      storeNameCheckMessage: clearStoreNameCheckMessage ? null : (storeNameCheckMessage ?? this.storeNameCheckMessage),
      orderListVersion: orders != null ? orderListVersion + 1 : orderListVersion,
      productListVersion: storeProducts != null ? productListVersion + 1 : productListVersion,
      unreadNotificationsCount: unreadNotificationsCount ?? this.unreadNotificationsCount,
      notifications: notifications ?? this.notifications,
      earningsSummary: earningsSummary ?? this.earningsSummary,
      earningsList: earningsList ?? this.earningsList,
      settlements: settlements ?? this.settlements,
      bankAccount: bankAccount ?? this.bankAccount,
      isLoadingFinance: isLoadingFinance ?? this.isLoadingFinance,
      financeErrorMessage: clearFinanceMessages ? null : (financeErrorMessage ?? this.financeErrorMessage),
      financeSuccessMessage: clearFinanceMessages ? null : (financeSuccessMessage ?? this.financeSuccessMessage),
      showSubscriptionRequiredSheet: showSubscriptionRequiredSheet ?? this.showSubscriptionRequiredSheet,
      heroBanners: heroBanners ?? this.heroBanners,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isStoreOpen,
        orderListVersion,
        productListVersion,
        profile,
        dashboardStats,
        latestPushNotification,
        subscription,
        isLoadingSubscription,
        errorMessage,
        successMessage,
        registrationStatus,
        registeredShopName,
        rejectionRemarks,
        rejectedDocuments,
        duplicateShopNameError,
        uploadedDocUrls,
        isUploadingDoc,
        uploadDocError,
        isCheckingStoreName,
        isStoreNameAvailable,
        storeNameCheckMessage,
        unreadNotificationsCount,
        notifications,
        earningsSummary,
        earningsList,
        settlements,
        bankAccount,
        isLoadingFinance,
        financeErrorMessage,
        financeSuccessMessage,
        showSubscriptionRequiredSheet,
        heroBanners,
        failureType,
      ];
}
