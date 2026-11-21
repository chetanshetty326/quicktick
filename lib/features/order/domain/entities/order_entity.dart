import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../customer/domain/entities/cart_pricing_entity.dart';

enum OrderStatus {
  paymentPending,
  placed,
  accepted,
  preparing,
  readyForPickup,
  assigned,
  pickedUp,
  outForDelivery,
  delivered,
  rejected,
  cancelled,
  failed;

  String get label {
    switch (this) {
      case OrderStatus.paymentPending:
        return 'Payment Pending';
      case OrderStatus.placed:
        return 'Order Placed';
      case OrderStatus.accepted:
        return 'Store Accepted';
      case OrderStatus.preparing:
        return 'Preparing Items';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.assigned:
        return 'Driver Assigned';
      case OrderStatus.pickedUp:
        return 'Order Picked Up';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.rejected:
        return 'Rejected by Store';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.failed:
        return 'Order Failed';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.paymentPending:
        return AppColors.statusReady;
      case OrderStatus.placed:
        return AppColors.statusPlaced;
      case OrderStatus.accepted:
        return AppColors.statusAccepted;
      case OrderStatus.preparing:
        return AppColors.statusPreparing;
      case OrderStatus.readyForPickup:
        return AppColors.statusReady;
      case OrderStatus.assigned:
        return AppColors.statusAssigned;
      case OrderStatus.pickedUp:
        return AppColors.statusPickedUp;
      case OrderStatus.outForDelivery:
        return AppColors.statusOutForDelivery;
      case OrderStatus.delivered:
        return AppColors.statusDelivered;
      case OrderStatus.rejected:
        return AppColors.statusRejected;
      case OrderStatus.cancelled:
        return AppColors.statusCancelled;
      case OrderStatus.failed:
        return AppColors.statusRejected;
    }
  }

  bool get isTerminal =>
      this == OrderStatus.delivered ||
      this == OrderStatus.cancelled ||
      this == OrderStatus.rejected ||
      this == OrderStatus.failed;

  int get stepIndex {
    switch (this) {
      case OrderStatus.paymentPending:
        return -1;
      case OrderStatus.placed:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.preparing:
        return 2;
      case OrderStatus.readyForPickup:
        return 3;
      case OrderStatus.assigned:
        return 4;
      case OrderStatus.pickedUp:
        return 5;
      case OrderStatus.outForDelivery:
        return 6;
      case OrderStatus.delivered:
        return 7;
      default:
        return -1;
    }
  }
}

class OrderStatusHistoryEntity extends Equatable {
  final String fromStatus;
  final String toStatus;
  final String actorRole;
  final DateTime? timestamp;

  const OrderStatusHistoryEntity({
    required this.fromStatus,
    required this.toStatus,
    required this.actorRole,
    this.timestamp,
  });

  factory OrderStatusHistoryEntity.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistoryEntity(
      fromStatus: json['fromStatus']?.toString() ?? '',
      toStatus: json['toStatus']?.toString() ?? '',
      actorRole: json['actorRole']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'fromStatus': fromStatus,
        'toStatus': toStatus,
        'actorRole': actorRole,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };

  @override
  List<Object?> get props => [fromStatus, toStatus, actorRole, timestamp];
}

class OrderItemEntity extends Equatable {
  final String productId;
  final String nameSnapshot;
  final double priceSnapshot;
  final String unit;
  final int quantity;
  final String? imageUrl;
  final String? foodType;
  final String? hsnCode;
  final double? taxPercent;
  final double? taxAmount;
  final double? serverTotal;

  const OrderItemEntity({
    required this.productId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.unit,
    required this.quantity,
    this.imageUrl,
    this.foodType,
    this.hsnCode,
    this.taxPercent,
    this.taxAmount,
    this.serverTotal,
  });

  double get total => serverTotal ?? (priceSnapshot * quantity);

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'nameSnapshot': nameSnapshot,
        'priceSnapshot': priceSnapshot,
        'unit': unit,
        'quantity': quantity,
        'imageUrl': imageUrl,
        if (foodType != null) 'foodType': foodType,
        if (hsnCode != null) 'hsnCode': hsnCode,
        if (taxPercent != null) 'taxPercent': taxPercent,
        if (taxAmount != null) 'taxAmount': taxAmount,
        if (serverTotal != null) 'total': serverTotal,
      };

  factory OrderItemEntity.fromJson(Map<String, dynamic> json) {
    final rawProdId = json['productId'];
    final resolvedProdId = rawProdId is Map
        ? (rawProdId['_id'] ?? rawProdId['id'])?.toString() ?? ''
        : (rawProdId?.toString() ?? '');

    double resolvedPrice = 0.0;
    final rawPrice = json['priceSnapshot'] ?? json['price'] ?? json['sellingPrice'];
    if (rawPrice is num) {
      resolvedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      resolvedPrice = double.tryParse(rawPrice) ?? 0.0;
    }

    int resolvedQty = 1;
    final rawQty = json['quantity'];
    if (rawQty is num) {
      resolvedQty = rawQty.toInt();
    } else if (rawQty is String) {
      resolvedQty = int.tryParse(rawQty) ?? 1;
    }

    String? resolvedImageUrl;
    final rawImg = json['imageUrl'] ?? json['image'] ?? json['images'];
    if (rawImg is List && rawImg.isNotEmpty) {
      resolvedImageUrl = rawImg.first?.toString();
    } else if (rawImg is String && rawImg.isNotEmpty) {
      resolvedImageUrl = rawImg;
    }

    return OrderItemEntity(
      productId: resolvedProdId,
      nameSnapshot: json['nameSnapshot']?.toString() ??
          json['name']?.toString() ??
          json['title']?.toString() ??
          '',
      priceSnapshot: resolvedPrice,
      unit: json['unit']?.toString() ?? 'item',
      quantity: resolvedQty,
      imageUrl: resolvedImageUrl,
      foodType: json['foodType']?.toString(),
      hsnCode: json['hsnCode']?.toString(),
      taxPercent: (json['taxPercent'] as num?)?.toDouble(),
      taxAmount: (json['taxAmount'] as num?)?.toDouble(),
      serverTotal: (json['total'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        productId,
        nameSnapshot,
        priceSnapshot,
        unit,
        quantity,
        imageUrl,
        foodType,
        hsnCode,
        taxPercent,
        taxAmount,
        serverTotal,
      ];
}

class DeliveryPartnerInfoEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? avatarUrl;
  final double rating;
  final int totalDeliveries;
  final String vehicleType;
  final String vehicleNumber;
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;

  const DeliveryPartnerInfoEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.rating = 0.0,
    this.totalDeliveries = 0,
    this.vehicleType = 'SCOOTER',
    this.vehicleNumber = '',
    this.latitude,
    this.longitude,
    this.updatedAt,
  });

  factory DeliveryPartnerInfoEntity.fromJson(Map<String, dynamic> json) {
    final vMap = json['vehicleDetails'] is Map ? json['vehicleDetails'] as Map : null;
    final vType = json['vehicleType']?.toString() ??
        vMap?['type']?.toString() ??
        vMap?['vehicleType']?.toString() ??
        'SCOOTER';
    final vNum = json['vehicleNumber']?.toString() ??
        vMap?['number']?.toString() ??
        vMap?['plateNumber']?.toString() ??
        vMap?['registrationNumber']?.toString() ??
        '';

    final rawPhone = json['phone'] ?? json['mobile'] ?? json['phoneNumber'] ?? json['contactNumber'];
    final rawName = json['name'] ?? json['fullName'] ?? 'Delivery Partner';

    final rawLat = json['latitude'] ?? json['lat'];
    final rawLng = json['longitude'] ?? json['lng'];

    return DeliveryPartnerInfoEntity(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: rawName.toString(),
      phone: rawPhone?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar']?.toString() ?? json['profileImage']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalDeliveries: (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      vehicleType: vType.toUpperCase(),
      vehicleNumber: vNum.toUpperCase(),
      latitude: rawLat != null ? (rawLat as num).toDouble() : null,
      longitude: rawLng != null ? (rawLng as num).toDouble() : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'rating': rating,
        'totalDeliveries': totalDeliveries,
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        avatarUrl,
        rating,
        totalDeliveries,
        vehicleType,
        vehicleNumber,
        latitude,
        longitude,
        updatedAt,
      ];
}

class OrderEntity extends Equatable {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String storeId;
  final String storeName;
  final String storeAddress;
  final String? deliveryPartnerId;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;
  final DeliveryPartnerInfoEntity? deliveryPartner;
  final List<OrderItemEntity> items;
  final double subtotal;
  final double deliveryFee;
  final double platformFee;
  final double discount;
  final double tip;
  final double tax;
  final TaxBreakdownEntity taxBreakdown;
  final double grandTotal;
  final String? couponCode;
  final OrderStatus status;
  final String deliveryOtp;
  final String paymentMethod; // 'COD'
  final String paymentStatus; // 'PENDING', 'COMPLETED'
  final DateTime createdAt;
  final String? rejectionReason;
  final List<OrderStatusHistoryEntity> statusHistory;
  final String? zoneId;
  final String? retailerGstinSnapshot;
  final String? retailerStateSnapshot;
  final String? retailerNameSnapshot;

  const OrderEntity({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.storeId,
    required this.storeName,
    required this.storeAddress,
    this.deliveryPartnerId,
    this.deliveryPartnerName,
    this.deliveryPartnerPhone,
    this.deliveryPartner,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.platformFee,
    this.discount = 0.0,
    this.tip = 0.0,
    this.tax = 0.0,
    this.taxBreakdown = const TaxBreakdownEntity(),
    required this.grandTotal,
    this.couponCode,
    required this.status,
    required this.deliveryOtp,
    this.paymentMethod = 'COD',
    this.paymentStatus = 'PENDING',
    required this.createdAt,
    this.rejectionReason,
    this.statusHistory = const [],
    this.zoneId,
    this.retailerGstinSnapshot,
    this.retailerStateSnapshot,
    this.retailerNameSnapshot,
  });

  String get resolvedZoneName {
    if (zoneId == '6abe8daf523e496cfdd80053') return 'Bengaluru Zone';
    if (zoneId != null && zoneId!.isNotEmpty) {
      return 'Operational Zone';
    }
    return 'Operational Zone';
  }

  OrderEntity copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    String? storeId,
    String? storeName,
    String? storeAddress,
    String? deliveryPartnerId,
    String? deliveryPartnerName,
    String? deliveryPartnerPhone,
    DeliveryPartnerInfoEntity? deliveryPartner,
    List<OrderItemEntity>? items,
    double? subtotal,
    double? deliveryFee,
    double? platformFee,
    double? discount,
    double? tip,
    double? tax,
    TaxBreakdownEntity? taxBreakdown,
    double? grandTotal,
    String? couponCode,
    OrderStatus? status,
    String? deliveryOtp,
    String? paymentMethod,
    String? paymentStatus,
    DateTime? createdAt,
    String? rejectionReason,
    List<OrderStatusHistoryEntity>? statusHistory,
    String? zoneId,
    String? retailerGstinSnapshot,
    String? retailerStateSnapshot,
    String? retailerNameSnapshot,
  }) {
    return OrderEntity(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      deliveryPartnerId: deliveryPartnerId ?? this.deliveryPartnerId,
      deliveryPartnerName: deliveryPartnerName ?? this.deliveryPartnerName,
      deliveryPartnerPhone: deliveryPartnerPhone ?? this.deliveryPartnerPhone,
      deliveryPartner: deliveryPartner ?? this.deliveryPartner,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      platformFee: platformFee ?? this.platformFee,
      discount: discount ?? this.discount,
      tip: tip ?? this.tip,
      tax: tax ?? this.tax,
      taxBreakdown: taxBreakdown ?? this.taxBreakdown,
      grandTotal: grandTotal ?? this.grandTotal,
      couponCode: couponCode ?? this.couponCode,
      status: status ?? this.status,
      deliveryOtp: deliveryOtp ?? this.deliveryOtp,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      statusHistory: statusHistory ?? this.statusHistory,
      zoneId: zoneId ?? this.zoneId,
      retailerGstinSnapshot: retailerGstinSnapshot ?? this.retailerGstinSnapshot,
      retailerStateSnapshot: retailerStateSnapshot ?? this.retailerStateSnapshot,
      retailerNameSnapshot: retailerNameSnapshot ?? this.retailerNameSnapshot,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'deliveryAddress': deliveryAddress,
        'storeId': storeId,
        'storeName': storeName,
        'storeAddress': storeAddress,
        'deliveryPartnerId': deliveryPartnerId,
        'deliveryPartnerName': deliveryPartnerName,
        'deliveryPartnerPhone': deliveryPartnerPhone,
        if (deliveryPartner != null) 'deliveryPartner': deliveryPartner!.toJson(),
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'platformFee': platformFee,
        'discount': discount,
        'tip': tip,
        'tax': tax,
        'taxBreakdown': taxBreakdown.toJson(),
        'grandTotal': grandTotal,
        if (couponCode != null) 'couponCode': couponCode,
        'status': status.name,
        'deliveryOtp': deliveryOtp,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'createdAt': createdAt.toIso8601String(),
        'rejectionReason': rejectionReason,
        'statusHistory': statusHistory.map((e) => e.toJson()).toList(),
        if (zoneId != null) 'zoneId': zoneId,
        if (retailerGstinSnapshot != null) 'retailerGstinSnapshot': retailerGstinSnapshot,
        if (retailerStateSnapshot != null) 'retailerStateSnapshot': retailerStateSnapshot,
        if (retailerNameSnapshot != null) 'retailerNameSnapshot': retailerNameSnapshot,
      };

  factory OrderEntity.fromJson(Map<String, dynamic> json) {
    final pMethod = json['paymentMethod']?.toString() ??
        json['payment_method']?.toString() ??
        json['paymentMode']?.toString() ??
        (json['payment'] is Map ? json['payment']['method']?.toString() : null) ??
        'COD';
    String pStatus = json['paymentStatus']?.toString().toUpperCase() ??
        json['payment_status']?.toString().toUpperCase() ??
        (json['payment'] is Map ? json['payment']['status']?.toString().toUpperCase() : null) ??
        (json['isPaid'] == true ? 'COMPLETED' : 'PENDING');
    if (pStatus == 'PAID' || pStatus == 'CAPTURED' || pStatus == 'SUCCESS') {
      pStatus = 'COMPLETED';
    }

    final historyList = (json['statusHistory'] as List? ?? [])
        .whereType<Map>()
        .map((e) => OrderStatusHistoryEntity.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final parsedZoneId = json['zoneId']?.toString() ??
        (json['zone'] is Map ? (json['zone']['_id'] ?? json['zone']['id'])?.toString() : json['zone']?.toString());

    DeliveryPartnerInfoEntity? parsedPartner;
    if (json['deliveryPartner'] is Map) {
      parsedPartner = DeliveryPartnerInfoEntity.fromJson(
        Map<String, dynamic>.from(json['deliveryPartner']),
      );
    } else if (json['deliveryPartnerId'] is Map) {
      parsedPartner = DeliveryPartnerInfoEntity.fromJson(
        Map<String, dynamic>.from(json['deliveryPartnerId']),
      );
    } else if (json['rider'] is Map) {
      parsedPartner = DeliveryPartnerInfoEntity.fromJson(
        Map<String, dynamic>.from(json['rider']),
      );
    }

    final pId = parsedPartner?.id.isNotEmpty == true
        ? parsedPartner!.id
        : (json['deliveryPartnerId'] is String ? json['deliveryPartnerId'] as String : null);
    final pName = (parsedPartner?.name.isNotEmpty == true && parsedPartner!.name != 'Delivery Partner')
        ? parsedPartner.name
        : json['deliveryPartnerName']?.toString() ?? json['riderName']?.toString() ?? parsedPartner?.name;
    final pPhone = parsedPartner?.phone.isNotEmpty == true
        ? parsedPartner!.phone
        : json['deliveryPartnerPhone']?.toString() ?? json['riderPhone']?.toString();

    return OrderEntity(
      id: json['id'] ?? json['_id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      deliveryAddress: json['deliveryAddress'] is Map
          ? (json['deliveryAddress']['line1'] ?? 'Default Address')
          : (json['deliveryAddress'] ?? ''),
      storeId: json['storeId'] is Map
          ? (json['storeId']['_id'] ?? '')
          : (json['storeId'] ?? ''),
      storeName: json['storeId'] is Map
          ? (json['storeId']['name'] ?? 'QuickMart Supermarket')
          : (json['storeName'] ?? ''),
      storeAddress: json['storeAddress'] ?? '',
      deliveryPartnerId: pId,
      deliveryPartnerName: pName,
      deliveryPartnerPhone: pPhone,
      deliveryPartner: parsedPartner,
      items: (json['items'] as List? ?? [])
          .map((e) => OrderItemEntity.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      platformFee: (json['platformFee'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      taxBreakdown: json['taxBreakdown'] is Map
          ? TaxBreakdownEntity.fromJson(Map<String, dynamic>.from(json['taxBreakdown']))
          : const TaxBreakdownEntity(),
      grandTotal: (json['total'] as num?)?.toDouble() ??
          (json['grandTotal'] as num?)?.toDouble() ??
          (json['totalAmount'] as num?)?.toDouble() ??
          0.0,
      couponCode: json['couponCode']?.toString(),
      status: parseStatus(json['status']),
      deliveryOtp: json['deliveryOtp']?.toString() ?? '1234',
      paymentMethod: pMethod,
      paymentStatus: pStatus,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      rejectionReason: json['rejectionReason']?.toString() ?? json['cancelReason']?.toString() ?? json['reason']?.toString(),
      statusHistory: historyList,
      zoneId: parsedZoneId,
      retailerGstinSnapshot: json['retailerGstinSnapshot']?.toString() ?? json['gstin']?.toString(),
      retailerStateSnapshot: json['retailerStateSnapshot']?.toString(),
      retailerNameSnapshot: json['retailerNameSnapshot']?.toString(),
    );
  }

  static OrderStatus parseStatus(dynamic status) {
    if (status is OrderStatus) return status;
    final s = status?.toString().trim().toUpperCase() ?? '';
    if (s == 'PAYMENT_PENDING' || s == 'PENDING_PAYMENT') return OrderStatus.paymentPending;
    if (s == 'ACCEPTED') return OrderStatus.accepted;
    if (s == 'PREPARING') return OrderStatus.preparing;
    if (s == 'READY_FOR_PICKUP' || s == 'READY') return OrderStatus.readyForPickup;
    if (s == 'ASSIGNED') return OrderStatus.assigned;
    if (s == 'PICKED_UP' || s == 'PICKEDUP') return OrderStatus.pickedUp;
    if (s == 'OUT_FOR_DELIVERY' || s == 'OUTFORDELIVERY') return OrderStatus.outForDelivery;
    if (s == 'DELIVERED' || s == 'COMPLETED') return OrderStatus.delivered;
    if (s == 'FAILED') return OrderStatus.failed;
    if (s.contains('REJECT')) return OrderStatus.rejected;
    if (s.contains('CANCEL')) return OrderStatus.cancelled;
    return OrderStatus.placed;
  }

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        customerId,
        storeId,
        deliveryPartnerId,
        deliveryPartnerName,
        deliveryPartnerPhone,
        deliveryPartner,
        items,
        subtotal,
        deliveryFee,
        platformFee,
        discount,
        tip,
        tax,
        taxBreakdown,
        grandTotal,
        couponCode,
        status,
        deliveryOtp,
        paymentStatus,
        createdAt,
        statusHistory,
        zoneId,
        retailerGstinSnapshot,
        retailerStateSnapshot,
        retailerNameSnapshot,
      ];
}
