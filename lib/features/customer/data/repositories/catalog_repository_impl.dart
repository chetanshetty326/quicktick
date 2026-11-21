import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/local_cache_service.dart';
import '../../domain/entities/catalog_entities.dart';
import '../../domain/entities/customer_address_entity.dart';
import '../../domain/entities/hero_banner_entity.dart';
import '../../domain/entities/coupon_entity.dart';
import '../../domain/entities/cart_pricing_entity.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/customer_remote_data_source.dart';
import '../models/customer_address_model.dart';
import '../models/product_model.dart';

class CatalogRepositoryImpl implements ICatalogRepository {
  final ICustomerRemoteDataSource _remoteDataSource;
  final ILocalCacheService _localCache;

  final StreamController<List<ProductEntity>> _productStream =
      StreamController<List<ProductEntity>>.broadcast();
  final StreamController<List<StoreEntity>> _storeStream =
      StreamController<List<StoreEntity>>.broadcast();

  final List<StoreEntity> _stores = [];
  final List<ProductEntity> _products = [];
  final List<CategoryEntity> _categories = [];
  final List<CustomerAddressEntity> _addresses = [];

  static const List<CategoryEntity> _defaultCategories = [
    CategoryEntity(id: 'cat_all', name: 'All Essentials', icon: '🏪', colorHex: '0xFF0F766E'),
    CategoryEntity(id: 'cat_dairy', name: 'Dairy & Bread', icon: '🥛', colorHex: '0xFF0284C7'),
    CategoryEntity(id: 'cat_veg', name: 'Fresh Vegetables', icon: '🥦', colorHex: '0xFF16A34A'),
    CategoryEntity(id: 'cat_fruits', name: 'Fresh Fruits', icon: '🍎', colorHex: '0xFFEA580C'),
    CategoryEntity(id: 'cat_snacks', name: 'Snacks & Munchies', icon: '🍿', colorHex: '0xFFD97706'),
    CategoryEntity(id: 'cat_beverages', name: 'Drinks & Juices', icon: '🧃', colorHex: '0xFF9333EA'),
  ];

  static const List<ProductEntity> _defaultProducts = [
    ProductEntity(
      id: 'prod_milk_1',
      storeId: 'store_default_1',
      storeName: 'Quick Mart Essentials',
      categoryId: 'cat_dairy',
      categoryName: 'Dairy & Bread',
      name: 'Fresh Cow Milk',
      description: 'Pasteurised toned milk, rich in calcium and vitamin D.',
      price: 32.0,
      originalPrice: 35.0,
      unit: '500 ml',
      stock: 50,
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&auto=format&fit=crop&q=60',
      rating: 4.8,
    ),
    ProductEntity(
      id: 'prod_bread_1',
      storeId: 'store_default_1',
      storeName: 'Quick Mart Essentials',
      categoryId: 'cat_dairy',
      categoryName: 'Dairy & Bread',
      name: 'Whole Wheat Bread',
      description: '100% whole wheat bread, freshly baked and soft.',
      price: 45.0,
      originalPrice: 50.0,
      unit: '400 g',
      stock: 30,
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&auto=format&fit=crop&q=60',
      rating: 4.6,
    ),
    ProductEntity(
      id: 'prod_banana_1',
      storeId: 'store_default_1',
      storeName: 'Quick Mart Essentials',
      categoryId: 'cat_fruits',
      categoryName: 'Fresh Fruits',
      name: 'Fresh Robust Bananas',
      description: 'Sweet and ripe bananas, naturally ripened.',
      price: 40.0,
      originalPrice: 48.0,
      unit: '1 kg',
      stock: 40,
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500&auto=format&fit=crop&q=60',
      rating: 4.7,
    ),
    ProductEntity(
      id: 'prod_apple_1',
      storeId: 'store_default_1',
      storeName: 'Quick Mart Essentials',
      categoryId: 'cat_fruits',
      categoryName: 'Fresh Fruits',
      name: 'Royal Gala Apples',
      description: 'Crisp and juicy sweet apples directly from orchards.',
      price: 160.0,
      originalPrice: 180.0,
      unit: '1 kg',
      stock: 25,
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500&auto=format&fit=crop&q=60',
      rating: 4.9,
    ),
    ProductEntity(
      id: 'prod_tomato_1',
      storeId: 'store_default_1',
      storeName: 'Quick Mart Essentials',
      categoryId: 'cat_veg',
      categoryName: 'Fresh Vegetables',
      name: 'Hybrid Tomatoes',
      description: 'Fresh farm-picked red firm tomatoes for daily cooking.',
      price: 28.0,
      originalPrice: 35.0,
      unit: '1 kg',
      stock: 60,
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1546470427-227c7369a9b2?w=500&auto=format&fit=crop&q=60',
      rating: 4.5,
    ),
    ProductEntity(
      id: 'prod_potato_1',
      storeId: 'store_default_1',
      storeName: 'Quick Mart Essentials',
      categoryId: 'cat_veg',
      categoryName: 'Fresh Vegetables',
      name: 'Fresh Potatoes',
      description: 'Selected earthy potatoes, perfect for curries and fries.',
      price: 30.0,
      originalPrice: 38.0,
      unit: '1 kg',
      stock: 75,
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=500&auto=format&fit=crop&q=60',
      rating: 4.6,
    ),
  ];

  static const List<StoreEntity> _defaultStores = [
    StoreEntity(
      id: 'store_default_1',
      name: 'Quick Mart Essentials',
      category: 'Grocery & Essentials',
      address: 'Main Market, Local Zone',
      rating: 4.8,
      deliveryTime: '15-20 min',
      distanceKm: 0.8,
      isOpen: true,
      bannerUrl: '',
    ),
  ];

  void _ensureProductsFallback() {
    if (_products.isNotEmpty) return;
    try {
      final cached = _localCache.getCachedProducts();
      if (cached.isNotEmpty) {
        _products.addAll(cached.map((e) => ProductModel.fromJson(e)));
      }
    } catch (_) {}
    if (_products.isEmpty) {
      _products.addAll(_defaultProducts);
    }
  }

  void _ensureStoresFallback() {
    if (_stores.isNotEmpty) return;
    try {
      final cached = _localCache.getCachedStores();
      if (cached.isNotEmpty) {
        _stores.addAll(cached.map((s) => StoreEntity(
          id: s['id']?.toString() ?? 'store_cached',
          name: s['name']?.toString() ?? 'Quick Mart Essentials',
          category: 'Grocery & Essentials',
          address: 'Local Store',
          rating: 4.8,
          deliveryTime: '15-20 min',
          distanceKm: 0.8,
          isOpen: true,
          bannerUrl: '',
        )));
      }
    } catch (_) {}
    if (_stores.isEmpty) {
      _stores.addAll(_defaultStores);
    }
  }


  CatalogRepositoryImpl(this._localCache, this._remoteDataSource);

  void _emitStores() {
    _storeStream.add(List.unmodifiable(_stores));
    _localCache.cacheStores(_stores.map((s) => {'id': s.id, 'name': s.name}).toList());
  }

  void _emitProducts() {
    _productStream.add(List.unmodifiable(_products));
    _localCache.cacheProducts(_products.map((p) => p.toJson()).toList());
  }

  void _emit() {
    _emitProducts();
    _emitStores();
  }

  @override
  Stream<List<ProductEntity>> get productsStream => _productStream.stream;

  @override
  Stream<List<StoreEntity>> get storesStream => _storeStream.stream;

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async {
    try {
      final remoteCats = await _remoteDataSource.getCategories();
      final List<CategoryEntity> apiCats = [
        const CategoryEntity(id: 'cat_all', name: 'All Essentials', icon: '🏪', colorHex: '0xFF0F766E'),
      ];

      for (final cat in remoteCats) {
        if (!apiCats.any((c) => c.id == cat.id || c.name.toLowerCase() == cat.name.toLowerCase())) {
          apiCats.add(cat);
        }
      }

      if (apiCats.length <= 1) {
        apiCats.addAll(_defaultCategories.where((c) => c.id != 'cat_all'));
      }

      _categories.clear();
      _categories.addAll(apiCats);
      return Right(_categories);
    } catch (e) {
      if (_categories.isEmpty) _categories.addAll(_defaultCategories);
      return Right(_categories);
    }
  }

  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async {
    try {
      double? reqLat = lat;
      double? reqLng = lng;
      if (reqLat == null || reqLng == null || (reqLat == 0.0 && reqLng == 0.0)) {
        final cached = _localCache.getCachedActiveLocation();
        if (cached != null) {
          final cLat = (cached['lat'] as num?)?.toDouble();
          final cLng = (cached['lng'] as num?)?.toDouble();
          if (cLat != null && cLng != null && (cLat != 0.0 || cLng != 0.0)) {
            reqLat = cLat;
            reqLng = cLng;
          }
        }
      }
      final remoteStores = await _remoteDataSource.getNearbyStores(lat: reqLat, lng: reqLng);
      if (remoteStores.isNotEmpty || _stores.isEmpty) {
        _stores.clear();
        _stores.addAll(remoteStores);
        _emitStores();
      }
    } catch (e) {
      // API FAILED (network/server error) — keep last successful fetch or fallback
      _ensureStoresFallback();
    }
    if (_stores.isEmpty) {
      _ensureStoresFallback();
    }
    return Right(_stores);
  }

  @override
  Future<Either<Failure, StoreEntity>> getStoreDetails(String storeId) async {
    try {
      final remoteStore = await _remoteDataSource.getStoreDetails(storeId);
      return Right(remoteStore);
    } catch (e) {
      final local = _stores.firstWhere(
        (s) => s.id == storeId,
        orElse: () => StoreEntity(
          id: storeId,
          name: 'Store',
          category: 'Grocery',
          address: '',
          rating: 4.5,
          deliveryTime: '20 min',
          distanceKm: 1.0,
          isOpen: true,
          bannerUrl: '',
        ),
      );
      return Right(local);
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async {
    try {
      final remoteProducts = await _remoteDataSource.getStoreProducts(storeId);
      if (remoteProducts.isNotEmpty) {
        for (final p in remoteProducts) {
          final idx = _products.indexWhere((existing) => existing.id == p.id);
          if (idx == -1) {
            _products.add(p);
          } else {
            _products[idx] = p;
          }
        }
        return Right(remoteProducts);
      }
    } catch (_) {}
    final list = _products.where((p) => p.storeId == storeId).toList();
    return Right(list);
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> searchProducts(
    String query, {
    String? category,
    int? page,
    int? limit,
    double? lat,
    double? lng,
    String? foodType,
  }) async {
    try {
      final remoteProducts = await _remoteDataSource.searchProducts(
        query,
        category: category,
        page: page,
        limit: limit,
        lat: lat,
        lng: lng,
        foodType: foodType,
      );

      if (remoteProducts.isNotEmpty) {
        _products.clear();
        _products.addAll(remoteProducts);
      } else if (_products.isEmpty) {
        _ensureProductsFallback();
      }
      _emit();
      return Right(_filterProducts(query, category));
    } catch (e) {
      _ensureProductsFallback();
      _emit();
      return Right(_filterProducts(query, category));
    }
  }

  List<ProductEntity> _filterProducts(String query, String? category) {
    final q = query.toLowerCase().trim();
    return _products.where((p) {
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
      final matchesCat = category == null || category == 'cat_all' || p.categoryId == category;
      return matchesQuery && matchesCat;
    }).toList();
  }

  @override
  Future<Either<Failure, ({List<ProductEntity> products, List<StoreEntity> stores})>> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
    double? lat,
    double? lng,
  }) async {
    try {
      final res = await _remoteDataSource.searchCatalog(
        query: query,
        page: page,
        limit: limit,
        lat: lat,
        lng: lng,
      );
      if (res.products.isNotEmpty) {
        return Right((products: res.products, stores: res.stores));
      }
      _ensureProductsFallback();
      _ensureStoresFallback();
      return Right((products: _filterProducts(query, null), stores: _stores));
    } catch (e) {
      _ensureProductsFallback();
      _ensureStoresFallback();
      final q = query.toLowerCase().trim();
      final matchedProducts = _filterProducts(q, null);
      final matchedStores = _stores.where((s) {
        return q.isEmpty || s.name.toLowerCase().contains(q);
      }).toList();
      return Right((products: matchedProducts, stores: matchedStores));
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getRecommendations() async {
    try {
      final recs = await _remoteDataSource.getRecommendations();
      if (recs.isNotEmpty) return Right(recs);
      return Right(_products.take(6).toList());
    } catch (e) {
      return Right(_products.take(6).toList());
    }
  }

  @override
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String app = 'CUSTOMER'}) async {
    try {
      final banners = await _remoteDataSource.getHeroBanners(app: app);
      return Right(banners);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch hero banners: $e'));
    }
  }

  @override
  Future<Either<Failure, List<CouponEntity>>> getAvailableCoupons({String? retailerId}) async {
    try {
      final coupons = await _remoteDataSource.getAvailableCoupons(retailerId: retailerId);
      return Right(coupons);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch available coupons: $e'));
    }
  }

  @override
  Future<Either<Failure, CouponValidationEntity>> validateCoupon({
    required String code,
    String? cartId,
    String? retailerId,
  }) async {
    try {
      final validation = await _remoteDataSource.validateCoupon(
        code: code,
        cartId: cartId,
        retailerId: retailerId,
      );
      return Right(validation);
    } catch (e) {
      return Left(ServerFailure(message: 'Coupon validation failed: $e'));
    }
  }

  @override
  Future<Either<Failure, CartPricingEntity>> getCartPricing({
    String? couponCode,
    double tip = 0.0,
    String? zoneId,
    double? lat,
    double? lng,
  }) async {
    try {
      final pricing = await _remoteDataSource.getCartPricing(
        couponCode: couponCode,
        tip: tip,
        zoneId: zoneId,
        lat: lat,
        lng: lng,
      );
      return Right(pricing);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch cart pricing: $e'));
    }
  }

  @override
  Future<Either<Failure, CartPricingEntity?>> addCartItem({required String productId, required int quantity}) async {
    try {
      final res = await _remoteDataSource.addCartItem(productId: productId, quantity: quantity);
      return Right(res);
    } catch (e) {
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, bool>> removeCartItem(String productId) async {
    try {
      await _remoteDataSource.removeCartItem(productId);
      return const Right(true);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, bool>> clearBackendCart() async {
    try {
      await _remoteDataSource.clearBackendCart();
      return const Right(true);
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> validateCart(List<Map<String, dynamic>> items) async {
    try {
      final result = await _remoteDataSource.validateCart(items);
      return Right(result);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: 'Cart validation failed: $e'));
    }
  }

  @override
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async {
    try {
      final remoteAddrs = await _remoteDataSource.getAddresses();
      _addresses.clear();
      if (remoteAddrs.isNotEmpty) {
        _addresses.addAll(remoteAddrs);
      }
      return Right(_addresses);
    } catch (e) {
      return Right(_addresses);
    }
  }

  @override
  Future<Either<Failure, CustomerAddressEntity>> addAddress(CustomerAddressEntity address) async {
    try {
      final model = CustomerAddressModel(
        id: address.id,
        label: address.label,
        line1: address.line1,
        line2: address.line2,
        landmark: address.landmark,
        city: address.city,
        state: address.state,
        pincode: address.pincode,
        lat: address.lat,
        lng: address.lng,
        isDefault: address.isDefault,
        contactName: address.contactName,
        contactPhone: address.contactPhone,
        deliveryInstructions: address.deliveryInstructions,
      );
      final created = await _remoteDataSource.addAddress(model);
      _addresses.add(created);
      return Right(created);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to save address: $e'));
    }
  }

  @override
  Future<Either<Failure, CustomerAddressEntity>> updateAddress(
      String addressId, CustomerAddressEntity address) async {
    try {
      final model = CustomerAddressModel(
        id: addressId,
        label: address.label,
        line1: address.line1,
        line2: address.line2,
        landmark: address.landmark,
        city: address.city,
        state: address.state,
        pincode: address.pincode,
        lat: address.lat,
        lng: address.lng,
        isDefault: address.isDefault,
        contactName: address.contactName,
        contactPhone: address.contactPhone,
        deliveryInstructions: address.deliveryInstructions,
      );
      final updated = await _remoteDataSource.updateAddress(addressId, model);
      final idx = _addresses.indexWhere((a) => a.id == addressId);
      if (idx != -1) {
        _addresses[idx] = updated;
      } else {
        _addresses.add(updated);
      }
      return Right(updated);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update address: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteAddress(String addressId) async {
    try {
      final ok = await _remoteDataSource.deleteAddress(addressId);
      if (ok) _addresses.removeWhere((a) => a.id == addressId);
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete address: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> setDefaultAddress(String addressId) async {
    try {
      final ok = await _remoteDataSource.setDefaultAddress(addressId);
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to set default address: $e'));
    }
  }

  // Customer Wishlist
  @override
  Future<Either<Failure, List<ProductEntity>>> getWishlist() async {
    try {
      final items = await _remoteDataSource.getWishlist();
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch wishlist: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> addToWishlist(String productId) async {
    try {
      final ok = await _remoteDataSource.addToWishlist(productId);
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to add to wishlist: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> removeFromWishlist(String productId) async {
    try {
      final ok = await _remoteDataSource.removeFromWishlist(productId);
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to remove from wishlist: $e'));
    }
  }

  // Zone / Location Validation
  @override
  Future<Either<Failure, CustomerZoneEntity>> checkLocation({required double lat, required double lng}) async {
    try {
      final res = await _remoteDataSource.checkLocation(lat: lat, lng: lng);
      return Right(res);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to validate location: $e'));
    }
  }

  // Customer Notifications
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async {
    try {
      final notifs = await _remoteDataSource.getNotifications();
      return Right(notifs);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch notifications: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async {
    try {
      final count = await _remoteDataSource.getUnreadNotificationCount();
      return Right(count);
    } catch (e) {
      return const Right(0);
    }
  }

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async {
    try {
      final ok = await _remoteDataSource.markNotificationRead(notificationId);
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark notification read: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async {
    try {
      final ok = await _remoteDataSource.markAllNotificationsRead();
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark all notifications read: $e'));
    }
  }

  // Retailer controls
  @override
  Future<Either<Failure, ProductEntity>> toggleProductStock(String productId, bool isAvailable) async {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx == -1) return const Left(ValidationFailure(message: 'Product not found'));

    final updated = _products[idx].copyWith(isAvailable: isAvailable);
    _products[idx] = updated;
    _emit();
    return Right(updated);
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProductPrice(String productId, double newPrice) async {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx == -1) return const Left(ValidationFailure(message: 'Product not found'));

    final updated = _products[idx].copyWith(price: newPrice);
    _products[idx] = updated;
    _emit();
    return Right(updated);
  }

  @override
  Future<Either<Failure, StoreEntity>> toggleStoreOpenStatus(String storeId, bool isOpen) async {
    final idx = _stores.indexWhere((s) => s.id == storeId);
    if (idx == -1) return const Left(ValidationFailure(message: 'Store not found'));

    final updated = _stores[idx].copyWith(isOpen: isOpen);
    _stores[idx] = updated;
    _emit();
    return Right(updated);
  }

  @override
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product) async {
    _products.insert(0, product);
    _emit();
    return Right(product);
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async {
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx == -1) return const Left(ValidationFailure(message: 'Product not found'));

    _products[idx] = product;
    _emit();
    return Right(product);
  }

  @override
  Future<Either<Failure, String>> deleteProduct(String productId) async {
    final idx = _products.indexWhere((p) => p.id == productId);
    if (idx == -1) return const Left(ValidationFailure(message: 'Product not found'));

    _products.removeAt(idx);
    _emit();
    return Right(productId);
  }

  @override
  Future<Either<Failure, bool>> registerDeviceToken({
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) async {
    try {
      final ok = await _remoteDataSource.registerDeviceToken(
        fcmToken: fcmToken,
        platform: platform,
        deviceId: deviceId,
      );
      return Right(ok);
    } catch (e) {
      return const Right(true); // Graceful fallback
    }
  }

  @override
  List<String> getSearchHistory() => _localCache.getSearchHistory();

  @override
  Future<void> saveSearchHistory(List<String> queries) =>
      _localCache.saveSearchHistory(queries);
}
