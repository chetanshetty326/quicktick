import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/catalog_entities.dart';
import '../models/category_model.dart';
import '../models/customer_address_model.dart';
import '../models/customer_notification_model.dart';
import '../models/hero_banner_model.dart';
import '../models/coupon_model.dart';
import '../models/cart_pricing_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';

abstract class ICustomerRemoteDataSource {
  Future<List<StoreModel>> getNearbyStores({double? lat, double? lng, double? radius});
  Future<StoreModel> getStoreDetails(String storeId);
  Future<List<ProductModel>> getStoreProducts(String storeId, {int? limit});
  Future<List<ProductModel>> searchProducts(
    String query, {
    String? category,
    String? categoryId,
    String? retailerId,
    int? page,
    int? limit,
    double? lat,
    double? lng,
    String? foodType,
  });
  Future<({List<ProductModel> products, List<StoreModel> stores})> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
    double? lat,
    double? lng,
  });
  Future<List<CategoryModel>> getCategories();
  Future<CategoryModel?> getCategoryDetails(String categoryId);
  Future<ProductModel?> getProductDetails(String productId);
  Future<List<ProductModel>> getRecommendations();
  Future<List<HeroBannerModel>> getHeroBanners({String app = 'CUSTOMER'});
  Future<List<CouponModel>> getAvailableCoupons({String? retailerId});
  Future<CouponValidationModel> validateCoupon({
    required String code,
    String? cartId,
    String? retailerId,
  });
  Future<CartPricingModel> getCartPricing({
    String? couponCode,
    double tip = 0.0,
    String? zoneId,
    double? lat,
    double? lng,
  });
  Future<CartPricingModel?> addCartItem({required String productId, required int quantity});
  Future<void> removeCartItem(String productId);
  Future<void> clearBackendCart();
  Future<Map<String, dynamic>> validateCart(List<Map<String, dynamic>> items);
  Future<List<CustomerAddressModel>> getAddresses();
  Future<CustomerAddressModel> addAddress(CustomerAddressModel address);
  Future<CustomerAddressModel> updateAddress(String addressId, CustomerAddressModel address);
  Future<bool> deleteAddress(String addressId);
  Future<bool> setDefaultAddress(String addressId);
  Future<List<ProductModel>> getWishlist();
  Future<bool> addToWishlist(String productId);
  Future<bool> removeFromWishlist(String productId);
  Future<CustomerZoneEntity> checkLocation({required double lat, required double lng});
  Future<List<Map<String, dynamic>>> getNotifications();
  Future<int> getUnreadNotificationCount();
  Future<bool> markNotificationRead(String notificationId);
  Future<bool> markAllNotificationsRead();
  Future<bool> registerDeviceToken({required String fcmToken, required String platform, String? deviceId});
}

class CustomerRemoteDataSourceImpl implements ICustomerRemoteDataSource {
  final ApiClient _apiClient;

  CustomerRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<StoreModel>> getNearbyStores({double? lat, double? lng, double? radius}) async {
    // Require real coordinates — no hardcoded fallback to prevent showing wrong-city stores
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) return [];

    final queryParams = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'radius': radius ?? 50,
    };

    final response = await _apiClient.get(
      ApiEndpoints.retailersNearby,
      queryParameters: queryParams,
    );

    final data = response.data;
    if (data is Map && data['data'] is List) {
      final stores = (data['data'] as List)
          .map((json) => StoreModel.fromJson(
                Map<String, dynamic>.from(json),
                userLat: lat,
                userLng: lng,
              ))
          .toList();
      // Sort: closest stores first so Express stores appear at top of list
      stores.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return stores;
    }
    return [];
  }

  @override
  Future<StoreModel> getStoreDetails(String storeId) async {
    final response = await _apiClient.get(ApiEndpoints.retailerById(storeId));
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return StoreModel.fromJson(Map<String, dynamic>.from(data['data']));
    }
    throw Exception('Invalid store profile response');
  }

  @override
  Future<List<ProductModel>> getStoreProducts(String storeId, {int? limit}) async {
    final response = await _apiClient.get(
      ApiEndpoints.products,
      queryParameters: {
        'retailerId': storeId,
        'limit': limit ?? 50,
      },
    );
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    return [];
  }

  @override
  Future<({List<ProductModel> products, List<StoreModel> stores})> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
    double? lat,
    double? lng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return (products: <ProductModel>[], stores: <StoreModel>[]);
    }

    try {
      final List<ProductModel> products = [];
      final List<StoreModel> matchingStores = [];

      // 1. Concurrently search products and nearby retailers
      final results = await Future.wait([
        _apiClient.get(
          ApiEndpoints.productsSearch,
          queryParameters: {
            'q': cleanQuery,
            if (lat != null && lat != 0.0) 'lat': lat,
            if (lng != null && lng != 0.0) 'lng': lng,
          },
        ).catchError((_) => Response(requestOptions: RequestOptions())),
        getNearbyStores(lat: lat, lng: lng).catchError((_) => <StoreModel>[]),
      ]);

      // Parse direct product matches
      final prodRes = results[0] as Response;
      final data = prodRes.data;
      if (data is Map && data['data'] is List) {
        products.addAll(
          (data['data'] as List)
              .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json))),
        );
      }

      // If no direct product matches from /products/search, try /products?search=...
      if (products.isEmpty) {
        try {
          final broadRes = await _apiClient.get(
            ApiEndpoints.products,
            queryParameters: {
              'search': cleanQuery,
              'limit': limit,
              'page': page,
            },
          );
          final bData = broadRes.data;
          if (bData is Map && bData['data'] is List) {
            products.addAll(
              (bData['data'] as List)
                  .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json)))
                  .where((p) => !_isTestOrDummyProduct(p)),
            );
          }
        } catch (_) {}
      }

      // 2. Filter matching stores by name, category, or address
      final allStores = results[1] as List<StoreModel>;
      final qLower = cleanQuery.toLowerCase();
      for (final s in allStores) {
        if (s.name.toLowerCase().contains(qLower) ||
            s.category.toLowerCase().contains(qLower) ||
            s.address.toLowerCase().contains(qLower)) {
          matchingStores.add(s);
        }
      }

      // C-3 Fix: Fetch products for up to 3 matching stores in parallel.
      // Previously executed sequentially (3× round-trip latency).
      if (matchingStores.isNotEmpty) {
        final existingProdIds = products.map((p) => p.id).toSet();
        final storesToFetch = matchingStores.take(3).toList();
        final storeProductLists = await Future.wait(
          storesToFetch.map((store) =>
              getStoreProducts(store.id).catchError((_) => <ProductModel>[])),
        );
        for (final storeProds in storeProductLists) {
          for (final sp in storeProds) {
            if (!existingProdIds.contains(sp.id)) {
              products.add(sp);
              existingProdIds.add(sp.id);
            }
          }
        }
      }

      return (products: products, stores: matchingStores);
    } catch (_) {
      return (products: <ProductModel>[], stores: <StoreModel>[]);
    }
  }

  @override
  Future<List<ProductModel>> searchProducts(
    String query, {
    String? category,
    String? categoryId,
    String? retailerId,
    int? page,
    int? limit,
    double? lat,
    double? lng,
    String? foodType,
  }) async {
    final params = <String, dynamic>{};
    if (query.trim().isNotEmpty) {
      params['search'] = query.trim();
    }
    final effectiveCat = (categoryId != null && categoryId.isNotEmpty && categoryId != 'cat_all')
        ? categoryId
        : (category != null && category.isNotEmpty && category != 'cat_all' ? category : null);
    if (effectiveCat != null) {
      if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(effectiveCat)) {
        params['categoryId'] = effectiveCat;
      } else {
        params['category'] = effectiveCat;
      }
    }
    if (foodType != null && foodType.isNotEmpty) {
      params['foodType'] = foodType;
    }
    if (retailerId != null && retailerId.isNotEmpty) {
      params['retailerId'] = retailerId;
    }
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    // Note: Do NOT append lat/lng to GET /products. In MongoDB, products do not
    // store root-level coordinates (stores do). Passing lat/lng triggers an empty
    // geospatial query on /products that returns 0 items.

    final response = await _apiClient.get(
      ApiEndpoints.products,
      queryParameters: params.isNotEmpty ? params : null,
    );

    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json)))
          .where((p) => !_isTestOrDummyProduct(p))
          .toList();
    } else if (data is Map && data['data'] is Map) {
      final p = ProductModel.fromJson(Map<String, dynamic>.from(data['data']));
      return _isTestOrDummyProduct(p) ? <ProductModel>[] : [p];
    }
    return [];
  }

  static bool _isTestOrDummyProduct(ProductModel p) {
    final name = p.name.toLowerCase().trim();
    final desc = p.description.toLowerCase().trim();
    if (name.contains('test product') ||
        name.contains('customer test') ||
        name.contains('retailer test') ||
        name.contains('fallback product') ||
        name.contains('flow product') ||
        name == 'aa product') {
      return true;
    }
    if (desc.contains('flow test product')) {
      return true;
    }
    return false;
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.categories);
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((json) => CategoryModel.fromJson(Map<String, dynamic>.from(json)))
            .where((c) {
              final n = c.name.toLowerCase().trim();
              return !n.contains('test category') && !n.contains('flow category');
            })
            .toList();
      } else if (data is List) {
        return data
            .map((json) => CategoryModel.fromJson(Map<String, dynamic>.from(json)))
            .where((c) {
              final n = c.name.toLowerCase().trim();
              return !n.contains('test category') && !n.contains('flow category');
            })
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<CategoryModel?> getCategoryDetails(String categoryId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.categoryById(categoryId));
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return CategoryModel.fromJson(Map<String, dynamic>.from(data['data']));
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<ProductModel?> getProductDetails(String productId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.productById(productId));
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return ProductModel.fromJson(Map<String, dynamic>.from(data['data']));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
    return null;
  }

  @override
  Future<List<ProductModel>> getRecommendations() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.productsFeatured);
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else if (data is Map && data['data'] is Map) {
        return [ProductModel.fromJson(Map<String, dynamic>.from(data['data']))];
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<HeroBannerModel>> getHeroBanners({String app = 'CUSTOMER'}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.heroBanners,
        queryParameters: {
          'app': app,
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ),
      );
      final data = response.data;
      List rawList = [];
      if (data is Map) {
        if (data['data'] is List) {
          rawList = data['data'] as List;
        } else if (data['banners'] is List) {
          rawList = data['banners'] as List;
        } else if (data['heroBanners'] is List) {
          rawList = data['heroBanners'] as List;
        } else if (data['items'] is List) {
          rawList = data['items'] as List;
        }
      } else if (data is List) {
        rawList = data;
      }

      return rawList
          .whereType<Map>()
          .map((json) => HeroBannerModel.fromJson(Map<String, dynamic>.from(json)))
          .where((banner) {
            // Must be strictly active
            if (!banner.isActive) return false;
            // Must belong to Customer app or universal
            final bApp = banner.app?.trim().toUpperCase();
            if (bApp == null || bApp.isEmpty || bApp == 'CUSTOMER' || bApp == 'ALL') {
              return true;
            }
            return false;
          })
          .toList();
    } catch (e) {
      if (e is DioException || e is Failure) {
        rethrow;
      }
      return [];
    }
  }

  @override
  Future<List<CouponModel>> getAvailableCoupons({String? retailerId}) async {
    try {
      final queryParams = <String, dynamic>{
        if (retailerId != null && retailerId.isNotEmpty) 'retailerId': retailerId,
      };
      final response = await _apiClient.get(
        ApiEndpoints.coupons,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final data = response.data;
      if (data is Map && data['data'] is List) {
        final list = (data['data'] as List)
            .map((json) => CouponModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        if (list.isNotEmpty) return list;
      }

      // Resilient fallback: If no retailerId was specified or returned empty,
      // auto-discover coupons from the nearest active store
      if (retailerId == null || retailerId.isEmpty) {
        try {
          final storesRes = await _apiClient.get(ApiEndpoints.retailersNearby);
          final storesData = storesRes.data;
          if (storesData is Map && storesData['data'] is List && (storesData['data'] as List).isNotEmpty) {
            final firstStore = (storesData['data'] as List).first;
            final firstStoreId = firstStore['id']?.toString() ?? firstStore['_id']?.toString();
            if (firstStoreId != null && firstStoreId.isNotEmpty) {
              final fallbackRes = await _apiClient.get(
                ApiEndpoints.coupons,
                queryParameters: {'retailerId': firstStoreId},
              );
              final fbData = fallbackRes.data;
              if (fbData is Map && fbData['data'] is List) {
                return (fbData['data'] as List)
                    .map((json) => CouponModel.fromJson(Map<String, dynamic>.from(json)))
                    .toList();
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  @override
  Future<CouponValidationModel> validateCoupon({
    required String code,
    String? cartId,
    String? retailerId,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    try {
      final response = await _apiClient.post(
        ApiEndpoints.couponsValidate,
        data: {
          'code': cleanCode,
          if (cartId != null && cartId.isNotEmpty) 'cartId': cartId,
          if (retailerId != null && retailerId.isNotEmpty) 'retailerId': retailerId,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return CouponValidationModel.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
          defaultCode: cleanCode,
        );
      }
      return CouponValidationModel.fromError(
        code: cleanCode,
        errorMessage: 'Invalid coupon format',
      );
    } on DioException catch (dioErr) {
      // If 401 Unauthorized (e.g. guest user not logged in), fallback to public GET /coupons/validate/:code
      if (dioErr.response?.statusCode == 401) {
        try {
          final getResponse = await _apiClient.get(
            ApiEndpoints.couponByCode(cleanCode),
          );
          final getData = getResponse.data;
          if (getData is Map) {
            final payload = getData['data'] is Map
                ? Map<String, dynamic>.from(getData['data'] as Map)
                : Map<String, dynamic>.from(getData);
            return CouponValidationModel.fromJson(payload, defaultCode: cleanCode);
          }
        } catch (_) {
          // If fallback fails as well, proceed to standard error parsing below
        }
      }

      final resData = dioErr.response?.data;
      String errMsg = 'Failed to validate coupon';
      String? errCode;
      if (resData is Map) {
        if (resData['error'] is Map) {
          errMsg = resData['error']['message']?.toString() ?? errMsg;
          errCode = resData['error']['code']?.toString();
        } else if (resData['message'] != null) {
          errMsg = resData['message'].toString();
        }
      }
      return CouponValidationModel.fromError(
        code: cleanCode,
        errorMessage: errMsg,
        errorCode: errCode,
      );
    } catch (e) {
      return CouponValidationModel.fromError(
        code: cleanCode,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<CartPricingModel> getCartPricing({
    String? couponCode,
    double tip = 0.0,
    String? zoneId,
    double? lat,
    double? lng,
  }) async {
    final queryParams = <String, dynamic>{
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      if (tip > 0) 'tip': tip,
      if (zoneId != null && zoneId.isNotEmpty) 'zoneId': zoneId,
      if (lat != null && lat != 0.0) 'lat': lat,
      if (lng != null && lng != 0.0) 'lng': lng,
    };
    final response = await _apiClient.get(
      ApiEndpoints.cart,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return CartPricingModel.fromJson(data);
    } else if (data is Map) {
      return CartPricingModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Invalid cart response format');
  }

  @override
  Future<CartPricingModel?> addCartItem({required String productId, required int quantity}) async {
    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(productId)) {
      return null;
    }
    try {
      final response = await _apiClient.post(
        ApiEndpoints.cartItems,
        data: {
          'productId': productId,
          'quantity': quantity,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return CartPricingModel.fromJson(Map<String, dynamic>.from(data['data']));
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> removeCartItem(String productId) async {
    if (!RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(productId)) {
      return;
    }
    try {
      await _apiClient.delete(ApiEndpoints.cartItemById(productId));
    } catch (_) {}
  }

  @override
  Future<void> clearBackendCart() async {
    try {
      await _apiClient.delete(ApiEndpoints.cart);
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> validateCart(List<Map<String, dynamic>> items) async {
    final response = await _apiClient.post(
      ApiEndpoints.customerValidateCart,
      data: {'items': items},
    );
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {'valid': true};
  }

  @override
  Future<List<CustomerAddressModel>> getAddresses() async {
    final response = await _apiClient.get(ApiEndpoints.customerAddresses);
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((json) => CustomerAddressModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    return [];
  }

  @override
  Future<CustomerAddressModel> addAddress(CustomerAddressModel address) async {
    final response = await _apiClient.post(
      ApiEndpoints.customerAddAddress,
      data: address.toCreateJson(),
    );
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return CustomerAddressModel.fromJson(Map<String, dynamic>.from(data['data']));
    }
    return address;
  }

  @override
  Future<CustomerAddressModel> updateAddress(String addressId, CustomerAddressModel address) async {
    final response = await _apiClient.patch(
      ApiEndpoints.customerAddressById(addressId),
      data: address.toCreateJson(),
    );
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return CustomerAddressModel.fromJson(Map<String, dynamic>.from(data['data']));
    }
    return address;
  }

  @override
  Future<bool> deleteAddress(String addressId) async {
    final response = await _apiClient.delete(ApiEndpoints.customerAddressById(addressId));
    final data = response.data;
    return data is Map && data['success'] == true;
  }

  @override
  Future<bool> setDefaultAddress(String addressId) async {
    final response = await _apiClient.post(ApiEndpoints.customerSetDefaultAddress(addressId));
    final data = response.data;
    return data is Map && data['success'] == true;
  }

  @override
  Future<List<ProductModel>> getWishlist() async {
    final response = await _apiClient.get(ApiEndpoints.customerWishlist);
    final data = response.data;
    if (data is Map && data['data'] is List) {
      final List<ProductModel> results = [];
      for (final item in data['data'] as List) {
        if (item is Map && item['productId'] is Map) {
          results.add(ProductModel.fromJson(Map<String, dynamic>.from(item['productId'])));
        } else if (item is Map && item.isNotEmpty) {
          results.add(ProductModel.fromJson(Map<String, dynamic>.from(item)));
        }
        // Malformed/non-Map items are silently skipped — do NOT inject
        // fake products with demo storeIds like 'store_01'.
      }
      return results;
    }
    return [];
  }

  @override
  Future<bool> addToWishlist(String productId) async {
    final response = await _apiClient.post(
      ApiEndpoints.customerAddToWishlist,
      data: {'productId': productId},
    );
    final data = response.data;
    return data is Map && data['success'] == true;
  }

  @override
  Future<bool> removeFromWishlist(String productId) async {
    final response = await _apiClient.delete(ApiEndpoints.customerRemoveWishlist(productId));
    final data = response.data;
    return data is Map && data['success'] == true;
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.customerNotifications);
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
        final model = CustomerNotificationModel.fromJson(map);
        return model.toMap();
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> markNotificationRead(String notificationId) async {
    final response = await _apiClient.patch(ApiEndpoints.customerNotificationRead(notificationId));
    final data = response.data;
    return data is Map && data['success'] == true;
  }

  @override
  Future<bool> markAllNotificationsRead() async {
    final response = await _apiClient.patch(ApiEndpoints.customerNotificationsReadAll);
    final data = response.data;
    return data is Map && data['success'] == true;
  }

  ({double? deliveryFee, double? platformFee, double? freeDeliveryThreshold, double? minOrderAmount})
      _extractZonePricing(Map source) {
    final settings = source['settings'] is Map ? source['settings'] as Map : const {};
    final pricing = source['pricing'] is Map
        ? source['pricing'] as Map
        : (settings['pricing'] is Map ? settings['pricing'] as Map : const {});

    final rawDelivery = pricing['deliveryFee'] ?? source['deliveryFee'] ?? source['deliveryCharge'];
    final rawPlatform = pricing['platformFee'] ?? source['platformFee'];
    final rawFreeThreshold = pricing['freeDeliveryThreshold'] ?? source['freeDeliveryThreshold'];
    final rawMinOrder = pricing['minOrderAmount'] ?? source['minOrderAmount'];

    return (
      deliveryFee: (rawDelivery as num?)?.toDouble(),
      platformFee: (rawPlatform as num?)?.toDouble(),
      freeDeliveryThreshold: (rawFreeThreshold as num?)?.toDouble(),
      minOrderAmount: (rawMinOrder as num?)?.toDouble(),
    );
  }

  @override
  Future<CustomerZoneEntity> checkLocation({required double lat, required double lng}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.zonesCheckLocation,
        queryParameters: {'lng': lng, 'lat': lat},
      );
      final data = response.data;
      if (data is Map) {
        final inner = data['data'] is Map ? data['data'] as Map : data;
        final inZone = inner['inZone'] == true || inner['insideZone'] == true;
        final zoneMap = inner['zone'] is Map ? inner['zone'] as Map : null;
        final zoneId = inner['zoneId']?.toString() ??
            (zoneMap != null ? zoneMap['_id']?.toString() ?? zoneMap['id']?.toString() : null);
        final zoneName = inner['zoneName']?.toString() ??
            (zoneMap != null ? zoneMap['name']?.toString() : null);
        final message = data['message']?.toString() ?? inner['message']?.toString();

        var resolvedPricing = _extractZonePricing(zoneMap ?? inner);
        if (resolvedPricing.deliveryFee == null &&
            resolvedPricing.platformFee == null &&
            resolvedPricing.minOrderAmount == null) {
          resolvedPricing = _extractZonePricing(inner);
        }

        // If /zones/check-location did not embed zone pricing, resolve it from /zones cleanly
        if (inZone &&
            zoneId != null &&
            zoneId.isNotEmpty &&
            resolvedPricing.deliveryFee == null &&
            resolvedPricing.platformFee == null) {
          try {
            final zonesRes = await _apiClient.get(ApiEndpoints.zones);
            final zData = zonesRes.data;
            final zInner = zData is Map && zData['data'] is Map ? zData['data'] as Map : zData;
            final items = zInner is Map && zInner['items'] is List
                ? zInner['items'] as List
                : (zInner is List ? zInner : const []);
            for (final item in items) {
              if (item is Map) {
                final itemId = (item['_id'] ?? item['id'])?.toString();
                if (itemId == zoneId) {
                  resolvedPricing = _extractZonePricing(item);
                  break;
                }
              }
            }
          } catch (_) {
            // Non-fatal: continue with zone membership even if /zones lookup fails
          }
        }

        return CustomerZoneEntity(
          inZone: inZone,
          zoneId: zoneId,
          zoneName: zoneName,
          message: message,
          deliveryFee: resolvedPricing.deliveryFee,
          platformFee: resolvedPricing.platformFee,
          freeDeliveryThreshold: resolvedPricing.freeDeliveryThreshold,
          minOrderAmount: resolvedPricing.minOrderAmount,
        );
      }
      return const CustomerZoneEntity(inZone: true);
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map) {
        final err = resData['error'] is Map ? resData['error'] as Map : resData;
        final msg = err['message']?.toString() ?? 'Location is outside the delivery zone';
        return CustomerZoneEntity(
          inZone: false,
          message: msg,
        );
      }
      return CustomerZoneEntity(
        inZone: false,
        message: e.message ?? 'Location is outside the delivery zone',
      );
    } catch (e) {
      return CustomerZoneEntity(inZone: false, message: e.toString());
    }
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.notificationsUnreadCount);
      final data = response.data;
      if (data is Map) {
        final inner = data['data'] is Map ? data['data'] as Map : data;
        final count = inner['count'] ?? inner['unreadCount'];
        if (count is num) return count.toInt();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<bool> registerDeviceToken({
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.registerDeviceToken,
        data: {
          'fcmToken': fcmToken,
          'deviceToken': fcmToken,
          'platform': platform.toLowerCase(),
          'app': 'customer',
          if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
        },
      );
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (_) {
      return true; // Graceful fallback
    }
  }
}
