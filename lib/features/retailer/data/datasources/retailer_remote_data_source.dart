import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../../customer/data/models/product_model.dart';
import '../../../customer/domain/entities/catalog_entities.dart';
import '../../../order/domain/entities/order_entity.dart';
import '../../domain/entities/retailer_entities.dart';
import '../../domain/entities/retailer_finance_entities.dart';
import '../../../customer/data/models/hero_banner_model.dart';
import '../models/retailer_finance_models.dart';
import '../models/retailer_notification_model.dart';
import '../models/retailer_registration_models.dart';

class RetailerPayoutModel {
  final double totalSales;
  final double platformFee;
  final double netPayable;
  final double codCollected;
  final double onlineCollected;
  final String payoutStatus;

  const RetailerPayoutModel({
    required this.totalSales,
    required this.platformFee,
    required this.netPayable,
    required this.codCollected,
    required this.onlineCollected,
    required this.payoutStatus,
  });

  factory RetailerPayoutModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map : json;
    return RetailerPayoutModel(
      totalSales: (data['totalSales'] as num?)?.toDouble() ?? 0.0,
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0.0,
      netPayable: (data['netPayable'] as num?)?.toDouble() ?? 0.0,
      codCollected: (data['codCollected'] as num?)?.toDouble() ?? 0.0,
      onlineCollected: (data['onlineCollected'] as num?)?.toDouble() ?? 0.0,
      payoutStatus: data['payoutStatus']?.toString().toUpperCase() ?? 'PENDING',
    );
  }
}

abstract class IRetailerRemoteDataSource {
  Future<RetailerStoreProfileEntity> registerStore(Map<String, dynamic> data);
  Future<RetailerStoreProfileEntity> updateStoreProfile(Map<String, dynamic> data);
  Future<RetailerStoreProfileEntity> getStoreProfile();
  Future<bool> toggleStoreStatus(bool isOpen);

  // New Retailer Verification & Registration Status Methods
  Future<({bool available, String message})> checkStoreName(String name);
  Future<RetailerCheckRegisteredModel> checkRetailerRegistration();
  Future<RetailerRejectionModel> getRejectionReason();
  Future<FileUploadModel> uploadFile({required String filePath, String? folder});
  Future<bool> updateShopPhoto(String shopPhotoUrl);

  Future<List<OrderEntity>> getLiveOrders();
  Future<List<OrderEntity>> getFilteredOrders({
    String? paymentStatus,
    String? paymentMethod,
    int page = 1,
    int limit = 20,
  });
  Future<RetailerPayoutModel> getRetailerPayouts({
    DateTime? from,
    DateTime? to,
  });
  Future<List<OrderEntity>> getOrderHistory();
  Future<OrderEntity> acceptOrder(String orderId);
  Future<OrderEntity> markPreparing(String orderId);
  Future<OrderEntity> markReady(String orderId);
  Future<OrderEntity> rejectOrder(String orderId, String reason);

  Future<List<ProductEntity>> getCatalogItems();
  Future<ProductEntity> addProduct(ProductEntity product);
  Future<ProductEntity> updateProduct(ProductEntity product);
  Future<bool> deleteProduct(String productId);
  Future<bool> toggleProductStock(String productId, bool isAvailable, {int? currentStock});

  Future<RetailerDashboardStatsEntity> getDashboardStats();
  Future<bool> registerDeviceToken({required String fcmToken, required String platform, required String deviceId});

  // Notifications Module
  Future<List<Map<String, dynamic>>> getNotifications();
  Future<int> getUnreadNotificationCount();
  Future<bool> markNotificationRead(String notificationId);
  Future<bool> markAllNotificationsRead();

  // Subscription Module
  Future<RetailerSubscriptionEntity?> getSubscription();

  // Finance Module (Spec R2 - R5)
  Future<RetailerEarningsSummaryEntity> getEarningsSummary();
  Future<List<RetailerEarningEntity>> getEarnings({String? status, int limit = 50, int skip = 0});
  Future<List<RetailerSettlementEntity>> getSettlements({int limit = 50, int skip = 0});
  Future<RetailerBankAccountEntity> updateBankAccount(Map<String, dynamic> data);

  // Hero Banners Module (Retailer Announcements)
  Future<List<HeroBannerModel>> getHeroBanners({String app = 'RETAILER'});
}

class RetailerRemoteDataSourceImpl implements IRetailerRemoteDataSource {
  final ApiClient _apiClient;
  final ISecureStorageService? _secureStorage;

  RetailerRemoteDataSourceImpl(this._apiClient, [this._secureStorage]);

  Map<String, dynamic> _prepareStorePayload(Map<String, dynamic> data) {
    final payload = Map<String, dynamic>.from(data);
    final sName = payload['shopName'] ?? payload['name'] ?? payload['storeName'] ?? 'Quick Mart Partner Store';
    payload['shopName'] = sName;
    payload['name'] = sName;

    final phoneVal = payload['phone'] ?? payload['contactPhone'] ?? payload['mobile'] ?? '9876543210';
    final cleanPhone = phoneVal.toString().replaceAll(RegExp(r'\D'), '');
    final standardPhone = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final formattedPhone = standardPhone.isNotEmpty ? '+91$standardPhone' : phoneVal.toString();
    payload['phone'] = formattedPhone;
    payload['contactPhone'] = standardPhone;
    payload['mobile'] = formattedPhone;

    // Zone ID validation: Backend Mongoose schema requires a valid 24-character hex ObjectId
    final dynamic zoneSource = payload['zoneId'] ?? data['zoneId'] ?? payload['zone'] ?? data['zone'];
    final rawZone = (zoneSource is Map ? (zoneSource['_id'] ?? zoneSource['id']) : zoneSource)?.toString().trim();
    if (rawZone != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(rawZone)) {
      payload['zoneId'] = rawZone;
    } else {
      // Remove invalid string to avoid Mongoose BSONError Cast to ObjectId
      payload.remove('zoneId');
    }

    if (payload['address'] is Map) {
      final addr = Map<String, dynamic>.from(payload['address'] as Map);
      final line1 = addr['line1'] ?? addr['street'] ?? '#104, 100ft Road, Indiranagar';
      final city = addr['city'] ?? 'Bengaluru';
      final state = addr['state'] ?? 'Karnataka';
      final postal = addr['postalCode'] ?? addr['pincode'] ?? '560038';
      payload['address'] = {
        'line1': line1,
        'street': line1,
        'city': city,
        'state': state,
        'postalCode': postal,
        'pincode': postal,
        'country': addr['country'] ?? 'India',
      };
    } else if (payload['address'] is String && payload['address'].toString().trim().isNotEmpty) {
      final strAddr = payload['address'].toString().trim();
      payload['address'] = {
        'line1': strAddr,
        'street': strAddr,
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'postalCode': '560038',
        'country': 'India',
      };
    } else {
      payload['address'] = {
        'line1': '#104, 100ft Road, Indiranagar',
        'street': '#104, 100ft Road, Indiranagar',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'postalCode': '560038',
        'country': 'India',
      };
    }

    if (payload['location'] is Map) {
      final loc = payload['location'] as Map;
      if (loc.containsKey('lat') && loc.containsKey('lng')) {
        payload['location'] = {
          'type': 'Point',
          'coordinates': [
            (loc['lng'] as num?)?.toDouble() ?? 77.5946,
            (loc['lat'] as num?)?.toDouble() ?? 12.9716,
          ],
        };
      } else if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
        final cList = loc['coordinates'] as List;
        payload['location'] = {
          'type': 'Point',
          'coordinates': [
            (cList[0] as num?)?.toDouble() ?? 77.5946,
            (cList[1] as num?)?.toDouble() ?? 12.9716,
          ],
        };
      }
    } else {
      payload['location'] = {
        'type': 'Point',
        'coordinates': [77.5946, 12.9716],
      };
    }

    // Category mapping: Backend Mongoose schema requires strict enum:
    // ['General', 'Grocery', 'Pharmacy', 'Restaurant', 'Bakery', 'Dairy', 'Electronics', 'Other']
    final rawCat = payload['category']?.toString() ?? payload['selectedStoreType']?.toString() ?? 'Grocery';
    final backendEnumCat = mapCategoryToBackendEnum(rawCat);
    payload['category'] = backendEnumCat;

    final existingCats = payload['categories'] is List
        ? List<String>.from((payload['categories'] as List).map((e) => e.toString()))
        : <String>[];
    if (!existingCats.contains(backendEnumCat)) {
      existingCats.insert(0, backendEnumCat);
    }
    if (rawCat.isNotEmpty && !existingCats.contains(rawCat) && rawCat != backendEnumCat) {
      existingCats.add(rawCat);
    }
    payload['categories'] = existingCats;

    // Service radius in km (Spec item 3)
    payload['serviceRadiusKm'] = (payload['serviceRadiusKm'] as num?)?.toInt() ?? 5;

    // Mongoose schema expects documents as an Array of objects: [{ type: String, url: String, number?: String }]
    final List<Map<String, dynamic>> processedDocs = [];
    if (payload['documents'] is List) {
      for (final d in (payload['documents'] as List)) {
        if (d is Map) {
          final m = Map<String, dynamic>.from(d);
          final type = m['type']?.toString().trim().isNotEmpty == true
              ? m['type'].toString().trim().toUpperCase()
              : 'DOCUMENT';
          final rawUrl = m['url']?.toString().trim();
          if (rawUrl != null && rawUrl.startsWith('https://')) {
            processedDocs.add({
              'type': type,
              'url': rawUrl,
              if (m['number'] != null && m['number'].toString().isNotEmpty) 'number': m['number'].toString(),
            });
          }
        }
      }
    } else if (payload['documents'] is Map) {
      final docMap = Map<String, dynamic>.from(payload['documents'] as Map);
      void addIfValid(String type, String? url, String? number) {
        if (url != null && url.startsWith('https://') && number != null && number.trim().isNotEmpty) {
          processedDocs.add({
            'type': type,
            'url': url.trim(),
            'number': number.trim(),
          });
        }
      }

      addIfValid('PAN', docMap['panDocUrl']?.toString(), docMap['panNumber']?.toString());
      addIfValid('GSTIN', docMap['gstDocUrl']?.toString(), docMap['gstin']?.toString());
      addIfValid('FSSAI', docMap['fssaiDocUrl']?.toString(), docMap['fssaiNumber']?.toString());
      addIfValid('DRUG_LICENSE', docMap['drugDocUrl']?.toString(), docMap['drugLicenseNumber']?.toString());
      addIfValid('TRADE_LICENSE', docMap['tradeDocUrl']?.toString(), docMap['tradeLicenseNumber']?.toString());
      addIfValid('MEAT_NOC', docMap['meatNocDocUrl']?.toString(), docMap['meatNocNumber']?.toString());
    }

    final shopPhoto = payload['shopPhotoUrl']?.toString().trim();
    if (shopPhoto != null && shopPhoto.startsWith('https://')) {
      payload['shopPhotoUrl'] = shopPhoto;
      final bool alreadyHasPhoto = processedDocs.any((d) => d['type'] == 'SHOP_PHOTO');
      if (!alreadyHasPhoto) {
        processedDocs.insert(0, {
          'type': 'SHOP_PHOTO',
          'url': shopPhoto,
          'status': 'PENDING',
        });
      }
    }

    payload['documents'] = processedDocs;

    // R6: Optional bank account during registration
    if (payload['bankAccount'] is Map) {
      final b = Map<String, dynamic>.from(payload['bankAccount'] as Map);
      payload['bankAccount'] = {
        'holderName': b['holderName']?.toString() ?? '',
        'accountNumber': b['accountNumber']?.toString() ?? '',
        'ifscCode': b['ifscCode']?.toString() ?? '',
        'bankName': b['bankName']?.toString() ?? '',
      };
    }

    return payload;
  }

  @override
  Future<RetailerStoreProfileEntity> registerStore(Map<String, dynamic> data) =>
      _registerStoreInternal(data, isRetry: false);

  @override
  Future<RetailerStoreProfileEntity> updateStoreProfile(Map<String, dynamic> data) =>
      _updateStoreProfileInternal(data, isRetry: false);

  Future<RetailerStoreProfileEntity> _registerStoreInternal(Map<String, dynamic> data, {bool isRetry = false}) async {
    final payload = _prepareStorePayload(data);

    // If zoneId is missing or removed, auto-resolve valid ObjectId from coordinates
    if (!payload.containsKey('zoneId') || payload['zoneId'] == null) {
      try {
        final loc = payload['location'];
        if (loc is Map && loc['coordinates'] is List) {
          final coords = loc['coordinates'] as List;
          if (coords.length >= 2) {
            final lng = coords[0];
            final lat = coords[1];
            final zRes = await _apiClient.get(
              ApiEndpoints.zonesCheckLocation,
              queryParameters: {'lat': lat, 'lng': lng},
            );
            if (zRes.data is Map) {
              final zData = zRes.data['data'] is Map ? zRes.data['data'] as Map : zRes.data;
              final bool insideZone = zData['inZone'] == true || zData['insideZone'] == true;
              if (!insideZone) {
                throw ServerException(message: 'Store location is outside operational service zones. Registration cannot proceed.');
              }
              final z = zData['zone'] is Map ? zData['zone'] as Map : null;
              final zid = z?['_id']?.toString() ?? z?['id']?.toString() ?? zData['zoneId']?.toString();
              if (zid != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(zid)) {
                payload['zoneId'] = zid;
              }
            }
          }
        }
      } on ServerException {
        rethrow;
      } catch (_) {}
    }

    // Strict Zone Enforcement: Store cannot register without a verified operational zone
    if (!payload.containsKey('zoneId') || payload['zoneId'] == null || payload['zoneId'].toString().isEmpty) {
      throw ServerException(message: 'Store location is outside operational service zones. Registration cannot proceed.');
    }

    try {
      final response = await _apiClient.post(
        ApiEndpoints.retailerRegister,
        data: payload,
      );
      final resData = response.data;
      if (resData is Map && resData['data'] is Map) {
        final d = resData['data'] as Map;
        // Gotcha #1: Save brand new accessToken with role: RETAILER returned upon registration
        final newAccessToken = d['accessToken']?.toString();
        if (newAccessToken != null && newAccessToken.isNotEmpty && _secureStorage != null) {
          final currentRefresh = await _secureStorage.getRefreshToken();
          await _secureStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: currentRefresh ?? '',
            expiryDuration: const Duration(days: 30),
          );
          final userMap = d['user'] is Map ? d['user'] as Map : {};
          await _secureStorage.saveUserData(
            userId: (userMap['_id'] ?? userMap['id'] ?? '').toString(),
            role: 'retailer',
            name: userMap['name']?.toString() ?? payload['shopName']?.toString() ?? 'Store Partner',
            phone: userMap['mobile']?.toString() ?? userMap['phone']?.toString() ?? payload['phone']?.toString() ?? '',
            email: userMap['email']?.toString(),
            expiryDuration: const Duration(days: 30),
          );
        }
        return _parseStoreProfile(resData['data']);
      }
      return _parseStoreProfile(resData is Map ? resData : {});
    } catch (e) {
      if (e is DuplicateResourceFailure) {
        if (e.message.toLowerCase().contains('already registered') && !isRetry) {
          try {
            return await _updateStoreProfileInternal(payload, isRetry: true);
          } catch (_) {}
        }
        throw DuplicateResourceException(
          message: e.message,
          code: e.code,
          statusCode: e.statusCode,
        );
      }
      if (e is DuplicateResourceException) {
        rethrow;
      }
      if (e is Failure) {
        final msg = e.message.toLowerCase();
        final isAlreadyRegistered = msg.contains('already registered') ||
            (e.statusCode == 409 && msg.contains('already'));
        if (isAlreadyRegistered && !isRetry) {
          try {
            return await _updateStoreProfileInternal(payload, isRetry: true);
          } catch (_) {}
        }
        rethrow;
      }
      if (e is DioException) {
        final errData = e.response?.data is Map ? (e.response?.data as Map) : null;
        final errorCode = errData?['error'] is Map
            ? errData!['error']['code']?.toString()
            : errData?['code']?.toString();
        final errorMsg = (errData?['error'] is Map
            ? errData!['error']['message']?.toString()
            : errData?['message']?.toString()) ?? '';

        if (errorCode == 'RESOURCE_ALREADY_EXISTS' || errorMsg.toLowerCase().contains('shop name')) {
          throw DuplicateResourceException(
            message: 'Shop name already taken. Please choose another shop name.',
            code: 'RESOURCE_ALREADY_EXISTS',
            statusCode: 409,
          );
        }

        final isAlreadyRegistered = errorCode == 'RETAILER_ALREADY_REGISTERED' ||
            errorMsg.toLowerCase().contains('already registered') ||
            (e.response?.statusCode == 409 && errorMsg.toLowerCase().contains('already'));
        if (isAlreadyRegistered && !isRetry) {
          return await _updateStoreProfileInternal(payload, isRetry: true);
        }
      }
      rethrow;
    }
  }

  @override
  Future<RetailerCheckRegisteredModel> checkRetailerRegistration() async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.retailerCheckRegistered,
        data: {},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return RetailerCheckRegisteredModel.fromJson(data);
      } else if (data is Map) {
        return RetailerCheckRegisteredModel.fromJson(Map<String, dynamic>.from(data));
      }
      return const RetailerCheckRegisteredModel(registered: false);
    } catch (e) {
      if (e is Failure) {
        throw ServerException(message: e.message, statusCode: e.statusCode);
      }
      if (e is DioException) {
        final msg = e.response?.data is Map ? e.response?.data['message']?.toString() : e.message;
        throw ServerException(message: msg ?? 'Failed to check retailer registration status');
      }
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<RetailerRejectionModel> getRejectionReason() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.retailerRejection);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return RetailerRejectionModel.fromJson(data);
      } else if (data is Map) {
        return RetailerRejectionModel.fromJson(Map<String, dynamic>.from(data));
      }
      return const RetailerRejectionModel(status: 'REJECTED');
    } catch (e) {
      if (e is Failure) {
        throw ServerException(message: e.message, statusCode: e.statusCode);
      }
      if (e is DioException) {
        final msg = e.response?.data is Map ? e.response?.data['message']?.toString() : e.message;
        throw ServerException(message: msg ?? 'Failed to get rejection reason');
      }
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<FileUploadModel> uploadFile({required String filePath, String? folder}) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final length = await file.length();
        if (length > 10 * 1024 * 1024) {
          throw const ServerException(message: 'File size exceeds maximum 10 MB limit.');
        }
      }

      final fileName = filePath.split(RegExp(r'[/\\]')).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        if (folder != null && folder.isNotEmpty) 'folder': folder,
      });

      final response = await _apiClient.post(
        ApiEndpoints.uploadsSingle,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      final data = response.data;
      FileUploadModel model;
      if (data is Map<String, dynamic>) {
        model = FileUploadModel.fromJson(data);
      } else if (data is Map) {
        model = FileUploadModel.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw const ServerException(message: 'Invalid file upload response');
      }

      if (model.url.isEmpty || !model.url.startsWith('https://')) {
        throw const ServerException(message: 'Upload response did not contain a valid HTTPS URL');
      }

      return model;
    } catch (e) {
      if (e is Failure) {
        throw ServerException(message: e.message, statusCode: e.statusCode);
      }
      if (e is DioException) {
        final msg = e.response?.data is Map ? e.response?.data['message']?.toString() : e.message;
        throw ServerException(message: msg ?? 'File upload failed');
      }
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<bool> updateShopPhoto(String shopPhotoUrl) async {
    if (!shopPhotoUrl.startsWith('https://')) {
      throw const ServerException(message: 'Shop photo URL must start with https://');
    }
    final res = await _apiClient.put(
      ApiEndpoints.retailerMe,
      data: {'shopPhotoUrl': shopPhotoUrl},
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  @override
  Future<({bool available, String message})> checkStoreName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return (available: true, message: 'Store name is available');
    }

    // 1. Check live backend search via GET /admin/retailers-search?q=<name> (Spec Item 4)
    try {
      final searchRes = await _apiClient.get(
        ApiEndpoints.adminRetailersSearch,
        queryParameters: {'q': cleanName},
      );
      final searchData = searchRes.data;
      if (searchData is Map && searchData['data'] is Map && searchData['data']['retailers'] is List) {
        final retailers = searchData['data']['retailers'] as List;
        final exactMatch = retailers.any((r) {
          if (r is Map) {
            final sName = r['shopName']?.toString().trim().toLowerCase();
            return sName == cleanName.toLowerCase();
          }
          return false;
        });
        if (exactMatch) {
          return (
            available: false,
            message: 'Shop name "$cleanName" is already registered on QuickMart. Please choose another name.'
          );
        }
      }
    } catch (_) {
      // Gracefully fall back to dedicated check-name endpoint
    }

    try {
      final response = await _apiClient.get(
        ApiEndpoints.retailerCheckStoreName,
        queryParameters: {'name': cleanName},
      );
      final data = response.data;
      if (data is Map) {
        final dynamic rawAvail = data['available'] ?? (data['data'] is Map ? data['data']['available'] : null);
        final available = rawAvail == true;
        final message = data['message']?.toString() ??
            (data['data'] is Map ? data['data']['message']?.toString() : null) ??
            (available ? 'Store name is available' : 'Shop name already taken. Please choose another shop name.');
        return (available: available, message: message);
      }
      return (available: true, message: 'Store name is available');
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        final resData = e.response!.data as Map;
        final msg = resData['message']?.toString() ??
            (resData['data'] is Map ? resData['data']['message']?.toString() : null) ??
            'Store name validation failed';
        final dynamic rawAvail = resData['available'] ?? (resData['data'] is Map ? resData['data']['available'] : null);
        final available = rawAvail == true;
        return (available: available, message: msg);
      }
      return (available: true, message: 'Store name is available');
    }
  }

  Future<RetailerStoreProfileEntity> _updateStoreProfileInternal(Map<String, dynamic> data, {bool isRetry = false}) async {
    final payload = _prepareStorePayload(data);
    try {
      final response = await _apiClient.put(
        ApiEndpoints.retailerProfile,
        data: payload,
      );
      final resData = response.data;
      if (resData is Map && resData['data'] is Map) {
        return _parseStoreProfile(resData['data']);
      }
      return _parseStoreProfile(resData is Map ? resData : {});
    } catch (e) {
      if (e is Failure && e.statusCode == 404 && !isRetry) {
        return await _registerStoreInternal(payload, isRetry: true);
      }
      if (e is DioException && e.response?.statusCode == 404 && !isRetry) {
        return await _registerStoreInternal(payload, isRetry: true);
      }
      rethrow;
    }
  }

  /// Maps human-friendly UI store category labels to the strict Mongoose backend enum:
  /// enumValues: ['General', 'Grocery', 'Pharmacy', 'Restaurant', 'Bakery', 'Dairy', 'Electronics', 'Other']
  static String mapCategoryToBackendEnum(String rawCategory) {
    final lower = rawCategory.trim().toLowerCase();
    if (lower.contains('restaurant') ||
        lower.contains('dine-in') ||
        lower.contains('cloud kitchen') ||
        lower.contains('cafe') ||
        lower.contains('beverage') ||
        lower.contains('food') ||
        lower.contains('kitchen')) {
      return 'Restaurant';
    }
    if (lower.contains('pharmacy') ||
        lower.contains('wellness') ||
        lower.contains('drug') ||
        lower.contains('medicine') ||
        lower.contains('chemist')) {
      return 'Pharmacy';
    }
    if (lower.contains('bakery') || lower.contains('confectionery') || lower.contains('cake') || lower.contains('pastry')) {
      return 'Bakery';
    }
    if (lower.contains('dairy') || lower.contains('milk')) {
      return 'Dairy';
    }
    if (lower.contains('electronic') || lower.contains('gadget') || lower.contains('appliance')) {
      return 'Electronics';
    }
    if (lower.contains('grocery') ||
        lower.contains('supermarket') ||
        lower.contains('mart') ||
        lower.contains('meat') ||
        lower.contains('seafood') ||
        lower.contains('fish') ||
        lower.contains('chicken')) {
      return 'Grocery';
    }
    if (lower.contains('general') || lower.contains('retail') || lower.contains('pet') || lower.contains('supplies')) {
      return 'General';
    }
    const validEnums = ['General', 'Grocery', 'Pharmacy', 'Restaurant', 'Bakery', 'Dairy', 'Electronics', 'Other'];
    for (final v in validEnums) {
      if (v.toLowerCase() == lower) return v;
    }
    return 'Other';
  }

  static String _normalizeUnit(String raw) {
    final l = raw.toLowerCase().trim();
    if (l == 'kg' || l.endsWith('kg')) return 'kg';
    if (l == 'g' || l.endsWith('g') || l.contains('gm')) return 'g';
    if (l == 'l' || l.endsWith('l') || l.contains('ltr') || l.contains('liter')) return 'l';
    if (l == 'ml' || l.endsWith('ml')) return 'ml';
    if (l.contains('box')) return 'box';
    if (l.contains('pack') || l.contains('pkt')) return 'pack';
    return 'piece';
  }

  static String _resolveMongoCategoryId(String cat) {
    if (RegExp(r'^[a-f0-9]{24}$').hasMatch(cat)) return cat;
    final lower = cat.toLowerCase().trim();
    if (lower.contains('dairy') || lower.contains('milk') || lower.contains('egg')) {
      return '6aa3febd8b2afec202cc65be'; // Dairy & Eggs
    }
    if (lower.contains('bever') || lower.contains('drink') || lower.contains('juice') || lower.contains('tea') || lower.contains('coffee')) {
      return '6aa3febd8b2afec202cc65bf'; // Beverages
    }
    if (lower.contains('snack') || lower.contains('munch') || lower.contains('biscuit') || lower.contains('chip')) {
      return '6aa3febd8b2afec202cc65c0'; // Snacks
    }
    if (lower.contains('care') || lower.contains('hygiene') || lower.contains('soap') || lower.contains('shampoo')) {
      return '6aa3febd8b2afec202cc65c1'; // Personal Care
    }
    if (lower.contains('frozen') || lower.contains('ice')) {
      return '6aa3febd8b2afec202cc65c2'; // Frozen Foods
    }
    if (lower.contains('bak') || lower.contains('bread') || lower.contains('cake') || lower.contains('bun')) {
      return '6aa3febd8b2afec202cc65c3'; // Bakery
    }
    if (lower.contains('baby') || lower.contains('diaper')) {
      return '6aa3febd8b2afec202cc65c4'; // Baby Care
    }
    if (lower.contains('house') || lower.contains('clean') || lower.contains('detergent')) {
      return '6aa3febd8b2afec202cc65c5'; // Household
    }
    if (lower.contains('pet') || lower.contains('dog') || lower.contains('cat')) {
      return '6aa3febd8b2afec202cc65c6'; // Pet Care
    }
    if (lower.contains('organic')) {
      return '6aa3febd8b2afec202cc65c7'; // Organic
    }
    return '6aa3febd8b2afec202cc65bd'; // Groceries
  }

  @override
  Future<RetailerStoreProfileEntity> getStoreProfile() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.retailerProfile);
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return _parseStoreProfile(data['data']);
      }
      return _parseStoreProfile(data is Map ? data : {});
    } on DioException catch (e) {
      // 404 means the retailer has not registered yet — route to registration screen.
      // Do NOT auto-register a fake store; that creates ghost records on the backend.
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      throw ServerException(
        message: msg ?? 'Store profile not found',
        statusCode: e.response?.statusCode,
      );
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<bool> toggleStoreStatus(bool isOpen) async {
    final response = await _apiClient.patch(
      ApiEndpoints.retailerToggleStatus,
      data: {
        'status': isOpen ? 'OPEN' : 'CLOSED',
        'isOpen': isOpen,
      },
    );
    final data = response.data;
    return data is Map && (data['success'] == true || data['isOpen'] == isOpen);
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
  Future<List<OrderEntity>> getLiveOrders() async {
    final response = await _apiClient.get(ApiEndpoints.retailerLiveOrders);
    final rawList = _extractOrdersList(response.data);
    return rawList.map((json) {
      try { return _parseOrder(json); } catch (_) { return null; }
    }).whereType<OrderEntity>().toList();
  }

  @override
  Future<List<OrderEntity>> getFilteredOrders({
    String? paymentStatus,
    String? paymentMethod,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      'paymentStatus': ?paymentStatus,
      'paymentMethod': ?paymentMethod,
    };
    try {
      final response = await _apiClient.get(
        ApiEndpoints.retailerOrders,
        queryParameters: queryParams,
      );
      final rawList = _extractOrdersList(response.data);
      if (rawList.isNotEmpty) {
        return rawList.map((json) {
          try { return _parseOrder(json); } catch (_) { return null; }
        }).whereType<OrderEntity>().toList();
      }
    } catch (_) {}
    final all = await getLiveOrders();
    return all.where((o) {
      if (paymentStatus != null && o.paymentStatus.toUpperCase() != paymentStatus.toUpperCase()) {
        return false;
      }
      if (paymentMethod != null && o.paymentMethod.toUpperCase() != paymentMethod.toUpperCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<RetailerPayoutModel> getRetailerPayouts({
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, dynamic>{
      if (from != null) 'from': from.toIso8601String().substring(0, 10),
      if (to != null) 'to': to.toIso8601String().substring(0, 10),
    };
    try {
      final response = await _apiClient.get(
        ApiEndpoints.retailerPayouts,
        queryParameters: queryParams,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return RetailerPayoutModel.fromJson(data);
      } else if (data is Map) {
        return RetailerPayoutModel.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}

    return const RetailerPayoutModel(
      totalSales: 0.0,
      platformFee: 0.0,
      netPayable: 0.0,
      codCollected: 0.0,
      onlineCollected: 0.0,
      payoutStatus: 'PENDING',
    );
  }

  @override
  Future<List<OrderEntity>> getOrderHistory() async {
    final response = await _apiClient.get(ApiEndpoints.retailerOrderHistory);
    final rawList = _extractOrdersList(response.data);
    return rawList.map((json) {
      try { return _parseOrder(json); } catch (_) { return null; }
    }).whereType<OrderEntity>().toList();
  }

  @override
  Future<OrderEntity> acceptOrder(String orderId) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.retailerAcceptOrder(orderId),
        data: {
          'status': 'ACCEPTED',
          'estimatedPrepTime': 15,
          'notes': 'Order accepted by store partner',
        },
      );
      final data = response.data;
      final orderMap = data is Map && data['data'] is Map ? data['data'] : data;
      return _parseOrder(orderMap, defaultStatus: OrderStatus.accepted, fallbackId: orderId);
    } on DioException catch (e) {
      final errData = e.response?.data;
      final msg = errData is Map
          ? (errData['message']?.toString() ?? errData['error']?['message']?.toString())
          : e.message;
      throw ServerException(message: msg ?? 'Failed to accept order', statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<OrderEntity> markPreparing(String orderId) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.retailerPreparingOrder(orderId),
        data: {
          'status': 'PREPARING',
        },
      );
      final data = response.data;
      final orderMap = data is Map && data['data'] is Map ? data['data'] : data;
      return _parseOrder(orderMap, defaultStatus: OrderStatus.preparing, fallbackId: orderId);
    } on DioException catch (e) {
      final errData = e.response?.data;
      final msg = errData is Map
          ? (errData['message']?.toString() ?? errData['error']?['message']?.toString())
          : e.message;
      throw ServerException(message: msg ?? 'Failed to mark order as preparing', statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<OrderEntity> markReady(String orderId) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.retailerReadyOrder(orderId),
        data: {
          'status': 'READY_FOR_PICKUP',
        },
      );
      final data = response.data;
      final orderMap = data is Map && data['data'] is Map ? data['data'] : data;
      return _parseOrder(orderMap, defaultStatus: OrderStatus.readyForPickup, fallbackId: orderId);
    } on DioException catch (e) {
      final errData = e.response?.data;
      final msg = errData is Map
          ? (errData['message']?.toString() ?? errData['error']?['message']?.toString())
          : e.message;
      throw ServerException(message: msg ?? 'Failed to mark order as ready', statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<OrderEntity> rejectOrder(String orderId, String reason) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.retailerRejectOrder(orderId),
        data: {
          'status': 'REJECTED',
          'reason': reason,
          'reasonCode': 'OUT_OF_STOCK',
        },
      );
      final data = response.data;
      final orderMap = data is Map && data['data'] is Map ? data['data'] : data;
      return _parseOrder(orderMap, defaultStatus: OrderStatus.rejected, rejectionReason: reason, fallbackId: orderId);
    } on DioException catch (e) {
      final errData = e.response?.data;
      final msg = errData is Map
          ? (errData['message']?.toString() ?? errData['error']?['message']?.toString())
          : e.message;
      throw ServerException(message: msg ?? 'Failed to reject order', statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<List<ProductEntity>> getCatalogItems() async {
    final response = await _apiClient.get(ApiEndpoints.retailerProducts);
    final data = response.data;
    if (data is Map) {
      final listData = data['data'] ?? data['products'] ?? data['items'];
      if (listData is List) {
        return listData
            .whereType<Map>()
            .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else if (listData is Map && listData['products'] is List) {
        return (listData['products'] as List)
            .whereType<Map>()
            .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else if (listData is Map && listData['items'] is List) {
        return (listData['items'] as List)
            .whereType<Map>()
            .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
    } else if (data is List) {
      return data
          .whereType<Map>()
          .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    return [];
  }

  @override
  Future<ProductEntity> addProduct(ProductEntity product) async {
    final normUnit = _normalizeUnit(product.unit);
    final validCat = _resolveMongoCategoryId(product.categoryId);
    final double validPrice = product.price > 0 ? product.price : 10.0;
    final double validMrp = (product.originalPrice != null && product.originalPrice! >= validPrice)
        ? product.originalPrice!
        : (validPrice + 10.0);
    final int qty = product.stock >= 0 ? product.stock : 0;

    final response = await _apiClient.post(
      ApiEndpoints.retailerProducts,
      data: {
        'name': product.name,
        'description': product.description.isNotEmpty
            ? product.description
            : 'Fresh essential item from partner catalog',
        'categoryId': validCat,
        'category': validCat,
        'price': validPrice,
        'discountPrice': validPrice,
        'mrp': validMrp,
        'unit': normUnit,
        'stockQty': qty,
        'quantity': qty,
        'stock': qty,
        if (RegExp(r'^[a-f0-9]{24}$').hasMatch(product.storeId)) 'storeId': product.storeId,
        if (RegExp(r'^[a-f0-9]{24}$').hasMatch(product.storeId)) 'retailerId': product.storeId,
        'imageUrl': product.imageUrl.isNotEmpty
            ? product.imageUrl
            : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
        'image': product.imageUrl.isNotEmpty
            ? product.imageUrl
            : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
        'images': [
          product.imageUrl.isNotEmpty
              ? product.imageUrl
              : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
        ],
        'preparationTime': 5,
        'isAvailable': product.isAvailable,
        if (product.hsnCode != null && product.hsnCode!.isNotEmpty) 'hsnCode': product.hsnCode,
        if (product.taxPercent != null) 'taxPercent': product.taxPercent,
      },
    );
    final data = response.data;
    Map itemMap = {};
    if (data is Map) {
      if (data['data'] is Map) {
        final d = data['data'] as Map;
        itemMap = d['product'] is Map ? d['product'] as Map : (d['item'] is Map ? d['item'] as Map : d);
      } else if (data['product'] is Map) {
        itemMap = data['product'] as Map;
      } else if (data['item'] is Map) {
        itemMap = data['item'] as Map;
      } else {
        itemMap = data;
      }
    }
    if (itemMap.isEmpty || (itemMap['_id'] == null && itemMap['id'] == null && itemMap['name'] == null)) {
      return product;
    }
    final parsed = ProductModel.fromJson(Map<String, dynamic>.from(itemMap));
    return (parsed.name.isNotEmpty && parsed.name != 'Essential Product')
        ? parsed.copyWith(
            imageUrl: (parsed.imageUrl.isNotEmpty && !parsed.imageUrl.contains('photo-1550583724-b2692b85b150'))
                ? parsed.imageUrl
                : product.imageUrl,
          )
        : product;
  }

  @override
  Future<ProductEntity> updateProduct(ProductEntity product) async {
    final normUnit = _normalizeUnit(product.unit);
    final validCat = _resolveMongoCategoryId(product.categoryId);
    final double validPrice = product.price > 0 ? product.price : 10.0;
    final double validMrp = (product.originalPrice != null && product.originalPrice! >= validPrice)
        ? product.originalPrice!
        : (validPrice + 10.0);
    final int qty = (product.isAvailable && product.stock > 0) ? product.stock : 0;
    final String statusStr = (product.isAvailable && qty > 0) ? 'ACTIVE' : 'OUT_OF_STOCK';
    final String stockStatusStr = (product.isAvailable && qty > 0) ? 'IN_STOCK' : 'OUT_OF_STOCK';
    final img = product.imageUrl.isNotEmpty
        ? product.imageUrl
        : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400';

    final payload = {
      'name': product.name,
      'description': product.description.isNotEmpty
          ? product.description
          : 'Fresh essential item from partner catalog',
      'categoryId': validCat,
      'category': validCat,
      'price': validPrice,
      'discountPrice': validPrice,
      'mrp': validMrp,
      'unit': normUnit,
      'stockQty': qty,
      'quantity': qty,
      'stock': qty,
      'status': statusStr,
      'stockStatus': stockStatusStr,
      'imageUrl': img,
      'image': img,
      'images': [img],
      'isAvailable': product.isAvailable && qty > 0,
      if (product.hsnCode != null && product.hsnCode!.isNotEmpty) 'hsnCode': product.hsnCode,
      if (product.taxPercent != null) 'taxPercent': product.taxPercent,
    };

    Response response;
    try {
      response = await _apiClient.put(
        ApiEndpoints.retailerProductById(product.id),
        data: payload,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        response = await _apiClient.patch(
          ApiEndpoints.retailerProductById(product.id),
          data: payload,
        );
      } else {
        rethrow;
      }
    }

    // Also sync dedicated stock endpoint to keep inventory status synchronized on backend
    try {
      await _apiClient.patch(
        ApiEndpoints.retailerProductStock(product.id),
        data: {
          'stock': qty,
          'stockQty': qty,
          'quantity': qty,
          'status': statusStr,
          'stockStatus': stockStatusStr,
          'isAvailable': product.isAvailable && qty > 0,
        },
      );
    } catch (_) {
      // Primary PUT succeeded, stock PATCH is best-effort sync
    }

    final data = response.data;
    Map itemMap = {};
    if (data is Map) {
      if (data['data'] is Map) {
        final d = data['data'] as Map;
        itemMap = d['product'] is Map ? d['product'] as Map : (d['item'] is Map ? d['item'] as Map : d);
      } else if (data['product'] is Map) {
        itemMap = data['product'] as Map;
      } else if (data['item'] is Map) {
        itemMap = data['item'] as Map;
      } else {
        itemMap = data;
      }
    }

    if (itemMap.isEmpty || (itemMap['_id'] == null && itemMap['id'] == null && itemMap['name'] == null)) {
      return product;
    }

    final parsed = ProductModel.fromJson(Map<String, dynamic>.from(itemMap));
    return parsed.copyWith(
      id: parsed.id.isNotEmpty ? parsed.id : product.id,
      imageUrl: (parsed.imageUrl.isNotEmpty && !parsed.imageUrl.contains('photo-1550583724-b2692b85b150'))
          ? parsed.imageUrl
          : product.imageUrl,
      storeId: parsed.storeId.isNotEmpty ? parsed.storeId : product.storeId,
    );
  }

  @override
  Future<bool> deleteProduct(String productId) async {
    final response = await _apiClient.delete(ApiEndpoints.retailerProductById(productId));
    final data = response.data;
    return data is Map && data['success'] == true;
  }

  @override
  Future<bool> toggleProductStock(String productId, bool isAvailable, {int? currentStock}) async {
    final int effectiveStock = isAvailable
        ? ((currentStock != null && currentStock > 0) ? currentStock : 10)
        : 0;
    final String statusStr = isAvailable ? 'ACTIVE' : 'OUT_OF_STOCK';
    final String stockStatusStr = isAvailable ? 'IN_STOCK' : 'OUT_OF_STOCK';

    // 1. Update product status & stockQty via PUT
    try {
      await _apiClient.put(
        ApiEndpoints.retailerProductById(productId),
        data: {
          'stock': effectiveStock,
          'stockQty': effectiveStock,
          'quantity': effectiveStock,
          'status': statusStr,
          'stockStatus': stockStatusStr,
          'isAvailable': isAvailable,
        },
      );
    } catch (_) {}

    // 2. Also call dedicated /products/:id/stock endpoint
    final response = await _apiClient.patch(
      ApiEndpoints.retailerProductStock(productId),
      data: {
        'stock': effectiveStock,
        'stockQty': effectiveStock,
        'quantity': effectiveStock,
        'status': statusStr,
        'stockStatus': stockStatusStr,
        'isAvailable': isAvailable,
      },
    );
    final data = response.data;
    return data is Map && (data['success'] == true || data['data'] != null || data['isAvailable'] == isAvailable);
  }

  @override
  Future<RetailerDashboardStatsEntity> getDashboardStats() async {
    final response = await _apiClient.get(ApiEndpoints.retailerDashboardStats);
    final data = response.data;
    final stats = data is Map && data['data'] is Map ? data['data'] : (data is Map ? data : {});

    return RetailerDashboardStatsEntity(
      todayEarnings: (stats['revenueToday'] as num?)?.toDouble() ??
          (stats['todayEarnings'] as num?)?.toDouble() ??
          (stats['revenue'] as num?)?.toDouble() ??
          0.0,
      totalOrders: (stats['ordersToday'] as num?)?.toInt() ??
          (stats['totalOrders'] as num?)?.toInt() ??
          0,
      pendingOrders: (stats['pendingOrders'] as num?)?.toInt() ?? 0,
      completedOrders: (stats['completedOrders'] as num?)?.toInt() ?? 0,
      commissionDeducted: (stats['commissionDeducted'] as num?)?.toDouble() ?? 0.0,
      netPayout: (stats['netPayout'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @visibleForTesting
  RetailerStoreProfileEntity parseStoreProfileForTesting(dynamic json) => _parseStoreProfile(json);

  RetailerStoreProfileEntity _parseStoreProfile(dynamic json) {
    if (json is! Map) {
      // FIX #3: Return empty profile instead of fake store_01 data
      // If the API returned non-Map data, returning fake data would hide the bug
      return const RetailerStoreProfileEntity(
        id: '',
        storeName: '',
        ownerName: '',
        email: '',
        phone: '',
        fssaiNumber: '',
        gstin: '',
        address: '',
        isOpen: false,
        isVerified: false,
        rating: 0.0,
      );
    }

    final storeObj = (json['retailer'] is Map)
        ? json['retailer'] as Map
        : ((json['store'] is Map) ? json['store'] as Map : json);

    String addressStr = 'Indiranagar, Bangalore';
    final addrSrc = json['address'] ?? storeObj['address'];
    if (addrSrc is Map) {
      final a = addrSrc;
      addressStr = [a['line1'], a['city'], a['postalCode'] ?? a['pincode']].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    } else if (addrSrc is String) {
      addressStr = addrSrc;
    }

    final sName = storeObj['shopName']?.toString() ??
        storeObj['storeName']?.toString() ??
        storeObj['name']?.toString() ??
        json['shopName']?.toString() ??
        json['storeName']?.toString() ??
        json['name']?.toString() ??
        'QuickMart Store';

    double? lat;
    double? lng;
    final locSrc = json['location'] ?? storeObj['location'];
    if (locSrc is Map) {
      final loc = locSrc;
      if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
        lng = ((loc['coordinates'] as List)[0] as num?)?.toDouble();
        lat = ((loc['coordinates'] as List)[1] as num?)?.toDouble();
      } else if (loc.containsKey('lat') && loc.containsKey('lng')) {
        lat = (loc['lat'] as num?)?.toDouble();
        lng = (loc['lng'] as num?)?.toDouble();
      }
    }

    final rawStatus = (storeObj['status'] ?? json['status'])?.toString().toUpperCase() ?? 'PENDING';
    String accountStatus;
    if (rawStatus == 'APPROVED' || rawStatus == 'REJECTED' || rawStatus == 'SUSPENDED' || rawStatus == 'PENDING') {
      accountStatus = rawStatus;
    } else if (rawStatus == 'OPEN' || rawStatus == 'CLOSED') {
      accountStatus = 'APPROVED';
    } else {
      accountStatus = (storeObj['isVerified'] == true || json['isVerified'] == true) ? 'APPROVED' : 'PENDING';
    }

    final dynamic rawZoneSource = storeObj['zoneId'] ?? json['zoneId'] ?? storeObj['zone'] ?? json['zone'];
    final String? zoneId = (rawZoneSource is Map
            ? (rawZoneSource['_id'] ?? rawZoneSource['id'])
            : rawZoneSource)
        ?.toString();
    final category = storeObj['category']?.toString() ?? json['category']?.toString() ?? 'General';

    String? shopPhoto = storeObj['shopPhotoUrl']?.toString() ??
        json['shopPhotoUrl']?.toString() ??
        storeObj['storePhotoUrl']?.toString() ??
        json['storePhotoUrl']?.toString() ??
        storeObj['imageUrl']?.toString() ??
        json['imageUrl']?.toString();

    if ((shopPhoto == null || shopPhoto.isEmpty) && json['documents'] is List) {
      for (final doc in json['documents']) {
        if (doc is Map) {
          final type = doc['type']?.toString().toUpperCase();
          final url = doc['url']?.toString();
          if ((type == 'SHOP_PHOTO' ||
                  type == 'STORE_PHOTO' ||
                  type == 'STOREFRONT' ||
                  type == 'STORE_FRONT') &&
              url != null &&
              url.isNotEmpty) {
            shopPhoto = url;
            break;
          }
        }
      }
    }

    return RetailerStoreProfileEntity(
      id: (storeObj['_id'] ?? storeObj['id'] ?? json['_id'] ?? json['id'] ?? '').toString(),
      storeName: sName,
      ownerName: storeObj['ownerName']?.toString() ?? json['ownerName']?.toString() ?? json['name']?.toString() ?? 'Partner',
      email: storeObj['email']?.toString() ?? json['email']?.toString() ?? json['contactEmail']?.toString() ?? '',
      phone: storeObj['phone']?.toString() ?? json['phone']?.toString() ?? json['contactPhone']?.toString() ?? '',
      fssaiNumber: (storeObj['fssaiLicense'] is Map
              ? storeObj['fssaiLicense']['number']?.toString()
              : (json['fssaiLicense'] is Map ? json['fssaiLicense']['number']?.toString() : null)) ??
          storeObj['fssaiNumber']?.toString() ??
          json['fssaiNumber']?.toString() ??
          '',
      gstin: storeObj['gstin']?.toString() ?? json['gstin']?.toString() ?? '',
      address: addressStr,
      isOpen: json['status']?.toString().toUpperCase() == 'OPEN' || json['isOpen'] == true,
      isVerified: (json['fssaiLicense'] is Map && json['fssaiLicense']['verified'] == true) ||
          json['isVerified'] == true ||
          accountStatus == 'APPROVED',
      rating: (json['rating'] is Map ? (json['rating']['average'] as num?)?.toDouble() : (json['rating'] as num?)?.toDouble()) ?? 4.8,
      latitude: lat,
      longitude: lng,
      status: accountStatus,
      zoneId: zoneId,
      category: category,
      shopPhotoUrl: shopPhoto,
    );
  }

  OrderEntity _parseOrder(dynamic json, {OrderStatus? defaultStatus, String? rejectionReason, String? fallbackId}) {
    if (json is! Map) {
      // Non-Map API response — do NOT inject phantom orders with fake OTPs or store names.
      // Callers should handle null/thrown orders by skipping them.
      throw const FormatException('Invalid order data: expected Map');
    }

    List<OrderItemEntity> orderItems = [];
    if (json['items'] is List) {
      orderItems = (json['items'] as List).map((i) {
        if (i is Map) {
          return OrderItemEntity(
            productId: i['productId']?.toString() ?? 'p1',
            nameSnapshot: i['name']?.toString() ?? 'Product',
            priceSnapshot: (i['price'] as num?)?.toDouble() ?? 50.0,
            unit: i['unit']?.toString() ?? '1 item',
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

    OrderStatus status = defaultStatus ?? OrderStatus.placed;
    if (json['status'] != null) {
      status = OrderEntity.parseStatus(json['status']);
    }

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

    final subtotal = (json['totalAmount'] as num?)?.toDouble() ??
        (json['subtotal'] as num?)?.toDouble() ??
        0.0;
    final deliveryFee = (json['deliveryFee'] as num?)?.toDouble() ??
        (json['delivery_fee'] as num?)?.toDouble() ??
        15.0;
    final platformFee = (json['platformFee'] as num?)?.toDouble() ??
        (json['service_fee'] as num?)?.toDouble() ??
        5.0;
    // Use backend-computed grandTotal first; fall back to summing the parts
    final grandTotal = (json['grandTotal'] as num?)?.toDouble() ??
        (json['total'] as num?)?.toDouble() ??
        (subtotal + deliveryFee + platformFee);

    final resolvedId = json['_id']?.toString() ??
        json['id']?.toString() ??
        fallbackId ??
        'order_${DateTime.now().millisecondsSinceEpoch}';

    return OrderEntity(
      id: resolvedId,
      orderNumber: json['orderNumber']?.toString() ?? 'QM-${DateTime.now().millisecondsSinceEpoch % 10000}',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Customer',
      customerPhone: json['customerPhone']?.toString() ?? '',
      deliveryAddress: json['deliveryAddress'] is Map
          ? (json['deliveryAddress']['line1']?.toString() ?? '')
          : (json['deliveryAddress']?.toString() ?? ''),
      storeId: json['storeId']?.toString() ?? '',
      storeName: json['storeName']?.toString() ?? '',
      storeAddress: json['storeAddress']?.toString() ?? '',
      items: orderItems,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: grandTotal,
      status: status,
      // Empty string when OTP absent — UI should show '—' not a guessable default
      deliveryOtp: json['deliveryOtp']?.toString() ?? '',
      paymentMethod: pMethod,
      paymentStatus: pStatus,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      rejectionReason: rejectionReason ?? json['rejectionReason']?.toString(),
    );
  }

  @override
  Future<bool> registerDeviceToken({
    required String fcmToken,
    required String platform,
    required String deviceId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.registerDeviceToken,
        data: {
          'fcmToken': fcmToken,
          'deviceToken': fcmToken,
          'platform': platform.isNotEmpty ? platform.toLowerCase() : 'android',
          'app': 'retailer',
          if (deviceId.isNotEmpty) 'deviceId': deviceId,
        },
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return true;
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      try {
        await _apiClient.post(
          ApiEndpoints.retailerRegisterDeviceLegacy,
          data: {
            'deviceToken': fcmToken,
            'fcmToken': fcmToken,
            'platform': platform,
            'deviceId': deviceId,
          },
        );
      } catch (_) {}
      return true; // Graceful fallback
    }
  }

  // Live Notifications Module (Backend Guide Section 3)
  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.notifications);
      final data = response.data;
      List rawList = [];
      if (data is Map) {
        final inner = data['data'];
        if (inner is List) {
          rawList = inner;
        } else if (inner is Map && inner['notifications'] is List) {
          rawList = inner['notifications'] as List;
        } else if (data['notifications'] is List) {
          rawList = data['notifications'] as List;
        }
      } else if (data is List) {
        rawList = data;
      }

      return rawList.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final model = RetailerNotificationModel.fromJson(map);
        return model.toMap();
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.notificationsUnreadCount);
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return (data['data']['count'] as num?)?.toInt() ??
            (data['data']['unreadCount'] as num?)?.toInt() ??
            0;
      }
      if (data is Map && data['unreadCount'] is num) {
        return (data['unreadCount'] as num).toInt();
      }
      if (data is Map && data['count'] is num) {
        return (data['count'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }

  @override
  Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response = await _apiClient.patch(ApiEndpoints.notificationRead(notificationId));
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> markAllNotificationsRead() async {
    try {
      final response = await _apiClient.patch(ApiEndpoints.notificationsReadAll);
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<RetailerSubscriptionEntity?> getSubscription() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.retailerSubscription);
      final data = response.data;
      if (data is Map && data['data'] != null) {
        final subData = data['data'];
        if (subData is Map) {
          return RetailerSubscriptionModel.fromJson(Map<String, dynamic>.from(subData));
        }
      } else if (data is Map && data['subscription'] != null) {
        final subData = data['subscription'];
        if (subData is Map) {
          return RetailerSubscriptionModel.fromJson(Map<String, dynamic>.from(subData));
        }
      }
      return RetailerSubscriptionEntity.freeTier;
    } catch (_) {
      // In accordance with specification: null or 404 falls back to free tier (0% commission)
      return RetailerSubscriptionEntity.freeTier;
    }
  }

  @override
  Future<RetailerEarningsSummaryEntity> getEarningsSummary() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.retailerEarningsSummary);
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return RetailerEarningsSummaryModel.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      } else if (data is Map) {
        return RetailerEarningsSummaryModel.fromJson(Map<String, dynamic>.from(data));
      }
      return const RetailerEarningsSummaryEntity();
    } catch (e) {
      throw ServerException(message: 'Failed to fetch earnings summary: $e');
    }
  }

  @override
  Future<List<RetailerEarningEntity>> getEarnings({String? status, int limit = 50, int skip = 0}) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.retailerEarnings(status: status, limit: limit, skip: skip));
      final data = response.data;
      List<dynamic> items = [];
      if (data is Map && data['data'] is List) {
        items = data['data'] as List;
      } else if (data is Map && data['earnings'] is List) {
        items = data['earnings'] as List;
      } else if (data is List) {
        items = data;
      }
      return items.map((e) => RetailerEarningModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      throw ServerException(message: 'Failed to fetch earnings: $e');
    }
  }

  @override
  Future<List<RetailerSettlementEntity>> getSettlements({int limit = 50, int skip = 0}) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.retailerSettlements(limit: limit, skip: skip));
      final data = response.data;
      List<dynamic> items = [];
      if (data is Map && data['data'] is List) {
        items = data['data'] as List;
      } else if (data is Map && data['settlements'] is List) {
        items = data['settlements'] as List;
      } else if (data is List) {
        items = data;
      }
      return items.map((e) => RetailerSettlementModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      throw ServerException(message: 'Failed to fetch settlements: $e');
    }
  }

  @override
  Future<RetailerBankAccountEntity> updateBankAccount(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.retailerBankAccount,
        data: data,
      );
      final resData = response.data;
      if (resData is Map && resData['bankAccount'] is Map) {
        return RetailerBankAccountModel.fromJson(Map<String, dynamic>.from(resData['bankAccount'] as Map));
      } else if (resData is Map && resData['data'] is Map) {
        final inner = resData['data'] as Map;
        if (inner['bankAccount'] is Map) {
          return RetailerBankAccountModel.fromJson(Map<String, dynamic>.from(inner['bankAccount'] as Map));
        }
        return RetailerBankAccountModel.fromJson(Map<String, dynamic>.from(inner));
      }
      return RetailerBankAccountModel.fromJson(data);
    } catch (e) {
      throw ServerException(message: 'Failed to update bank account: $e');
    }
  }

  @override
  Future<List<HeroBannerModel>> getHeroBanners({String app = 'RETAILER'}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.heroBanners,
        queryParameters: {'app': app},
      );
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((json) => HeroBannerModel.fromJson(Map<String, dynamic>.from(json)))
            .where((banner) => banner.isActive)
            .toList();
      }
    } catch (_) {
      return [];
    }
    return [];
  }
}

