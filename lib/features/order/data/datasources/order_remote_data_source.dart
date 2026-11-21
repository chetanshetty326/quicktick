import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/local_cache_service.dart';
import '../../../customer/domain/entities/cart_pricing_entity.dart';
import '../../domain/entities/order_entity.dart';

abstract class IOrderRemoteDataSource {
  Future<OrderEntity> createOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String storeId,
    required String storeName,
    required String storeAddress,
    required List<OrderItemEntity> items,
    required double deliveryFee,
    required double platformFee,
    String paymentMethod = 'UPI',
    String? zoneId,
    String? deliveryAddressId,
    String? couponCode,
    double? couponDiscount,
    double? lat,
    double? lng,
    String? city,
    String? postalCode,
    double tip = 0.0,
  });

  Future<List<OrderEntity>> getActiveOrders();
  Future<List<OrderEntity>> getOrderHistory();
  Future<Map<String, dynamic>> trackOrder(String orderId);
  Future<bool> cancelOrder(String orderId, String reason);
  Future<bool> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment);
  Future<List<OrderEntity>> getOrdersByStatus(String status) async => [];
  Future<List<int>> getOrderInvoice(String orderId) async => [];
}

class OrderRemoteDataSourceImpl implements IOrderRemoteDataSource {
  final ApiClient _apiClient;
  static String? _cachedAddressId;

  static void setCachedAddressId(String? id) {
    if (id != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id.trim())) {
      _cachedAddressId = id.trim();
    }
  }

  OrderRemoteDataSourceImpl(this._apiClient);

  @override
  Future<OrderEntity> createOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String storeId,
    required String storeName,
    required String storeAddress,
    required List<OrderItemEntity> items,
    required double deliveryFee,
    required double platformFee,
    String paymentMethod = 'UPI',
    String? zoneId,
    String? deliveryAddressId,
    String? couponCode,
    double? couponDiscount,
    double? lat,
    double? lng,
    String? city,
    String? postalCode,
    double tip = 0.0,
  }) async {
    // Resolve dynamic coordinates from parameters or active cached location
    double effectiveLat = lat ?? 0.0;
    double effectiveLng = lng ?? 0.0;
    String effectiveCity = city ?? '';
    String effectivePostalCode = postalCode ?? '';

    if (effectiveLat == 0.0 || effectiveLng == 0.0) {
      if (sl.isRegistered<ILocalCacheService>()) {
        try {
          final cachedLoc = sl<ILocalCacheService>().getCachedActiveLocation();
          if (cachedLoc != null) {
            effectiveLat = (cachedLoc['lat'] as num?)?.toDouble() ?? 0.0;
            effectiveLng = (cachedLoc['lng'] as num?)?.toDouble() ?? 0.0;
            final addrStr = cachedLoc['address']?.toString() ?? '';
            if (effectiveCity.isEmpty && addrStr.isNotEmpty) {
              effectiveCity = addrStr.split(',').first.trim();
            }
          }
        } catch (_) {}
      }
    }
    if (effectiveLat == 0.0 || effectiveLng == 0.0) {
      effectiveLat = 12.9716;
      effectiveLng = 77.5946;
    }
    if (effectiveCity.isEmpty) {
      effectiveCity = 'Karnataka';
    }
    if (effectivePostalCode.isEmpty) {
      effectivePostalCode = '560001';
    }

    final cleanDeliveryAddressId = deliveryAddressId?.trim() ?? '';
    final isExplicitValidId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(cleanDeliveryAddressId);
    String resolvedAddressId = isExplicitValidId ? cleanDeliveryAddressId : '';

    // 1. If deliveryAddress text is itself already a valid 24-char ObjectId
    final cleanAddr = deliveryAddress.trim();
    final isHexId = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(cleanAddr);
    if (resolvedAddressId.isEmpty && isHexId) {
      resolvedAddressId = cleanAddr;
    }

    // 2. Check cached valid addressId in memory (instant 0ms)
    if (resolvedAddressId.isEmpty &&
        _cachedAddressId != null &&
        RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(_cachedAddressId!.trim())) {
      resolvedAddressId = _cachedAddressId!.trim();
    }

    // 3. Fallback: lookup existing saved addresses first before creating new one
    if (resolvedAddressId.isEmpty) {
      try {
        final getAddrRes = await _apiClient.get(ApiEndpoints.addresses);
        if (getAddrRes.data is Map && getAddrRes.data['data'] is List) {
          final list = getAddrRes.data['data'] as List;
          if (list.isNotEmpty) {
            final defaultAddr = list.firstWhere(
              (a) => a is Map && a['isDefault'] == true,
              orElse: () => list.first,
            );
            if (defaultAddr is Map) {
              resolvedAddressId = (defaultAddr['_id'] ?? defaultAddr['id'])?.toString() ?? '';
            }
          }
        }
      } catch (_) {}

      // 4. Only if user genuinely has zero saved addresses, create one with real coordinates
      if (resolvedAddressId.isEmpty) {
        try {
          final createAddrRes = await _apiClient.post(
            ApiEndpoints.addresses,
            data: {
              'address': (!isHexId && cleanAddr.isNotEmpty) ? cleanAddr : 'Customer Delivery Address',
              'line1': (!isHexId && cleanAddr.isNotEmpty) ? cleanAddr : 'Customer Delivery Address',
              'city': effectiveCity,
              'state': 'Karnataka',
              'postalCode': effectivePostalCode,
              'latitude': effectiveLat,
              'longitude': effectiveLng,
              'type': 'HOME',
              'label': 'Home',
              'isDefault': true,
              'instructions': 'Call before delivery',
            },
          );
          if (createAddrRes.data is Map && createAddrRes.data['data'] is Map) {
            resolvedAddressId = (createAddrRes.data['data']['_id'] ?? createAddrRes.data['data']['id'])?.toString() ?? '';
          }
        } catch (_) {}
      }
    }

    if (resolvedAddressId.isNotEmpty) {
      _cachedAddressId = resolvedAddressId;
    }

    final isCod = paymentMethod.toUpperCase() == 'COD';
    final backendPaymentMethod = isCod ? 'COD' : 'ONLINE';
    final effectiveZoneId = (zoneId != null && zoneId.isNotEmpty) ? zoneId : null;

    final hasNonMongoProducts = items.any((i) => !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(i.productId));
    if (hasNonMongoProducts) {
      throw const ServerException(
        message: 'Products are demo catalog items',
        statusCode: 400,
      );
    }

    final payload = {
      'items': items
          .map((i) => {
                'productId': i.productId,
                'quantity': i.quantity,
              })
          .toList(),
      if (resolvedAddressId.isNotEmpty) 'addressId': resolvedAddressId,
      'paymentMethod': backendPaymentMethod,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      'tip': tip,
      // Legacy fallback fields for broad server compatibility
      'retailerId': storeId,
      'storeId': storeId,
      if (resolvedAddressId.isNotEmpty) 'deliveryAddressId': resolvedAddressId,
      if (couponDiscount != null && couponDiscount > 0) 'couponDiscount': couponDiscount,
      if (effectiveZoneId != null && effectiveZoneId.isNotEmpty) 'zoneId': effectiveZoneId,
    };

    dynamic data;
    try {
      final response = await _apiClient.post(
        ApiEndpoints.orders,
        data: payload,
      );
      data = response.data;
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map) {
        final errMap = resData['error'] is Map ? resData['error'] : resData;
        final errCode = errMap['code']?.toString();
        final errMsg = errMap['message']?.toString();

        if (errCode == 'ZONE_FEES_NOT_CONFIGURED' || (e.response?.statusCode == 409 && errCode != 'OUT_OF_STOCK')) {
          throw const ServerException(
            message: 'Delivery unavailable in this area',
            statusCode: 409,
          );
        } else if (errCode == 'RETAILER_CLOSED') {
          throw const ServerException(
            message: 'The shop is closed',
            statusCode: 400,
          );
        } else if (errCode == 'RETAILER_NOT_APPROVED') {
          throw const ServerException(
            message: 'The shop is unavailable',
            statusCode: 400,
          );
        } else if (errCode == 'OUT_OF_STOCK' || e.response?.statusCode == 409) {
          throw OutOfStockException(
            message: errMsg ?? 'Some items are out of stock. Please review your cart.',
          );
        } else if (errCode == 'VALIDATION_ERROR') {
          throw ServerException(
            message: errMsg ?? 'Validation error during checkout',
            statusCode: 400,
          );
        } else if (errCode == 'OUT_OF_DELIVERY_ZONE') {
          throw ServerException(
            message: errMsg ?? 'Order cannot be placed outside the delivery zone',
            statusCode: e.response?.statusCode,
          );
        } else if (errCode == 'PRODUCT_NOT_FOUND' || (errMsg != null && errMsg.contains('products not found'))) {
          throw ServerException(
            message: errMsg ?? 'One or more products were not found',
            statusCode: e.response?.statusCode,
          );
        }
      }
      rethrow;
    }
    if (data is Map && data['data'] is Map) {
      final orderMap = data['data']['order'] ?? data['data'];
      final mapped = _mapToOrderEntity(orderMap);
      return mapped.copyWith(
        customerName: mapped.customerName.isNotEmpty && mapped.customerName != 'Customer' ? mapped.customerName : customerName,
        customerPhone: mapped.customerPhone.isNotEmpty ? mapped.customerPhone : customerPhone,
        storeName: (storeName.isNotEmpty && storeName != 'Store' && storeName != 'QuickMart Supermarket')
            ? storeName
            : (mapped.storeName.isNotEmpty ? mapped.storeName : storeName),
        storeAddress: (storeAddress.isNotEmpty && storeAddress != 'Local Area')
            ? storeAddress
            : (mapped.storeAddress.isNotEmpty ? mapped.storeAddress : storeAddress),
        deliveryAddress: (!isHexId && cleanAddr.isNotEmpty)
            ? cleanAddr
            : (mapped.deliveryAddress.isNotEmpty && !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(mapped.deliveryAddress) && mapped.deliveryAddress != 'Default Address'
                ? mapped.deliveryAddress
                : (cleanAddr.isNotEmpty ? cleanAddr : 'Customer Delivery Address')),
      );
    }

    throw Exception('Invalid order creation response');
  }

  List _extractOrdersList(dynamic data) {
    if (data is Map) {
      final inner = data['data'];
      if (inner is List) return inner;
      if (inner is Map) {
        if (inner['orders'] is List) return inner['orders'] as List;
        if (inner['items'] is List) return inner['items'] as List;
        if (inner['list'] is List) return inner['list'] as List;
      }
      if (data['orders'] is List) return data['orders'] as List;
      if (data['items'] is List) return data['items'] as List;
    } else if (data is List) {
      return data;
    }
    return [];
  }

  @override
  Future<List<OrderEntity>> getActiveOrders() async {
    final response = await _apiClient.get(
      ApiEndpoints.orders,
      queryParameters: {'limit': 50},
    );
    final rawList = _extractOrdersList(response.data);
    if (rawList.isNotEmpty) {
      final all = rawList.map((json) => _mapToOrderEntity(json)).toList();
      return all.where((o) =>
          o.status != OrderStatus.delivered &&
          o.status != OrderStatus.cancelled &&
          o.status != OrderStatus.rejected &&
          o.status != OrderStatus.failed).toList();
    }
    return [];
  }

  @override
  Future<List<OrderEntity>> getOrderHistory() async {
    final response = await _apiClient.get(
      ApiEndpoints.orders,
      queryParameters: {'limit': 50},
    );
    final rawList = _extractOrdersList(response.data);
    if (rawList.isNotEmpty) {
      return rawList.map((json) => _mapToOrderEntity(json)).toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> trackOrder(String orderId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.orderTracking(orderId));
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data']);
      } else if (data is Map && data.containsKey('status')) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {
      // Fallback to GET /orders/:id
      try {
        final response = await _apiClient.get(ApiEndpoints.customerTrackOrder(orderId));
        final data = response.data;
        if (data is Map && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      } catch (_) {}
    }
    return {};
  }

  @override
  Future<List<OrderEntity>> getOrdersByStatus(String status) async {
    final response = await _apiClient.get(
      ApiEndpoints.orders,
      queryParameters: {'status': status, 'limit': 50},
    );
    final rawList = _extractOrdersList(response.data);
    if (rawList.isNotEmpty) {
      return rawList.map((json) => _mapToOrderEntity(json)).toList();
    }
    return [];
  }

  @override
  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.customerCancelOrder(orderId),
        data: {'reason': reason},
      );
      final data = response.data;
      if (data is Map) {
        if (data['success'] == true) return true;
        if (data['status'] == 'success' || data['status'] == 200 || data['statusCode'] == 200) return true;
        if (data.containsKey('order') || data.containsKey('data')) return true;
        final msg = data['message']?.toString().toLowerCase() ?? '';
        if (msg.contains('cancel') || msg.contains('success')) return true;
      }
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map) {
        final errMap = resData['error'] is Map ? resData['error'] : resData;
        final errCode = errMap['code']?.toString();
        final errMsg = errMap['message']?.toString() ?? '';
        if (errCode == 'ORDER_CANCEL_NOT_ALLOWED' ||
            (e.response?.statusCode == 409 && errMsg.contains('ASSIGNED'))) {
          throw OrderCancelNotAllowedException(
            message: errMsg.isNotEmpty ? errMsg : 'Cancel attempted after ASSIGNED',
          );
        }
        if (errMsg.isNotEmpty) {
          throw ServerException(message: errMsg);
        }
      }
      rethrow;
    }
  }

  @override
  Future<bool> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async {
    final response = await _apiClient.post(
      ApiEndpoints.customerReviewOrder(orderId),
      data: {
        'storeRating': storeRating,
        'deliveryRating': deliveryRating,
        'storeReview': comment,
        'deliveryReview': comment,
      },
    );
    final data = response.data;
    return data is Map && data['success'] == true;
  }

  OrderEntity mapToOrderEntity(dynamic json) => _mapToOrderEntity(json);

  OrderEntity _mapToOrderEntity(dynamic json) {
    if (json is! Map) {
      return OrderEntity(
        id: 'unknown',
        orderNumber: 'QM-0000',
        customerId: '',
        customerName: '',
        customerPhone: '',
        deliveryAddress: '',
        storeId: '',
        storeName: '',
        storeAddress: '',
        items: const [],
        subtotal: 0,
        deliveryFee: 0,
        platformFee: 0,
        grandTotal: 0,
        status: OrderStatus.placed,
        deliveryOtp: '1234',
        createdAt: DateTime.now(),
      );
    }

    String storeName = '';
    String storeAddr = 'Bangalore';
    String sId = 'store_01';

    if (json['storeId'] is Map) {
      final sMap = json['storeId'] as Map;
      storeName = sMap['name']?.toString() ?? sMap['shopName']?.toString() ?? '';
      sId = sMap['_id']?.toString() ?? sMap['id']?.toString() ?? sId;
      if (sMap['address'] is Map) {
        final aMap = sMap['address'] as Map;
        storeAddr = aMap['city']?.toString() ?? aMap['line1']?.toString() ?? storeAddr;
      } else if (sMap['address'] is String) {
        storeAddr = sMap['address'].toString();
      }
    } else if (json['storeId'] is String && json['storeId'].toString().isNotEmpty) {
      sId = json['storeId'].toString();
    }

    if (json['retailerId'] is Map) {
      final rMap = json['retailerId'] as Map;
      if (storeName.isEmpty) {
        storeName = rMap['shopName']?.toString() ?? rMap['name']?.toString() ?? '';
      }
      if (sId == 'store_01') {
        sId = rMap['_id']?.toString() ?? rMap['id']?.toString() ?? sId;
      }
      if (rMap['address'] is Map && storeAddr == 'Bangalore') {
        storeAddr = rMap['address']['city']?.toString() ?? storeAddr;
      }
    } else if (json['retailerId'] is String && json['retailerId'].toString().isNotEmpty && sId == 'store_01') {
      sId = json['retailerId'].toString();
    }

    if (json['store'] is Map) {
      final stMap = json['store'] as Map;
      if (storeName.isEmpty) {
        storeName = stMap['name']?.toString() ?? stMap['shopName']?.toString() ?? '';
      }
    }

    if (storeName.isEmpty && json['storeName'] != null && json['storeName'].toString().trim().isNotEmpty) {
      storeName = json['storeName'].toString().trim();
    }
    if (storeName.isEmpty && json['shopName'] != null && json['shopName'].toString().trim().isNotEmpty) {
      storeName = json['shopName'].toString().trim();
    }

    if (storeName.isEmpty || storeName == 'QuickMart Supermarket' || storeName == 'Store') {
      storeName = _resolveKnownStoreName(sId);
    }
    // Neutral fallback: never show a fake brand name for an unknown store
    if (storeName.isEmpty) {
      storeName = 'Retailer';
    }

    List<OrderItemEntity> orderItems = [];
    if (json['items'] is List) {
      orderItems = (json['items'] as List).map((i) {
        if (i is Map) {
          return OrderItemEntity(
            productId: i['productId']?.toString() ?? 'p1',
            nameSnapshot: i['name'] ?? 'Product',
            priceSnapshot: (i['price'] as num?)?.toDouble() ?? 50.0,
            unit: i['unit'] ?? 'item',
            quantity: (i['quantity'] as num?)?.toInt() ?? 1,
          );
        }
        return const OrderItemEntity(
          productId: 'p1',
          nameSnapshot: 'Product',
          priceSnapshot: 50.0,
          unit: '1 item',
          quantity: 1,
        );
      }).toList();
    }

    final parsedStatus = OrderEntity.parseStatus(json['status']);

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

    final pricingMap = json['pricing'] is Map ? Map<String, dynamic>.from(json['pricing']) : null;
    final subtotal = (json['subtotal'] as num?)?.toDouble() ??
        (pricingMap?['subtotal'] as num?)?.toDouble() ??
        (json['totalAmount'] as num?)?.toDouble() ??
        (json['grandTotal'] as num?)?.toDouble() ??
        100.0;
    final deliveryFee = (json['deliveryFee'] as num?)?.toDouble() ??
        (pricingMap?['deliveryFee'] as num?)?.toDouble() ??
        15.0;
    final platformFee = (json['platformFee'] as num?)?.toDouble() ??
        (pricingMap?['platformFee'] as num?)?.toDouble() ??
        5.0;
    final rawTaxBreakdown = json['taxBreakdown'] is Map
        ? json['taxBreakdown']
        : (pricingMap?['taxBreakdown'] is Map ? pricingMap!['taxBreakdown'] : null);
    final parsedTaxBreakdown = rawTaxBreakdown is Map
        ? TaxBreakdownEntity.fromJson(Map<String, dynamic>.from(rawTaxBreakdown))
        : const TaxBreakdownEntity();
    final parsedTax = (json['tax'] as num?)?.toDouble() ??
        (pricingMap?['tax'] as num?)?.toDouble() ??
        (json['taxAmount'] as num?)?.toDouble() ??
        (json['gstAmount'] as num?)?.toDouble() ??
        (json['gst'] as num?)?.toDouble() ??
        parsedTaxBreakdown.total;
    final resolvedTax = parsedTax > 0 ? parsedTax : parsedTaxBreakdown.total;
    final parsedDiscount = (json['discount'] as num?)?.toDouble() ??
        (json['couponDiscount'] as num?)?.toDouble() ??
        (pricingMap?['discount'] as num?)?.toDouble() ??
        0.0;
    final parsedTip = (json['tip'] as num?)?.toDouble() ??
        (pricingMap?['tip'] as num?)?.toDouble() ??
        0.0;
    final grandTotal = (json['total'] as num?)?.toDouble() ??
        (json['grandTotal'] as num?)?.toDouble() ??
        (pricingMap?['grandTotal'] as num?)?.toDouble() ??
        (pricingMap?['total'] as num?)?.toDouble() ??
        (subtotal + deliveryFee + platformFee + resolvedTax + parsedTip - parsedDiscount);

    String deliveryAddr = 'Default Address';
    if (json['addressSnapshot'] is Map) {
      final snap = json['addressSnapshot'] as Map;
      final line1 = snap['line1']?.toString() ?? '';
      final city = snap['city']?.toString() ?? '';
      deliveryAddr = [line1, city].where((s) => s.isNotEmpty).join(', ');
      if (deliveryAddr.isEmpty) deliveryAddr = 'Default Address';
    } else if (json['deliveryAddress'] is Map) {
      deliveryAddr = json['deliveryAddress']['line1']?.toString() ?? 'Default Address';
    } else if (json['deliveryAddress'] != null && json['deliveryAddress'].toString().isNotEmpty) {
      deliveryAddr = json['deliveryAddress'].toString();
    }
    if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(deliveryAddr.trim())) {
      deliveryAddr = 'Default Address';
    }

    final rejReason = json['rejectionReason']?.toString() ??
        json['cancelReason']?.toString() ??
        json['reason']?.toString();

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
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? 'QM-ORDER',
      customerId: json['userId']?.toString() ?? json['customerId']?.toString() ?? 'customer_01',
      customerName: 'Customer',
      customerPhone: '',
      deliveryAddress: deliveryAddr,
      storeId: json['retailerId']?.toString() ?? sId,
      storeName: storeName,
      storeAddress: storeAddr,
      deliveryPartnerId: pId,
      deliveryPartnerName: pName,
      deliveryPartnerPhone: pPhone,
      deliveryPartner: parsedPartner,
      items: orderItems,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      discount: parsedDiscount,
      tip: parsedTip,
      tax: resolvedTax,
      taxBreakdown: parsedTaxBreakdown,
      grandTotal: (json['total'] as num?)?.toDouble() ?? grandTotal,
      couponCode: json['couponCode']?.toString(),
      status: parsedStatus,
      deliveryOtp: json['deliveryOtp']?.toString() ?? '1234',
      paymentMethod: pMethod,
      paymentStatus: pStatus,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      rejectionReason: rejReason,
      zoneId: json['zoneId'] is Map
          ? json['zoneId']['_id']?.toString()
          : json['zoneId']?.toString(),
      retailerGstinSnapshot: json['retailerGstinSnapshot']?.toString() ??
          json['gstin']?.toString() ??
          (json['retailer'] is Map ? json['retailer']['gstin']?.toString() : null),
      retailerStateSnapshot: json['retailerStateSnapshot']?.toString() ??
          (json['retailer'] is Map ? json['retailer']['state']?.toString() : null),
      retailerNameSnapshot: json['retailerNameSnapshot']?.toString() ?? storeName,
    );
  }

  @override
  Future<List<int>> getOrderInvoice(String orderId) async {
    final response = await _apiClient.get(
      ApiEndpoints.orderInvoice(orderId),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Accept': 'application/pdf, application/octet-stream, */*'},
      ),
    );
    return _extractPdfBytes(response.data);
  }

  Future<List<int>> _extractPdfBytes(dynamic rawData, {bool allowUrlRedirect = true}) async {
    if (rawData is Map) {
      return _resolvePdfFromJson(rawData, allowUrlRedirect: allowUrlRedirect);
    }

    List<int>? bytes;
    if (rawData is List<int>) {
      bytes = rawData;
    } else if (rawData is List) {
      bytes = rawData.whereType<num>().map((e) => e.toInt()).toList();
    }

    if (bytes == null || bytes.isEmpty) {
      throw ServerException(message: 'Invoice PDF is empty.');
    }

    if (_isPdfSignature(bytes)) {
      return bytes;
    }

    // Backend may return JSON (error payload, base64 PDF, or signed invoice URL)
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          return _resolvePdfFromJson(decoded, allowUrlRedirect: allowUrlRedirect);
        }
      } catch (e) {
        if (e is ServerException) rethrow;
      }
    }

    throw ServerException(message: 'Invalid invoice PDF received from server.');
  }

  Future<List<int>> _resolvePdfFromJson(Map json, {required bool allowUrlRedirect}) async {
    final payload = json['data'] is Map ? json['data'] as Map : json;

    if (allowUrlRedirect) {
      final url = (payload['invoiceUrl'] ?? payload['pdfUrl'] ?? payload['url'])?.toString().trim();
      if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
        final pdfResponse = await _apiClient.get(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Accept': 'application/pdf, application/octet-stream, */*'},
          ),
        );
        return _extractPdfBytes(pdfResponse.data, allowUrlRedirect: false);
      }
    }

    final base64Raw = (payload['pdf'] ?? payload['base64'] ?? payload['content'] ?? (json['data'] is String ? json['data'] : null))?.toString();
    if (base64Raw != null && base64Raw.isNotEmpty) {
      final cleaned = base64Raw.contains(',') ? base64Raw.split(',').last : base64Raw;
      try {
        final decodedBytes = base64Decode(cleaned.trim());
        if (_isPdfSignature(decodedBytes)) {
          return decodedBytes;
        }
      } catch (_) {}
    }

    final errMap = json['error'] is Map ? json['error'] as Map : null;
    final msg = (errMap?['message'] ?? json['message'] ?? json['error'])?.toString();
    throw ServerException(
      message: (msg != null && msg.isNotEmpty) ? msg : 'Failed to download order invoice PDF',
    );
  }

  bool _isPdfSignature(List<int> bytes) {
    // Allow leading whitespace/BOM before %PDF-
    var offset = 0;
    while (offset < bytes.length && offset < 16 && (bytes[offset] <= 0x20 || bytes[offset] == 0xEF || bytes[offset] == 0xBB || bytes[offset] == 0xBF)) {
      offset++;
    }
    return bytes.length >= offset + 4 &&
        bytes[offset] == 0x25 && // %
        bytes[offset + 1] == 0x50 && // P
        bytes[offset + 2] == 0x44 && // D
        bytes[offset + 3] == 0x46; // F
  }

  String _resolveKnownStoreName(String storeId) {
    switch (storeId) {
      case '6aa3febe8b2afec202cc65cc':
        return 'BigBasket Express';
      case '6aa4d2968e786cd9f0772009':
        return 'Daily Needs Supermarket';
      case '6aa57f6a191b0ba5d25863af':
        return 'Spice Garden Restaurant';
      case '6aa4d51e8e786cd9f07720bb':
        return 'malnad spicies';
      case '6aa3febe8b2afec202cc65cb':
        return 'Daily Needs Store';
      case '6aa3febe8b2afec202cc65c9':
        return 'QuickStore S391';
      case '6aa3febe8b2afec202cc65ca':
        return 'FreshMart Grocery';
      case '6aa3febe8b2afec202cc65ce':
        return 'Organic Hub';
      case '6aa3febe8b2afec202cc65cd':
        return 'Corner Shop';
      case 'store_04':
        return 'Spice Route';
      case 'store_05':
        return 'The Rustic Oven';
      case 'store_06':
        return 'Urban Brew Cafe';
      case 'store_02':
        return 'Green Leaf Organic';
      case 'store_03':
        return 'Sunrise Bakery';
      default:
        return '';
    }
  }
}
