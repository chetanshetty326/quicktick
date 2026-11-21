import 'package:equatable/equatable.dart';

class RetailerStoreProfileEntity extends Equatable {
  final String id;
  final String storeName;
  final String ownerName;
  final String email;
  final String phone;
  final String fssaiNumber;
  final String gstin;
  final String address;
  final bool isOpen;
  final bool isVerified;
  final double rating;
  final double? latitude;
  final double? longitude;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED'
  final String? zoneId;
  final String category;
  final String? shopPhotoUrl;

  const RetailerStoreProfileEntity({
    required this.id,
    required this.storeName,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.fssaiNumber,
    required this.gstin,
    required this.address,
    required this.isOpen,
    required this.isVerified,
    this.rating = 4.8,
    this.latitude,
    this.longitude,
    this.status = 'PENDING',
    this.zoneId,
    this.category = 'General',
    this.shopPhotoUrl,
  });

  bool get isApproved => status.toUpperCase() == 'APPROVED' || (isVerified && status.toUpperCase() != 'REJECTED' && status.toUpperCase() != 'SUSPENDED');
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isSuspended => status.toUpperCase() == 'SUSPENDED';

  RetailerStoreProfileEntity copyWith({
    String? id,
    String? storeName,
    String? ownerName,
    String? email,
    String? phone,
    String? fssaiNumber,
    String? gstin,
    String? address,
    bool? isOpen,
    bool? isVerified,
    double? rating,
    double? latitude,
    double? longitude,
    String? status,
    String? zoneId,
    String? category,
    String? shopPhotoUrl,
  }) {
    return RetailerStoreProfileEntity(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      ownerName: ownerName ?? this.ownerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fssaiNumber: fssaiNumber ?? this.fssaiNumber,
      gstin: gstin ?? this.gstin,
      address: address ?? this.address,
      isOpen: isOpen ?? this.isOpen,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      zoneId: zoneId ?? this.zoneId,
      category: category ?? this.category,
      shopPhotoUrl: shopPhotoUrl ?? this.shopPhotoUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        storeName,
        ownerName,
        email,
        phone,
        fssaiNumber,
        gstin,
        address,
        isOpen,
        isVerified,
        rating,
        latitude,
        longitude,
        status,
        zoneId,
        category,
        shopPhotoUrl,
      ];
}

class RetailerDashboardStatsEntity extends Equatable {
  final double todayEarnings;
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final double commissionDeducted;
  final double netPayout;

  const RetailerDashboardStatsEntity({
    required this.todayEarnings,
    required this.totalOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.commissionDeducted,
    required this.netPayout,
  });

  @override
  List<Object?> get props => [
        todayEarnings,
        totalOrders,
        pendingOrders,
        completedOrders,
        commissionDeducted,
        netPayout,
      ];
}

/// Clean Architecture entity representing the top/most ordered product in the store
class TopOrderedItemEntity extends Equatable {
  final String productId;
  final String name;
  final int totalQuantity;
  final double totalRevenue;
  final String? imageUrl;

  const TopOrderedItemEntity({
    required this.productId,
    required this.name,
    required this.totalQuantity,
    required this.totalRevenue,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [productId, name, totalQuantity, totalRevenue, imageUrl];
}

/// Clean Architecture domain entity representing computed real-time order statistics
class RetailerOrderAnalyticsEntity extends Equatable {
  final int todayOrdersCount;
  final double todayRevenue;
  final TopOrderedItemEntity? mostOrderedItem;
  final int pendingOrdersCount;
  final int preparingOrdersCount;
  final int readyOrdersCount;
  final int deliveredOrdersCount;

  const RetailerOrderAnalyticsEntity({
    required this.todayOrdersCount,
    required this.todayRevenue,
    this.mostOrderedItem,
    required this.pendingOrdersCount,
    required this.preparingOrdersCount,
    required this.readyOrdersCount,
    required this.deliveredOrdersCount,
  });

  @override
  List<Object?> get props => [
        todayOrdersCount,
        todayRevenue,
        mostOrderedItem,
        pendingOrdersCount,
        preparingOrdersCount,
        readyOrdersCount,
        deliveredOrdersCount,
      ];
}

class RetailerSubscriptionEntity extends Equatable {
  final String id;
  final String planName;
  final double price;
  final double commissionPercent;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final String status;
  final bool isFreeTier;
  final bool isTrial;
  final int daysRemaining;
  final bool canAcceptOrders;

  const RetailerSubscriptionEntity({
    required this.id,
    required this.planName,
    required this.price,
    required this.commissionPercent,
    this.startsAt,
    this.expiresAt,
    this.status = 'ACTIVE',
    this.isFreeTier = false,
    this.isTrial = false,
    this.daysRemaining = 0,
    this.canAcceptOrders = true,
  });

  static const RetailerSubscriptionEntity freeTier = RetailerSubscriptionEntity(
    id: 'free_tier',
    planName: 'Free Starter Plan',
    price: 0.0,
    commissionPercent: 0.0,
    status: 'ACTIVE',
    isFreeTier: true,
    isTrial: false,
    daysRemaining: 0,
    canAcceptOrders: true,
  );

  bool get isExpired => status.toUpperCase() == 'EXPIRED' || (!canAcceptOrders && !isTrial) || (expiresAt != null && DateTime.now().isAfter(expiresAt!));
  bool get isTrialExpiringSoon => isTrial && daysRemaining <= 3 && daysRemaining >= 0;

  @override
  List<Object?> get props => [
        id,
        planName,
        price,
        commissionPercent,
        startsAt,
        expiresAt,
        status,
        isFreeTier,
        isTrial,
        daysRemaining,
        canAcceptOrders,
      ];
}

class RetailerSubscriptionModel extends RetailerSubscriptionEntity {
  const RetailerSubscriptionModel({
    required super.id,
    required super.planName,
    required super.price,
    required super.commissionPercent,
    super.startsAt,
    super.expiresAt,
    super.status,
    super.isFreeTier,
    super.isTrial,
    super.daysRemaining,
    super.canAcceptOrders,
  });

  factory RetailerSubscriptionModel.fromJson(Map<String, dynamic> json) {
    final subData = json['data'] is Map
        ? json['data'] as Map
        : (json['subscription'] is Map ? json['subscription'] as Map : json);
    final plan = subData['plan'] is Map ? subData['plan'] as Map : null;

    final String planName = plan?['name']?.toString() ??
        (subData['plan'] is String ? subData['plan'].toString() : null) ??
        subData['planName']?.toString() ??
        subData['name']?.toString() ??
        'Standard Merchant Plan';

    final double price = (plan?['price'] as num?)?.toDouble() ??
        (subData['price'] as num?)?.toDouble() ??
        0.0;

    final double commission = (plan?['commissionPercent'] as num?)?.toDouble() ??
        (subData['commissionPercent'] as num?)?.toDouble() ??
        (subData['commission'] as num?)?.toDouble() ??
        5.0;

    final bool isTrial = subData['isTrial'] == true ||
        subData['status']?.toString().toUpperCase() == 'TRIAL';
    final int daysRemaining = (subData['daysRemaining'] as num?)?.toInt() ?? 0;
    final bool canAcceptOrders = subData['canAcceptOrders'] != false;

    return RetailerSubscriptionModel(
      id: subData['_id']?.toString() ?? subData['id']?.toString() ?? 'sub_01',
      planName: planName,
      price: price,
      commissionPercent: commission,
      startsAt: subData['startsAt'] != null ? DateTime.tryParse(subData['startsAt'].toString()) : null,
      expiresAt: subData['expiresAt'] != null ? DateTime.tryParse(subData['expiresAt'].toString()) : null,
      status: subData['status']?.toString().toUpperCase() ?? 'ACTIVE',
      isFreeTier: price == 0.0 && commission == 0.0,
      isTrial: isTrial,
      daysRemaining: daysRemaining,
      canAcceptOrders: canAcceptOrders,
    );
  }
}


