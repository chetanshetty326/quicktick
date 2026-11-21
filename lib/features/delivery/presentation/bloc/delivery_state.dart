import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../customer/domain/entities/hero_banner_entity.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/delivery_models.dart';
import '../../domain/entities/delivery_api_entities.dart';
import '../../domain/entities/delivery_notification_entity.dart';
import '../../domain/entities/rider_wallet_entities.dart';
import '../../domain/entities/doorstep_qr_entity.dart';

class DeliveryState extends Equatable {
  final bool isLoading;
  final FailureType failureType;
  final bool isOnline;
  final String offlineReason;
  final bool isFaceVerifiedToday;
  final DateTime? lastFaceVerifiedTime;
  final RiderKYCEntity riderKYC;
  final DeliveryPartnerProfileEntity? apiProfile;
  final DeliveryEarningsEntity? apiEarnings;
  final List<DeliveryJobEntity> apiJobs;
  final List<OrderEntity> availableJobs;
  final List<OrderEntity> activeTrips;
  final List<OrderEntity> completedTrips;
  final DeliveryTripStep activeJobStep;
  final Set<String> verifiedItemChecklist;
  final double walletBalance;
  final List<DeliveryTransactionEntity> transactions;
  final List<RiderBankAccountEntity> bankAccounts;
  final List<RiderWithdrawalEntity> withdrawals;
  final bool isWalletLoading;
  final bool isWithdrawalSubmitting;
  final List<DeliveryOfferEntity> offers;
  final List<HeroBannerEntity> heroBanners;
  final OrderEntity? incomingJobAlert;
  final bool isPartnerNotApproved;
  final List<DeliveryNotificationEntity> notifications;
  final int unreadNotificationsCount;
  final Map<String, dynamic>? latestPushNotification;
  final List<EarningsBreakdownRowEntity> earningsBreakdown;
  final CashCollectedSummaryEntity? cashCollectedSummary;
  final bool isLoadingEarnings;
  final bool isLoadingCashCollected;
  final String? errorMessage;
  final String? successMessage;
  final String? zoneMismatchNotice;
  final bool isCrossZoneEnabled;
  final DoorstepQrEntity? activeDoorstepQr;
  final QrPaymentStatusEntity? qrPaymentStatus;
  final bool isRequestingQr;
  final bool isPollingQr;
  final String? qrError;

  const DeliveryState({
    this.isLoading = false,
    this.failureType = FailureType.none,
    this.isOnline = true,
    this.offlineReason = 'None',
    this.isFaceVerifiedToday = false,
    this.lastFaceVerifiedTime,
    this.riderKYC = const RiderKYCEntity(),
    this.apiProfile,
    this.apiEarnings,
    this.earningsBreakdown = const [],
    this.cashCollectedSummary,
    this.isLoadingEarnings = false,
    this.isLoadingCashCollected = false,
    this.apiJobs = const [],
    this.availableJobs = const [],
    this.activeTrips = const [],
    this.completedTrips = const [],
    this.activeJobStep = DeliveryTripStep.enRouteStore,
    this.verifiedItemChecklist = const {},
    this.walletBalance = 0.0,
    this.transactions = const [],
    this.bankAccounts = const [],
    this.withdrawals = const [],
    this.isWalletLoading = false,
    this.isWithdrawalSubmitting = false,
    this.offers = const [],
    this.heroBanners = const [],
    this.incomingJobAlert,
    this.isPartnerNotApproved = false,
    this.notifications = const [],
    this.unreadNotificationsCount = 0,
    this.latestPushNotification,
    this.errorMessage,
    this.successMessage,
    this.zoneMismatchNotice,
    this.isCrossZoneEnabled = true,
    this.activeDoorstepQr,
    this.qrPaymentStatus,
    this.isRequestingQr = false,
    this.isPollingQr = false,
    this.qrError,
  });

  String? get currentZoneId => apiProfile?.zoneId ?? (riderKYC.zoneId != null && riderKYC.zoneId!.isNotEmpty ? riderKYC.zoneId : null);
  String get currentZoneName {
    if (riderKYC.zoneName != null && riderKYC.zoneName!.isNotEmpty) {
      final name = riderKYC.zoneName!;
      return name.toLowerCase().contains('zone') ? name : '$name Zone';
    }
    if (apiProfile?.zoneName != null && apiProfile!.zoneName!.isNotEmpty) {
      final name = apiProfile!.zoneName!;
      return name.toLowerCase().contains('zone') ? name : '$name Zone';
    }
    if (currentZoneId != null && currentZoneId!.isNotEmpty) {
      return 'Delivery Zone';
    }
    return 'Unassigned Zone';
  }

  bool get hasZoneMismatch => zoneMismatchNotice != null && zoneMismatchNotice!.isNotEmpty;

  double get todayEarnings =>
      apiEarnings?.today.amount ??
      (completedTrips.length * 35.0 + (completedTrips.length >= 5 ? 100.0 : 0.0));

  int get todayCompletedCount =>
      apiEarnings?.today.deliveries ?? completedTrips.length;

  bool get isNetworkOffline => failureType == FailureType.noInternet;
  bool get isServerDown => failureType == FailureType.serverDown;

  DeliveryState copyWith({
    bool? isLoading,
    FailureType? failureType,
    bool? isOnline,
    String? offlineReason,
    bool? isFaceVerifiedToday,
    DateTime? lastFaceVerifiedTime,
    RiderKYCEntity? riderKYC,
    DeliveryPartnerProfileEntity? apiProfile,
    DeliveryEarningsEntity? apiEarnings,
    List<EarningsBreakdownRowEntity>? earningsBreakdown,
    CashCollectedSummaryEntity? cashCollectedSummary,
    bool? isLoadingEarnings,
    bool? isLoadingCashCollected,
    List<DeliveryJobEntity>? apiJobs,
    List<OrderEntity>? availableJobs,
    List<OrderEntity>? activeTrips,
    List<OrderEntity>? completedTrips,
    DeliveryTripStep? activeJobStep,
    Set<String>? verifiedItemChecklist,
    double? walletBalance,
    List<DeliveryTransactionEntity>? transactions,
    List<RiderBankAccountEntity>? bankAccounts,
    List<RiderWithdrawalEntity>? withdrawals,
    bool? isWalletLoading,
    bool? isWithdrawalSubmitting,
    List<DeliveryOfferEntity>? offers,
    List<HeroBannerEntity>? heroBanners,
    OrderEntity? incomingJobAlert,
    bool clearIncomingAlert = false,
    bool? isPartnerNotApproved,
    List<DeliveryNotificationEntity>? notifications,
    int? unreadNotificationsCount,
    Map<String, dynamic>? latestPushNotification,
    bool clearLatestPushNotification = false,
    String? errorMessage,
    String? successMessage,
    String? zoneMismatchNotice,
    bool clearZoneMismatch = false,
    bool? isCrossZoneEnabled,
    bool clearMessages = false,
    DoorstepQrEntity? activeDoorstepQr,
    bool clearDoorstepQr = false,
    QrPaymentStatusEntity? qrPaymentStatus,
    bool clearQrPaymentStatus = false,
    bool? isRequestingQr,
    bool? isPollingQr,
    String? qrError,
    bool clearQrError = false,
  }) {
    return DeliveryState(
      isLoading: isLoading ?? this.isLoading,
      failureType: failureType ?? this.failureType,
      isOnline: isOnline ?? this.isOnline,
      offlineReason: offlineReason ?? this.offlineReason,
      isFaceVerifiedToday: isFaceVerifiedToday ?? this.isFaceVerifiedToday,
      lastFaceVerifiedTime: lastFaceVerifiedTime ?? this.lastFaceVerifiedTime,
      riderKYC: riderKYC ?? this.riderKYC,
      apiProfile: apiProfile ?? this.apiProfile,
      apiEarnings: apiEarnings ?? this.apiEarnings,
      earningsBreakdown: earningsBreakdown ?? this.earningsBreakdown,
      cashCollectedSummary: cashCollectedSummary ?? this.cashCollectedSummary,
      isLoadingEarnings: isLoadingEarnings ?? this.isLoadingEarnings,
      isLoadingCashCollected: isLoadingCashCollected ?? this.isLoadingCashCollected,
      apiJobs: apiJobs ?? this.apiJobs,
      availableJobs: availableJobs ?? this.availableJobs,
      activeTrips: activeTrips ?? this.activeTrips,
      completedTrips: completedTrips ?? this.completedTrips,
      activeJobStep: activeJobStep ?? this.activeJobStep,
      verifiedItemChecklist: verifiedItemChecklist ?? this.verifiedItemChecklist,
      walletBalance: walletBalance ?? this.walletBalance,
      transactions: transactions ?? this.transactions,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      withdrawals: withdrawals ?? this.withdrawals,
      isWalletLoading: isWalletLoading ?? this.isWalletLoading,
      isWithdrawalSubmitting: isWithdrawalSubmitting ?? this.isWithdrawalSubmitting,
      offers: offers ?? this.offers,
      heroBanners: heroBanners ?? this.heroBanners,
      incomingJobAlert: clearIncomingAlert ? null : (incomingJobAlert ?? this.incomingJobAlert),
      isPartnerNotApproved: isPartnerNotApproved ?? this.isPartnerNotApproved,
      notifications: notifications ?? this.notifications,
      unreadNotificationsCount: unreadNotificationsCount ?? this.unreadNotificationsCount,
      latestPushNotification: clearLatestPushNotification ? null : (latestPushNotification ?? this.latestPushNotification),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
      zoneMismatchNotice: clearZoneMismatch ? null : (zoneMismatchNotice ?? this.zoneMismatchNotice),
      isCrossZoneEnabled: isCrossZoneEnabled ?? this.isCrossZoneEnabled,
      activeDoorstepQr: clearDoorstepQr ? null : (activeDoorstepQr ?? this.activeDoorstepQr),
      qrPaymentStatus: clearQrPaymentStatus ? null : (qrPaymentStatus ?? this.qrPaymentStatus),
      isRequestingQr: isRequestingQr ?? this.isRequestingQr,
      isPollingQr: isPollingQr ?? this.isPollingQr,
      qrError: clearQrError ? null : (qrError ?? this.qrError),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isOnline,
        offlineReason,
        isFaceVerifiedToday,
        lastFaceVerifiedTime,
        riderKYC,
        apiProfile,
        apiEarnings,
        earningsBreakdown,
        cashCollectedSummary,
        isLoadingEarnings,
        isLoadingCashCollected,
        apiJobs,
        availableJobs,
        activeTrips,
        completedTrips,
        activeJobStep,
        verifiedItemChecklist,
        walletBalance,
        transactions,
        bankAccounts,
        withdrawals,
        isWalletLoading,
        isWithdrawalSubmitting,
        offers,
        heroBanners,
        incomingJobAlert,
        isPartnerNotApproved,
        notifications,
        unreadNotificationsCount,
        latestPushNotification,
        errorMessage,
        successMessage,
        zoneMismatchNotice,
        isCrossZoneEnabled,
        activeDoorstepQr,
        qrPaymentStatus,
        isRequestingQr,
        isPollingQr,
        qrError,
        failureType,
      ];
}
