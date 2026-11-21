import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/retailer/data/datasources/retailer_remote_data_source.dart';
import 'package:quicklink/features/retailer/data/models/retailer_registration_models.dart';
import 'package:quicklink/features/retailer/data/repositories/retailer_repository_impl.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_entities.dart';

class InMemoryLocalCacheService implements ILocalCacheService {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _cartItems = [];
  Map<String, dynamic>? _user;
  bool _darkMode = false;
  String? _devRole;

  @override
  Future<void> init() async {}

  @override
  List<Map<String, dynamic>> getCartItems() => List.from(_cartItems);

  @override
  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    _cartItems = List.from(items);
  }

  @override
  Future<void> clearCart() async {
    _cartItems.clear();
  }

  @override
  Future<void> cacheActiveOrders(List<Map<String, dynamic>> orders) async {
    _orders = List.from(orders);
  }

  @override
  List<Map<String, dynamic>> getCachedOrders() => List.from(_orders);

  @override
  List<Map<String, dynamic>> getCachedActiveOrders() => List.from(_orders);

  @override
  Future<List<Map<String, dynamic>>> reloadAndGetCachedOrders() async => List.from(_orders);

  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {
    _products = List.from(products);
  }

  @override
  List<Map<String, dynamic>> getCachedProducts() => List.from(_products);

  @override
  Future<void> cacheStores(List<Map<String, dynamic>> stores) async {
    _stores = List.from(stores);
  }

  @override
  List<Map<String, dynamic>> getCachedStores() => List.from(_stores);

  @override
  Future<void> cacheAddresses(List<Map<String, dynamic>> addresses) async {
    _addresses = List.from(addresses);
  }

  @override
  List<Map<String, dynamic>> getCachedAddresses() => List.from(_addresses);

  @override
  Future<void> cacheUser(Map<String, dynamic> user) async {
    _user = Map.from(user);
  }

  @override
  Map<String, dynamic>? getCachedUser() => _user != null ? Map.from(_user!) : null;

  @override
  bool isDarkMode() => _darkMode;

  @override
  Future<void> setDarkMode(bool isDark) async {
    _darkMode = isDark;
  }

  @override
  String? getDevRole() => _devRole;

  @override
  Future<void> setDevRole(String role) async {
    _devRole = role;
  }

  @override
  Future<void> cacheActiveLocation({
    required double lat,
    required double lng,
    required String address,
    String? zoneId,
    String? zoneName,
    bool? inZone,
  }) async {}

  @override
  Map<String, dynamic>? getCachedActiveLocation() => null;

  @override
  Future<void> clearAll() async {
    _orders.clear();
    _products.clear();
    _stores.clear();
    _addresses.clear();
    _cartItems.clear();
    _user = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRetailerRemoteDataSource implements IRetailerRemoteDataSource {
  List<ProductEntity> remoteProducts = [];
  bool shouldThrow = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<ProductEntity>> getCatalogItems() async {
    if (shouldThrow) throw Exception('Network timeout');
    return List.from(remoteProducts);
  }

  @override
  Future<ProductEntity> addProduct(ProductEntity product) async {
    if (shouldThrow) throw Exception('Server error');
    remoteProducts.add(product);
    return product;
  }

  @override
  Future<ProductEntity> updateProduct(ProductEntity product) async {
    if (shouldThrow) throw Exception('Server error');
    final idx = remoteProducts.indexWhere((p) => p.id == product.id);
    if (idx >= 0) remoteProducts[idx] = product;
    return product;
  }

  @override
  Future<bool> deleteProduct(String productId) async {
    if (shouldThrow) throw Exception('Server error');
    remoteProducts.removeWhere((p) => p.id == productId);
    return true;
  }

  @override
  Future<bool> toggleProductStock(String productId, bool isAvailable) async {
    if (shouldThrow) throw Exception('Server error');
    final idx = remoteProducts.indexWhere((p) => p.id == productId);
    if (idx >= 0) {
      final p = remoteProducts[idx];
      remoteProducts[idx] = ProductEntity(
        id: p.id,
        storeId: p.storeId,
        categoryId: p.categoryId,
        name: p.name,
        description: p.description,
        price: p.price,
        originalPrice: p.originalPrice,
        unit: p.unit,
        stock: isAvailable ? 25 : 0,
        isAvailable: isAvailable,
        imageUrl: p.imageUrl,
      );
    }
    return true;
  }

  @override
  Future<RetailerStoreProfileEntity> registerStore(Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<RetailerStoreProfileEntity> updateStoreProfile(Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<RetailerStoreProfileEntity> getStoreProfile() async => throw UnimplementedError();

  @override
  Future<bool> toggleStoreStatus(bool isOpen) async => true;

  @override
  Future<List<OrderEntity>> getLiveOrders() async => [];

  @override
  Future<List<OrderEntity>> getOrderHistory() async => [];

  @override
  Future<OrderEntity> acceptOrder(String orderId) async => throw UnimplementedError();

  @override
  Future<OrderEntity> markPreparing(String orderId) async => throw UnimplementedError();

  @override
  Future<OrderEntity> markReady(String orderId) async => throw UnimplementedError();

  @override
  Future<OrderEntity> rejectOrder(String orderId, String reason) async => throw UnimplementedError();

  @override
  Future<RetailerDashboardStatsEntity> getDashboardStats() async => throw UnimplementedError();

  @override
  Future<bool> registerDeviceToken({required String fcmToken, required String platform, required String deviceId}) async => true;

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async => [];

  @override
  Future<int> getUnreadNotificationCount() async => 0;

  @override
  Future<bool> markNotificationRead(String notificationId) async => true;

  @override
  Future<bool> markAllNotificationsRead() async => true;

  @override
  Future<({bool available, String message})> checkStoreName(String name) async =>
      (available: true, message: 'Store name is available');

  @override
  Future<RetailerCheckRegisteredModel> checkRetailerRegistration() async =>
      const RetailerCheckRegisteredModel(registered: true, status: 'APPROVED');

  @override
  Future<RetailerRejectionModel> getRejectionReason() async =>
      const RetailerRejectionModel(status: 'REJECTED', remarks: '', rejectedDocuments: []);

  @override
  Future<List<OrderEntity>> getFilteredOrders({String? paymentStatus, String? paymentMethod, int page = 1, int limit = 20}) async => [];

  @override
  Future<RetailerPayoutModel> getRetailerPayouts({DateTime? from, DateTime? to}) async => const RetailerPayoutModel(
        totalSales: 0.0,
        platformFee: 0.0,
        netPayable: 0.0,
        codCollected: 0.0,
        onlineCollected: 0.0,
        payoutStatus: 'PENDING',
      );

  @override
  Future<FileUploadModel> uploadFile({required String filePath, String? folder}) async =>
      const FileUploadModel(url: 'https://cdn.example.com/doc.pdf', publicId: 'doc1', format: 'pdf', bytes: 1024);

  @override
  Future<RetailerSubscriptionEntity?> getSubscription() async => RetailerSubscriptionEntity.freeTier;
}

void main() {
  group('Retailer Inventory Stock Persistence Tests', () {
    late InMemoryLocalCacheService cacheService;
    late FakeRetailerRemoteDataSource remoteDataSource;

    setUp(() {
      cacheService = InMemoryLocalCacheService();
      remoteDataSource = FakeRetailerRemoteDataSource();
    });

    test('added product is cached and survives app restart / repository recreation', () async {
      // 1. App session 1: Retailer adds a new item to inventory
      final repo1 = RetailerRepositoryImpl(remoteDataSource, cacheService);

      const newProduct = ProductEntity(
        id: 'prod_test_101',
        storeId: 'store_indiranagar_01',
        categoryId: 'cat_snacks',
        name: 'Organic Cashew Nuts',
        description: 'Fresh roasted cashew nuts.',
        price: 249.0,
        originalPrice: 299.0,
        unit: '200g',
        stock: 45,
        isAvailable: true,
        imageUrl: 'https://example.com/cashew.png',
      );

      final addResult = await repo1.addProduct(newProduct);
      expect(addResult.isRight(), true);

      // Verify that the local cache received the product
      final cachedJson = cacheService.getCachedProducts();
      expect(cachedJson.length, 1);
      expect(cachedJson.first['id'], 'prod_test_101');
      expect(cachedJson.first['name'], 'Organic Cashew Nuts');
      expect(cachedJson.first['price'], 249.0);

      // 2. Simulate closing the app and restarting:
      // A new repository instance is constructed with the persisted cacheService
      final repo2 = RetailerRepositoryImpl(remoteDataSource, cacheService);

      // When the app reopens, getCatalogItems is invoked
      final getResult = await repo2.getCatalogItems();
      expect(getResult.isRight(), true);

      final products = getResult.getOrElse(() => []);
      expect(products.length, 1);
      expect(products.first.id, 'prod_test_101');
      expect(products.first.name, 'Organic Cashew Nuts');
      expect(products.first.price, 249.0);
      expect(products.first.stock, 45);
    });

    test('locally added item is preserved even if remote API fails or times out on restart', () async {
      final repo1 = RetailerRepositoryImpl(remoteDataSource, cacheService);

      const newProduct = ProductEntity(
        id: 'prod_test_offline',
        storeId: 'store_01',
        categoryId: 'cat_dairy',
        name: 'Artisan Sourdough Loaf',
        description: 'Locally baked fresh bread',
        price: 120.0,
        originalPrice: 150.0,
        unit: '1 loaf',
        stock: 15,
        isAvailable: true,
        imageUrl: '',
      );

      await repo1.addProduct(newProduct);

      // Simulate network going down / backend offline
      remoteDataSource.shouldThrow = true;

      // App restart
      final repo2 = RetailerRepositoryImpl(remoteDataSource, cacheService);
      final getResult = await repo2.getCatalogItems();

      expect(getResult.isRight(), true);
      final products = getResult.getOrElse(() => []);
      expect(products.length, 1);
      expect(products.first.id, 'prod_test_offline');
      expect(products.first.name, 'Artisan Sourdough Loaf');
    });

    test('remote seed items and locally added items are merged without wiping local items', () async {
      final repo1 = RetailerRepositoryImpl(remoteDataSource, cacheService);

      const localProduct = ProductEntity(
        id: 'prod_local_unique',
        storeId: 'store_01',
        categoryId: 'cat_fruits',
        name: 'Alphonso Mango Box',
        description: 'Sweet seasonal mangoes',
        price: 799.0,
        originalPrice: 999.0,
        unit: '1 box (12 pcs)',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      await repo1.addProduct(localProduct);

      // Remote backend has its own catalog products
      remoteDataSource.remoteProducts = [
        const ProductEntity(
          id: 'prod_remote_01',
          storeId: 'store_01',
          categoryId: 'cat_dairy',
          name: 'Amul Butter 100g',
          description: 'Salted table butter',
          price: 56.0,
          originalPrice: 60.0,
          unit: '100g',
          stock: 50,
          isAvailable: true,
          imageUrl: '',
        ),
      ];

      // App restart
      final repo2 = RetailerRepositoryImpl(remoteDataSource, cacheService);
      final getResult = await repo2.getCatalogItems();

      expect(getResult.isRight(), true);
      final products = getResult.getOrElse(() => []);
      expect(products.length, 2);
      expect(products.any((p) => p.id == 'prod_local_unique'), true);
      expect(products.any((p) => p.id == 'prod_remote_01'), true);
    });

    test('toggling stock status and deleting product updates cache appropriately', () async {
      final repo = RetailerRepositoryImpl(remoteDataSource, cacheService);

      const product = ProductEntity(
        id: 'prod_stock_test',
        storeId: 'store_01',
        categoryId: 'cat_veg',
        name: 'Fresh Spinach',
        description: 'Organic bunch',
        price: 30.0,
        originalPrice: 35.0,
        unit: '1 bunch',
        stock: 20,
        isAvailable: true,
        imageUrl: '',
      );

      await repo.addProduct(product);

      // Toggle stock to out of stock
      await repo.toggleProductStock('prod_stock_test', false);
      var cached = cacheService.getCachedProducts();
      expect(cached.first['isAvailable'], false);
      expect(cached.first['stock'], 0);

      // Delete product
      await repo.deleteProduct('prod_stock_test');
      cached = cacheService.getCachedProducts();
      expect(cached.isEmpty, true);
    });
  });
}
