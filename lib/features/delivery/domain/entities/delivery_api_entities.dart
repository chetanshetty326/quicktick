import 'package:equatable/equatable.dart';
import '../../../../features/order/domain/entities/order_entity.dart';

enum DeliveryDocumentType {
  aadhaar,
  license,
  rc,
  pan,
  photo,
  other;

  String toApiString() {
    switch (this) {
      case DeliveryDocumentType.aadhaar:
        return 'AADHAAR';
      case DeliveryDocumentType.license:
        return 'LICENSE';
      case DeliveryDocumentType.rc:
        return 'RC';
      case DeliveryDocumentType.pan:
        return 'PAN';
      case DeliveryDocumentType.photo:
        return 'PHOTO';
      case DeliveryDocumentType.other:
        return 'OTHER';
    }
  }

  static DeliveryDocumentType fromApiString(String val) {
    switch (val.toUpperCase()) {
      case 'AADHAAR':
        return DeliveryDocumentType.aadhaar;
      case 'LICENSE':
        return DeliveryDocumentType.license;
      case 'RC':
        return DeliveryDocumentType.rc;
      case 'PAN':
        return DeliveryDocumentType.pan;
      case 'PHOTO':
        return DeliveryDocumentType.photo;
      default:
        return DeliveryDocumentType.other;
    }
  }
}

class DeliveryDocumentEntity extends Equatable {
  final DeliveryDocumentType type;
  final String url;
  final String? number;

  const DeliveryDocumentEntity({
    required this.type,
    required this.url,
    this.number,
  });

  @override
  List<Object?> get props => [type, url, number];
}

class DeliveryPartnerProfileEntity extends Equatable {
  final String id;
  final String userId;
  final String phone;
  final String vehicleType;
  final String vehicleNumber;
  final String vehicleModel;
  final String licenseNumber;
  final String availability; // 'ONLINE', 'OFFLINE', 'BUSY', 'BREAK'
  final String status; // 'PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED'
  final bool isVerified;
  final String verificationStatus;
  final List<DeliveryDocumentEntity> documents;
  final int serviceRadius;
  final double rating;
  final int totalDeliveries;
  final double successRate;

  final double? latitude;
  final double? longitude;
  final int currentDeliveries;
  final int maxConcurrentDeliveries;
  final String? zoneId;
  final String? zoneName;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final double? earningsToday;
  final double? earningsThisWeek;
  final double? earningsThisMonth;

  const DeliveryPartnerProfileEntity({
    required this.id,
    required this.userId,
    required this.phone,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.vehicleModel,
    required this.licenseNumber,
    this.availability = 'OFFLINE',
    this.status = 'PENDING',
    this.isVerified = false,
    this.verificationStatus = 'PENDING',
    this.documents = const [],
    this.serviceRadius = 5,
    this.rating = 0.0,
    this.totalDeliveries = 0,
    this.successRate = 100.0,
    this.latitude,
    this.longitude,
    this.currentDeliveries = 0,
    this.maxConcurrentDeliveries = 3,
    this.zoneId,
    this.zoneName,
    this.name,
    this.email,
    this.avatarUrl,
    this.earningsToday,
    this.earningsThisWeek,
    this.earningsThisMonth,
  });

  bool get isApproved => status == 'APPROVED' || verificationStatus == 'APPROVED';
  bool get isPending => status == 'PENDING' || verificationStatus == 'PENDING';
  bool get isRejected => status == 'REJECTED' || verificationStatus == 'REJECTED';
  bool get isSuspended => status == 'SUSPENDED';

  DeliveryPartnerProfileEntity copyWith({
    String? id,
    String? userId,
    String? phone,
    String? vehicleType,
    String? vehicleNumber,
    String? vehicleModel,
    String? licenseNumber,
    String? availability,
    String? status,
    bool? isVerified,
    String? verificationStatus,
    List<DeliveryDocumentEntity>? documents,
    int? serviceRadius,
    double? rating,
    int? totalDeliveries,
    double? successRate,
    double? latitude,
    double? longitude,
    int? currentDeliveries,
    int? maxConcurrentDeliveries,
    String? zoneId,
    String? zoneName,
    String? name,
    String? email,
    String? avatarUrl,
    double? earningsToday,
    double? earningsThisWeek,
    double? earningsThisMonth,
  }) {
    return DeliveryPartnerProfileEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      availability: availability ?? this.availability,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      documents: documents ?? this.documents,
      serviceRadius: serviceRadius ?? this.serviceRadius,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      successRate: successRate ?? this.successRate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      currentDeliveries: currentDeliveries ?? this.currentDeliveries,
      maxConcurrentDeliveries: maxConcurrentDeliveries ?? this.maxConcurrentDeliveries,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      earningsToday: earningsToday ?? this.earningsToday,
      earningsThisWeek: earningsThisWeek ?? this.earningsThisWeek,
      earningsThisMonth: earningsThisMonth ?? this.earningsThisMonth,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        phone,
        vehicleType,
        vehicleNumber,
        vehicleModel,
        licenseNumber,
        availability,
        status,
        isVerified,
        verificationStatus,
        documents,
        serviceRadius,
        rating,
        totalDeliveries,
        successRate,
        latitude,
        longitude,
        currentDeliveries,
        maxConcurrentDeliveries,
        zoneId,
        zoneName,
        name,
        email,
        avatarUrl,
        earningsToday,
        earningsThisWeek,
        earningsThisMonth,
      ];
}

class DeliveryJobCustomerEntity extends Equatable {
  final String id;
  final String name;
  final String mobile;

  const DeliveryJobCustomerEntity({
    required this.id,
    required this.name,
    required this.mobile,
  });

  @override
  List<Object?> get props => [id, name, mobile];
}

class DeliveryJobRetailerEntity extends Equatable {
  final String id;
  final String shopName;
  final String phone;

  const DeliveryJobRetailerEntity({
    required this.id,
    required this.shopName,
    required this.phone,
  });

  @override
  List<Object?> get props => [id, shopName, phone];
}

class DeliveryJobAssignmentEntity extends Equatable {
  final String id;
  final String status;
  final DateTime? offeredAt;
  final DateTime? expiresAt;

  const DeliveryJobAssignmentEntity({
    required this.id,
    required this.status,
    this.offeredAt,
    this.expiresAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  int get secondsRemaining {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  @override
  List<Object?> get props => [id, status, offeredAt, expiresAt];
}

class DeliveryJobEntity extends Equatable {
  final String id;
  final String orderNumber;
  final String status; // 'ASSIGNED', 'ACCEPTED', 'REACHED_STORE', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED'
  final double total;
  final double deliveryFee;
  final String paymentMethod;
  final DeliveryJobCustomerEntity customer;
  final DeliveryJobRetailerEntity retailer;
  final DateTime createdAt;
  final String? deliveryAddress;
  final String? storeAddress;
  final double? customerLatitude;
  final double? customerLongitude;
  final double? storeLatitude;
  final double? storeLongitude;
  final String? zoneId;
  final String? deliveryOtp;
  final String? deliveryPartnerId;
  final DeliveryJobAssignmentEntity? assignment;
  final List<OrderItemEntity> items;

  const DeliveryJobEntity({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    this.deliveryFee = 0.0,
    this.paymentMethod = 'COD',
    required this.customer,
    required this.retailer,
    required this.createdAt,
    this.deliveryAddress,
    this.storeAddress,
    this.customerLatitude,
    this.customerLongitude,
    this.storeLatitude,
    this.storeLongitude,
    this.zoneId,
    this.deliveryOtp,
    this.deliveryPartnerId,
    this.assignment,
    this.items = const [],
  });

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        status,
        total,
        deliveryFee,
        paymentMethod,
        customer,
        retailer,
        createdAt,
        deliveryAddress,
        storeAddress,
        customerLatitude,
        customerLongitude,
        storeLatitude,
        storeLongitude,
        zoneId,
        deliveryOtp,
        deliveryPartnerId,
        assignment,
        items,
      ];
}

class PeriodEarningsEntity extends Equatable {
  final double amount;
  final int deliveries;
  final double cashCollected;
  final double netPayout;

  const PeriodEarningsEntity({
    required this.amount,
    required this.deliveries,
    this.cashCollected = 0.0,
    this.netPayout = 0.0,
  });

  @override
  List<Object?> get props => [amount, deliveries, cashCollected, netPayout];
}

class RecentEarningRecordEntity extends Equatable {
  final String orderId;
  final double amount;
  final String status;
  final DateTime? paidAt;

  const RecentEarningRecordEntity({
    required this.orderId,
    required this.amount,
    required this.status,
    this.paidAt,
  });

  @override
  List<Object?> get props => [orderId, amount, status, paidAt];
}

class DeliveryEarningsEntity extends Equatable {
  final PeriodEarningsEntity today;
  final PeriodEarningsEntity thisWeek;
  final PeriodEarningsEntity thisMonth;
  final PeriodEarningsEntity lifetime;
  final double pendingPayout;
  final List<RecentEarningRecordEntity> recent;

  const DeliveryEarningsEntity({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.lifetime,
    this.pendingPayout = 0.0,
    this.recent = const [],
  });

  @override
  List<Object?> get props => [today, thisWeek, thisMonth, lifetime, pendingPayout, recent];
}

class EarningsBreakdownRowEntity extends Equatable {
  final String id;
  final String orderId;
  final String orderNumber;
  final double total;
  final String paymentMethod;
  final String orderStatus;
  final double basePay;
  final double distancePay;
  final double surgeBonus;
  final double tipFromCustomer;
  final double penalty;
  final double totalEarning;
  final double cashCollected;
  final double netPayout;
  final double distanceKm;
  final String status;
  final DateTime createdAt;

  const EarningsBreakdownRowEntity({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.total,
    required this.paymentMethod,
    required this.orderStatus,
    required this.basePay,
    required this.distancePay,
    required this.surgeBonus,
    required this.tipFromCustomer,
    required this.penalty,
    required this.totalEarning,
    required this.cashCollected,
    required this.netPayout,
    required this.distanceKm,
    required this.status,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        orderId,
        orderNumber,
        total,
        paymentMethod,
        orderStatus,
        basePay,
        distancePay,
        surgeBonus,
        tipFromCustomer,
        penalty,
        totalEarning,
        cashCollected,
        netPayout,
        distanceKm,
        status,
        createdAt,
      ];
}

class CashCollectedOrderEntity extends Equatable {
  final String orderId;
  final double amount;
  final DateTime? collectedAt;

  const CashCollectedOrderEntity({
    required this.orderId,
    required this.amount,
    this.collectedAt,
  });

  @override
  List<Object?> get props => [orderId, amount, collectedAt];
}

class CashCollectedSummaryEntity extends Equatable {
  final double totalCashCollected;
  final double totalEarnings;
  final double netOwedToCompany;
  final double netOwedByCompany;
  final double cashInHand;
  final List<CashCollectedOrderEntity> orders;

  const CashCollectedSummaryEntity({
    required this.totalCashCollected,
    required this.totalEarnings,
    required this.netOwedToCompany,
    required this.netOwedByCompany,
    this.cashInHand = 0.0,
    this.orders = const [],
  });

  @override
  List<Object?> get props => [
        totalCashCollected,
        totalEarnings,
        netOwedToCompany,
        netOwedByCompany,
        cashInHand,
        orders,
      ];
}
