import '../../domain/entities/delivery_api_entities.dart';
import '../../../order/domain/entities/order_entity.dart';

class DeliveryDocumentModel extends DeliveryDocumentEntity {
  const DeliveryDocumentModel({
    required super.type,
    required super.url,
    super.number,
  });

  factory DeliveryDocumentModel.fromJson(Map<String, dynamic> json) {
    return DeliveryDocumentModel(
      type: DeliveryDocumentType.fromApiString(json['type']?.toString() ?? 'OTHER'),
      url: json['url']?.toString() ?? '',
      number: json['number']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toApiString(),
      'url': url,
      if (number != null && number!.isNotEmpty) 'number': number,
    };
  }
}

class DeliveryPartnerProfileModel extends DeliveryPartnerProfileEntity {
  const DeliveryPartnerProfileModel({
    required super.id,
    required super.userId,
    required super.phone,
    required super.vehicleType,
    required super.vehicleNumber,
    required super.vehicleModel,
    required super.licenseNumber,
    super.availability,
    super.status,
    super.isVerified,
    super.verificationStatus,
    super.documents,
    super.serviceRadius,
    super.rating,
    super.totalDeliveries,
    super.successRate,
    super.latitude,
    super.longitude,
    super.currentDeliveries,
    super.maxConcurrentDeliveries,
    super.zoneId,
    super.zoneName,
    super.name,
    super.email,
    super.avatarUrl,
    super.earningsToday,
    super.earningsThisWeek,
    super.earningsThisMonth,
  });

  factory DeliveryPartnerProfileModel.fromJson(Map<String, dynamic> json) {
    final docsRaw = json['documents'];
    final List<DeliveryDocumentEntity> docs = [];
    if (docsRaw is List) {
      for (final d in docsRaw) {
        if (d is Map<String, dynamic>) {
          docs.add(DeliveryDocumentModel.fromJson(d));
        } else if (d is Map) {
          docs.add(DeliveryDocumentModel.fromJson(Map<String, dynamic>.from(d)));
        }
      }
    }

    final locMap = json['location'] is Map ? json['location'] as Map : null;
    final coords = (locMap != null && locMap['coordinates'] is List) ? locMap['coordinates'] as List : null;
    final double? parsedLng = coords != null && coords.isNotEmpty ? (coords[0] as num?)?.toDouble() : null;
    final double? parsedLat = coords != null && coords.length > 1 ? (coords[1] as num?)?.toDouble() : null;

    final double? finalLat = (json['latitude'] as num?)?.toDouble() ?? parsedLat;
    final double? finalLng = (json['longitude'] as num?)?.toDouble() ?? parsedLng;

    final rawUser = json['userId'] ?? json['user'] ?? json['userid'];
    final String resolvedUserId = rawUser is Map
        ? (rawUser['_id'] ?? rawUser['id'])?.toString() ?? ''
        : (rawUser?.toString() ?? '');

    final String resolvedPhone = json['phone']?.toString() ??
        (rawUser is Map ? rawUser['phone']?.toString() ?? rawUser['mobile']?.toString() : null) ??
        '';

    final String? resolvedName = (rawUser is Map ? rawUser['name']?.toString() : null) ?? json['name']?.toString();
    final String? resolvedEmail = (rawUser is Map ? rawUser['email']?.toString() : null) ?? json['email']?.toString();
    final String? resolvedAvatar = (rawUser is Map ? rawUser['avatarUrl']?.toString() : null) ?? json['avatarUrl']?.toString();

    return DeliveryPartnerProfileModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: resolvedUserId,
      phone: resolvedPhone,
      vehicleType: json['vehicleType']?.toString() ?? 'BIKE',
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      vehicleModel: json['vehicleModel']?.toString() ?? '',
      licenseNumber: json['licenseNumber']?.toString() ?? '',
      availability: json['availability']?.toString() ?? 'OFFLINE',
      status: json['status']?.toString() ?? 'PENDING',
      isVerified: json['isVerified'] == true,
      verificationStatus: json['verificationStatus']?.toString() ?? json['status']?.toString() ?? 'PENDING',
      documents: docs,
      serviceRadius: (json['serviceRadius'] as num?)?.toInt() ?? 5,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalDeliveries: (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      successRate: (json['successRate'] as num?)?.toDouble() ?? 100.0,
      latitude: finalLat,
      longitude: finalLng,
      currentDeliveries: (json['currentDeliveries'] as num?)?.toInt() ?? 0,
      maxConcurrentDeliveries: (json['maxConcurrentDeliveries'] as num?)?.toInt() ?? 3,
      zoneId: json['zoneId']?.toString() ??
          (json['zone'] is Map
              ? (json['zone']['_id'] ?? json['zone']['id'])?.toString()
              : json['zone']?.toString()),
      zoneName: json['zoneName']?.toString() ??
          (json['zone'] is Map ? json['zone']['name']?.toString() : null),
      name: resolvedName,
      email: resolvedEmail,
      avatarUrl: resolvedAvatar,
      earningsToday: (json['earningsToday'] as num?)?.toDouble(),
      earningsThisWeek: (json['earningsThisWeek'] as num?)?.toDouble(),
      earningsThisMonth: (json['earningsThisMonth'] as num?)?.toDouble(),
    );
  }
}

class DeliveryJobCustomerModel extends DeliveryJobCustomerEntity {
  const DeliveryJobCustomerModel({
    required super.id,
    required super.name,
    required super.mobile,
  });

  factory DeliveryJobCustomerModel.fromJson(Map<String, dynamic> json) {
    return DeliveryJobCustomerModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? json['customerId']?.toString() ?? json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? json['customerName']?.toString() ?? json['userName']?.toString() ?? 'Customer',
      mobile: json['mobile']?.toString() ?? json['phone']?.toString() ?? json['customerPhone']?.toString() ?? json['userPhone']?.toString() ?? '',
    );
  }
}

class DeliveryJobRetailerModel extends DeliveryJobRetailerEntity {
  const DeliveryJobRetailerModel({
    required super.id,
    required super.shopName,
    required super.phone,
  });

  factory DeliveryJobRetailerModel.fromJson(Map<String, dynamic> json) {
    return DeliveryJobRetailerModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? json['storeId']?.toString() ?? json['retailerId']?.toString() ?? '',
      shopName: json['shopName']?.toString() ?? json['name']?.toString() ?? json['storeName']?.toString() ?? 'Store',
      phone: json['phone']?.toString() ?? json['mobile']?.toString() ?? json['storePhone']?.toString() ?? '',
    );
  }
}

class DeliveryJobAssignmentModel extends DeliveryJobAssignmentEntity {
  const DeliveryJobAssignmentModel({
    required super.id,
    required super.status,
    super.offeredAt,
    super.expiresAt,
  });

  factory DeliveryJobAssignmentModel.fromJson(Map<String, dynamic> json) {
    return DeliveryJobAssignmentModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OFFERED',
      offeredAt: json['offeredAt'] != null ? DateTime.tryParse(json['offeredAt'].toString()) : null,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : null,
    );
  }
}

class DeliveryJobModel extends DeliveryJobEntity {
  const DeliveryJobModel({
    required super.id,
    required super.orderNumber,
    required super.status,
    required super.total,
    super.deliveryFee,
    super.paymentMethod,
    required super.customer,
    required super.retailer,
    required super.createdAt,
    super.deliveryAddress,
    super.storeAddress,
    super.customerLatitude,
    super.customerLongitude,
    super.storeLatitude,
    super.storeLongitude,
    super.zoneId,
    super.deliveryOtp,
    super.deliveryPartnerId,
    super.assignment,
    super.items = const [],
  });

  factory DeliveryJobModel.fromJson(Map<String, dynamic> json) {
    final uMap = json['userId'] is Map
        ? Map<String, dynamic>.from(json['userId'] as Map)
        : (json['customer'] is Map
            ? Map<String, dynamic>.from(json['customer'] as Map)
            : <String, dynamic>{
                'id': json['customerId']?.toString() ?? json['userId']?.toString() ?? '',
                'name': json['customerName']?.toString() ?? json['userName']?.toString(),
                'mobile': json['customerPhone']?.toString() ?? json['userPhone']?.toString() ?? json['phone']?.toString(),
              });

    final pickupMap = json['pickup'] is Map ? Map<String, dynamic>.from(json['pickup'] as Map) : <String, dynamic>{};
    final dropoffMap = json['dropoff'] is Map ? Map<String, dynamic>.from(json['dropoff'] as Map) : <String, dynamic>{};

    final rMap = json['retailerId'] is Map
        ? Map<String, dynamic>.from(json['retailerId'] as Map)
        : (json['retailer'] is Map
            ? Map<String, dynamic>.from(json['retailer'] as Map)
            : (json['store'] is Map
                ? Map<String, dynamic>.from(json['store'] as Map)
                : <String, dynamic>{
                    'id': json['storeId']?.toString() ?? json['retailerId']?.toString() ?? '',
                    'shopName': pickupMap['retailerName']?.toString() ?? json['storeName']?.toString() ?? json['shopName']?.toString(),
                    'phone': json['storePhone']?.toString() ?? json['retailerPhone']?.toString(),
                  }));

    final snapMap = json['addressSnapshot'] is Map ? Map<String, dynamic>.from(json['addressSnapshot'] as Map) : <String, dynamic>{};
    final rAddrMap = rMap['address'] is Map ? Map<String, dynamic>.from(rMap['address'] as Map) : <String, dynamic>{};

    // Format customer delivery address from dropoff, addressSnapshot or deliveryAddress map
    String? resolvedDeliveryAddress;
    if (dropoffMap['address'] != null && dropoffMap['address'].toString().trim().isNotEmpty) {
      resolvedDeliveryAddress = dropoffMap['address'].toString();
    }
    if (resolvedDeliveryAddress == null && snapMap.isNotEmpty) {
      final parts = [
        snapMap['line1']?.toString(),
        snapMap['city']?.toString(),
        snapMap['state']?.toString(),
        snapMap['postalCode']?.toString(),
      ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
      if (parts.isNotEmpty) resolvedDeliveryAddress = parts;
    }
    if (resolvedDeliveryAddress == null && json['deliveryAddress'] is Map) {
      final dMap = Map<String, dynamic>.from(json['deliveryAddress'] as Map);
      final parts = [
        dMap['line1']?.toString() ?? dMap['street']?.toString() ?? dMap['addressLine']?.toString(),
        dMap['city']?.toString(),
        dMap['state']?.toString(),
        dMap['postalCode']?.toString() ?? dMap['pincode']?.toString(),
      ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
      if (parts.isNotEmpty) resolvedDeliveryAddress = parts;
    }
    resolvedDeliveryAddress ??= json['deliveryAddress']?.toString() ?? json['address']?.toString();

    // Format retailer store pickup address from pickup, retailerId.address or storeAddress map
    String? resolvedStoreAddress;
    if (pickupMap['address'] != null && pickupMap['address'].toString().trim().isNotEmpty) {
      resolvedStoreAddress = pickupMap['address'].toString();
    }
    if (resolvedStoreAddress == null && rAddrMap.isNotEmpty) {
      final parts = [
        rAddrMap['line1']?.toString(),
        rAddrMap['city']?.toString(),
        rAddrMap['state']?.toString(),
      ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
      if (parts.isNotEmpty) resolvedStoreAddress = parts;
    }
    if (resolvedStoreAddress == null && (json['storeAddress'] is Map || json['pickupAddress'] is Map)) {
      final sMap = Map<String, dynamic>.from((json['storeAddress'] ?? json['pickupAddress']) as Map);
      final parts = [
        sMap['line1']?.toString() ?? sMap['street']?.toString(),
        sMap['city']?.toString(),
        sMap['state']?.toString(),
      ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
      if (parts.isNotEmpty) resolvedStoreAddress = parts;
    }
    resolvedStoreAddress ??= json['storeAddress']?.toString() ?? json['pickupAddress']?.toString();

    // Coordinates helper
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    // Customer Coordinates
    final double? custLat = parseDouble(dropoffMap['latitude']) ?? parseDouble(snapMap['latitude']) ?? parseDouble(json['customerLatitude']);
    final double? custLng = parseDouble(dropoffMap['longitude']) ?? parseDouble(snapMap['longitude']) ?? parseDouble(json['customerLongitude']);

    // Store Coordinates from pickupMap or GeoJSON Point [lng, lat]
    final rLoc = rMap['location'] is Map ? rMap['location'] as Map : null;
    final rCoords = (rLoc != null && rLoc['coordinates'] is List) ? rLoc['coordinates'] as List : null;
    final double? storeLng = parseDouble(pickupMap['longitude']) ??
        (rCoords != null && rCoords.isNotEmpty ? parseDouble(rCoords[0]) : null) ??
        parseDouble(json['storeLongitude']);
    final double? storeLat = parseDouble(pickupMap['latitude']) ??
        (rCoords != null && rCoords.length > 1 ? parseDouble(rCoords[1]) : null) ??
        parseDouble(json['storeLatitude']);

    final String? parsedZoneId = json['zoneId']?.toString() ??
        (json['zone'] is Map
            ? (json['zone']['_id'] ?? json['zone']['id'])?.toString()
            : json['zone']?.toString()) ??
        (snapMap['zoneId']?.toString() ??
            (snapMap['zone'] is Map ? (snapMap['zone']['_id'] ?? snapMap['zone']['id'])?.toString() : snapMap['zone']?.toString())) ??
        (rMap['zoneId']?.toString() ??
            (rMap['zone'] is Map ? (rMap['zone']['_id'] ?? rMap['zone']['id'])?.toString() : rMap['zone']?.toString()));

    DeliveryJobAssignmentModel? parsedAssignment;
    if (json['assignment'] is Map) {
      parsedAssignment = DeliveryJobAssignmentModel.fromJson(Map<String, dynamic>.from(json['assignment'] as Map));
    } else if (json['currentAssignment'] is Map) {
      parsedAssignment = DeliveryJobAssignmentModel.fromJson(Map<String, dynamic>.from(json['currentAssignment'] as Map));
    } else if (json['expiresAt'] != null || json['assignmentId'] != null) {
      parsedAssignment = DeliveryJobAssignmentModel(
        id: json['assignmentId']?.toString() ?? '',
        status: json['assignmentStatus']?.toString() ?? 'OFFERED',
        offeredAt: json['offeredAt'] != null ? DateTime.tryParse(json['offeredAt'].toString()) : null,
        expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : null,
      );
    }

    // Parse items safely
    final itemsRaw = json['items'];
    final List<OrderItemEntity> parsedItems = [];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        try {
          if (item is Map<String, dynamic>) {
            parsedItems.add(OrderItemEntity.fromJson(item));
          } else if (item is Map) {
            parsedItems.add(OrderItemEntity.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
    }

    // Resolve delivery partner ID from all possible backend schemas
    String? resolvedPartnerId = json['deliveryPartnerId']?.toString() ??
        json['partnerId']?.toString() ??
        json['riderId']?.toString() ??
        json['driverId']?.toString();

    if (resolvedPartnerId == null || resolvedPartnerId.isEmpty) {
      final rawPartner = json['deliveryPartner'] ?? json['partner'] ?? json['driver'] ?? json['assignedTo'];
      if (rawPartner is Map) {
        resolvedPartnerId = (rawPartner['_id'] ?? rawPartner['id'])?.toString();
      } else if (rawPartner is String && rawPartner.isNotEmpty) {
        resolvedPartnerId = rawPartner;
      }
    }

    if (resolvedPartnerId == null || resolvedPartnerId.isEmpty) {
      if (json['currentAssignment'] is Map) {
        final ca = json['currentAssignment'] as Map;
        resolvedPartnerId = (ca['deliveryPartnerId'] ?? ca['partnerId'] ?? ca['riderId'])?.toString();
      } else if (json['assignment'] is Map) {
        final asgn = json['assignment'] as Map;
        resolvedPartnerId = (asgn['deliveryPartnerId'] ?? asgn['partnerId'] ?? asgn['riderId'] ?? asgn['partner'])?.toString();
      }
    }

    final rawAssignmentStatus = (json['assignmentStatus'] ?? json['status'] ?? 'ASSIGNED').toString().toUpperCase();
    final String resolvedStatus = ['ASSIGNED', 'OFFERED', 'ACCEPTED', 'REACHED_STORE', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED'].contains(rawAssignmentStatus)
        ? rawAssignmentStatus
        : (json['status']?.toString() ?? 'ASSIGNED');

    return DeliveryJobModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      status: resolvedStatus,
      total: parseDouble(json['totalAmount']) ?? parseDouble(json['total']) ?? parseDouble(json['grandTotal']) ?? 0.0,
      deliveryFee: parseDouble(json['deliveryFee']) ?? parseDouble(json['deliveryCharge']) ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'COD',
      customer: DeliveryJobCustomerModel.fromJson(uMap),
      retailer: DeliveryJobRetailerModel.fromJson(rMap),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      deliveryAddress: resolvedDeliveryAddress,
      storeAddress: resolvedStoreAddress,
      customerLatitude: custLat,
      customerLongitude: custLng,
      storeLatitude: storeLat,
      storeLongitude: storeLng,
      zoneId: parsedZoneId,
      // Security Hardening: Never expose customer's expected delivery OTP to the delivery partner's app state.
      // Verification must be performed authoritatively by the backend server at doorstep delivery.
      deliveryOtp: '',
      deliveryPartnerId: resolvedPartnerId,
      assignment: parsedAssignment,
      items: parsedItems,
    );
  }
}

class PeriodEarningsModel extends PeriodEarningsEntity {
  const PeriodEarningsModel({
    required super.amount,
    required super.deliveries,
    super.cashCollected = 0.0,
    super.netPayout = 0.0,
  });

  factory PeriodEarningsModel.fromAny(dynamic val) {
    if (val is num) {
      return PeriodEarningsModel(
        amount: val.toDouble(),
        deliveries: 0,
      );
    }
    if (val is Map) {
      return PeriodEarningsModel.fromJson(Map<String, dynamic>.from(val));
    }
    return const PeriodEarningsModel(amount: 0.0, deliveries: 0);
  }

  factory PeriodEarningsModel.fromJson(Map<String, dynamic> json) {
    return PeriodEarningsModel(
      amount: (json['amount'] as num?)?.toDouble() ?? (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      deliveries: (json['deliveries'] as num?)?.toInt() ?? (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      cashCollected: (json['cashCollected'] as num?)?.toDouble() ?? 0.0,
      netPayout: (json['netPayout'] as num?)?.toDouble() ??
          ((json['amount'] as num?)?.toDouble() ?? 0.0) - ((json['cashCollected'] as num?)?.toDouble() ?? 0.0),
    );
  }
}

class DeliveryEarningsModel extends DeliveryEarningsEntity {
  const DeliveryEarningsModel({
    required super.today,
    required super.thisWeek,
    required super.thisMonth,
    required super.lifetime,
    super.pendingPayout,
    super.recent,
  });

  factory DeliveryEarningsModel.fromJson(Map<String, dynamic> json) {
    final today = PeriodEarningsModel.fromAny(json['today']);
    final thisWeek = PeriodEarningsModel.fromAny(json['thisWeek']);
    final thisMonth = PeriodEarningsModel.fromAny(json['thisMonth']);
    final lifetime = PeriodEarningsModel.fromAny(json['lifetime']);
    final pendingPayout = (json['pendingPayout'] as num?)?.toDouble() ?? 0.0;

    final List<RecentEarningRecordEntity> recentList = [];
    if (json['recent'] is List) {
      for (final r in json['recent'] as List) {
        if (r is Map) {
          final rMap = Map<String, dynamic>.from(r);
          recentList.add(RecentEarningRecordEntity(
            orderId: rMap['orderId']?.toString() ?? '',
            amount: (rMap['amount'] as num?)?.toDouble() ?? 0.0,
            status: rMap['status']?.toString() ?? 'PAID',
            paidAt: rMap['paidAt'] != null ? DateTime.tryParse(rMap['paidAt'].toString()) : null,
          ));
        }
      }
    }

    return DeliveryEarningsModel(
      today: today,
      thisWeek: thisWeek,
      thisMonth: thisMonth,
      lifetime: lifetime,
      pendingPayout: pendingPayout,
      recent: recentList,
    );
  }
}

class EarningsBreakdownRowModel extends EarningsBreakdownRowEntity {
  const EarningsBreakdownRowModel({
    required super.id,
    required super.orderId,
    required super.orderNumber,
    required super.total,
    required super.paymentMethod,
    required super.orderStatus,
    required super.basePay,
    required super.distancePay,
    required super.surgeBonus,
    required super.tipFromCustomer,
    required super.penalty,
    required super.totalEarning,
    required super.cashCollected,
    required super.netPayout,
    required super.distanceKm,
    required super.status,
    required super.createdAt,
  });

  factory EarningsBreakdownRowModel.fromJson(Map<String, dynamic> json) {
    final orderObj = json['orderId'] is Map ? Map<String, dynamic>.from(json['orderId'] as Map) : null;
    final String resolvedOrderId = orderObj != null
        ? (orderObj['_id']?.toString() ?? orderObj['id']?.toString() ?? '')
        : (json['orderId']?.toString() ?? '');
    final String resolvedOrderNumber = orderObj?['orderNumber']?.toString() ?? json['orderNumber']?.toString() ?? '';
    final double resolvedTotal = (orderObj?['total'] as num?)?.toDouble() ??
        (orderObj?['grandTotal'] as num?)?.toDouble() ??
        (json['total'] as num?)?.toDouble() ??
        0.0;
    final String resolvedPaymentMethod = orderObj?['paymentMethod']?.toString() ?? json['paymentMethod']?.toString() ?? 'COD';
    final String resolvedOrderStatus = orderObj?['status']?.toString() ?? json['orderStatus']?.toString() ?? 'DELIVERED';

    final double base = (json['basePay'] as num?)?.toDouble() ?? 0.0;
    final double dist = (json['distancePay'] as num?)?.toDouble() ?? 0.0;
    final double surge = (json['surgeBonus'] as num?)?.toDouble() ?? 0.0;
    final double tip = (json['tipFromCustomer'] as num?)?.toDouble() ?? 0.0;
    final double pen = (json['penalty'] as num?)?.toDouble() ?? 0.0;
    final double totEarn = (json['totalEarning'] as num?)?.toDouble() ?? (base + dist + surge + tip - pen);
    final double cashCol = (json['cashCollected'] as num?)?.toDouble() ?? 0.0;
    final double net = (json['netPayout'] as num?)?.toDouble() ?? (totEarn - cashCol);

    return EarningsBreakdownRowModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      orderId: resolvedOrderId,
      orderNumber: resolvedOrderNumber,
      total: resolvedTotal,
      paymentMethod: resolvedPaymentMethod,
      orderStatus: resolvedOrderStatus,
      basePay: base,
      distancePay: dist,
      surgeBonus: surge,
      tipFromCustomer: tip,
      penalty: pen,
      totalEarning: totEarn,
      cashCollected: cashCol,
      netPayout: net,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'COMPLETED',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CashCollectedSummaryModel extends CashCollectedSummaryEntity {
  const CashCollectedSummaryModel({
    required super.totalCashCollected,
    required super.totalEarnings,
    required super.netOwedToCompany,
    required super.netOwedByCompany,
    super.cashInHand,
    super.orders,
  });

  factory CashCollectedSummaryModel.fromJson(Map<String, dynamic> json) {
    final cashInHandVal = (json['cashInHand'] as num?)?.toDouble();
    final cashCol = cashInHandVal ??
        (json['totalCashCollected'] as num?)?.toDouble() ??
        (json['cashCollected'] as num?)?.toDouble() ??
        0.0;
    final earnings = (json['totalEarnings'] as num?)?.toDouble() ??
        (json['earnings'] as num?)?.toDouble() ??
        0.0;
    double owedToCompany = (json['netOwedToCompany'] as num?)?.toDouble() ?? 0.0;
    double owedByCompany = (json['netOwedByCompany'] as num?)?.toDouble() ?? 0.0;

    if (owedToCompany == 0.0 && owedByCompany == 0.0) {
      final diff = cashCol - earnings;
      if (diff > 0) {
        owedToCompany = diff;
      } else {
        owedByCompany = -diff;
      }
    }

    final List<CashCollectedOrderEntity> ordersList = [];
    if (json['orders'] is List) {
      for (final o in json['orders'] as List) {
        if (o is Map) {
          final oMap = Map<String, dynamic>.from(o);
          ordersList.add(CashCollectedOrderEntity(
            orderId: oMap['orderId']?.toString() ?? '',
            amount: (oMap['amount'] as num?)?.toDouble() ?? 0.0,
            collectedAt: oMap['collectedAt'] != null ? DateTime.tryParse(oMap['collectedAt'].toString()) : null,
          ));
        }
      }
    }

    return CashCollectedSummaryModel(
      totalCashCollected: cashCol,
      totalEarnings: earnings,
      netOwedToCompany: owedToCompany,
      netOwedByCompany: owedByCompany,
      cashInHand: cashInHandVal ?? cashCol,
      orders: ordersList,
    );
  }
}
