import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/services/push_notification_service.dart';
import 'package:quicklink/core/services/websocket_service.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/customer/domain/entities/cart_pricing_entity.dart';
import 'package:quicklink/features/customer/domain/entities/coupon_entity.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/customer/presentation/widgets/customer_address_sheet.dart';
import 'package:quicklink/features/customer/presentation/widgets/customer_notifications_sheet.dart';
import 'package:quicklink/features/customer/presentation/widgets/customer_profile_edit_sheet.dart';
import 'package:quicklink/features/customer/presentation/widgets/customer_filter_sort_sheet.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/customer/domain/entities/hero_banner_entity.dart';
import 'package:quicklink/features/customer/data/models/hero_banner_model.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:dartz/dartz.dart';

class MockCatalogRepository implements ICatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<ProductEntity> mockProducts = [];
  List<CustomerAddressEntity> mockAddresses = [];
  List<Map<String, dynamic>> mockNotifications = [];
  List<HeroBannerEntity> mockHeroBanners = [];
  List<String> mockSearchHistory = [];
  CustomerZoneEntity mockZone = const CustomerZoneEntity(inZone: true);

  @override
  List<String> getSearchHistory() => List<String>.from(mockSearchHistory);

  @override
  Future<void> saveSearchHistory(List<String> queries) async {
    mockSearchHistory = List<String>.from(queries);
  }

  @override
  Future<Either<Failure, CustomerZoneEntity>> checkLocation({
    required double lat,
    required double lng,
  }) async =>
      Right(mockZone);

  @override
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String app = 'CUSTOMER'}) async {
    return Right(mockHeroBanners);
  }

  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();

  @override
  Stream<List<StoreEntity>> get storesStream => const Stream.empty();

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async => const Right([]);

  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async => const Right([]);

  @override
  Future<Either<Failure, StoreEntity>> getStoreDetails(String storeId) async =>
      const Left(ServerFailure(message: 'Not implemented'));

  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async => Right(mockProducts);

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
    return Right(mockProducts.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList());
  }

  @override
  Future<Either<Failure, ({List<ProductEntity> products, List<StoreEntity> stores})>> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
    double? lat,
    double? lng,
  }) async {
    return Right((
      products: mockProducts.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList(),
      stores: const [],
    ));
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getRecommendations() async => const Right([]);

  @override
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async => Right(mockAddresses);

  @override
  Future<Either<Failure, CustomerAddressEntity>> addAddress(CustomerAddressEntity address) async {
    mockAddresses.add(address);
    return Right(address);
  }

  @override
  Future<Either<Failure, CustomerAddressEntity>> updateAddress(String id, CustomerAddressEntity address) async =>
      Right(address);

  @override
  Future<Either<Failure, bool>> deleteAddress(String id) async {
    mockAddresses.removeWhere((a) => a.id == id);
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> setDefaultAddress(String id) async => const Right(true);

  @override
  Future<Either<Failure, List<ProductEntity>>> getWishlist() async => const Right([]);
  @override
  Future<Either<Failure, bool>> addToWishlist(String productId) async => const Right(true);
  @override
  Future<Either<Failure, bool>> removeFromWishlist(String productId) async => const Right(true);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async => Right(mockNotifications);

  @override
  Future<Either<Failure, bool>> markNotificationRead(String id) async => const Right(true);

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async => const Right(true);

  @override
  Future<Either<Failure, bool>> registerDeviceToken({required String fcmToken, required String platform, String? deviceId}) async =>
      const Right(true);

  @override
  Future<Either<Failure, Map<String, dynamic>>> validateCart(List<Map<String, dynamic>> items) async =>
      const Right({'valid': true});

  @override
  Future<Either<Failure, ProductEntity>> toggleProductStock(String productId, bool isAvailable) async =>
      const Left(ServerFailure(message: 'Not implemented'));

  @override
  Future<Either<Failure, ProductEntity>> updateProductPrice(String productId, double newPrice) async =>
      const Left(ServerFailure(message: 'Not implemented'));

  @override
  Future<Either<Failure, StoreEntity>> toggleStoreOpenStatus(String storeId, bool isOpen) async =>
      const Left(ServerFailure(message: 'Not implemented'));

  @override
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product) async => Right(product);

  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async => Right(product);

  @override
  Future<Either<Failure, String>> deleteProduct(String productId) async => Right(productId);

  @override
  Future<Either<Failure, CartPricingEntity?>> addCartItem({required String productId, required int quantity}) async =>
      const Right(null);

  @override
  Future<Either<Failure, bool>> removeCartItem(String productId) async => const Right(true);

  @override
  Future<Either<Failure, bool>> clearBackendCart() async => const Right(true);

  @override
  Future<Either<Failure, CartPricingEntity>> getCartPricing({
    String? couponCode,
    double tip = 0.0,
    String? zoneId,
    double? lat,
    double? lng,
  }) async =>
      const Left(ServerFailure(message: 'Not implemented'));

  @override
  Future<Either<Failure, List<CouponEntity>>> getAvailableCoupons({String? retailerId}) async => const Right([]);
}

class MockOrderRepository implements IOrderRepository {
  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async => const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocalCacheService implements ILocalCacheService {
  @override
  String getAppLanguage() => 'en';

  @override
  Future<void> setAppLanguage(String langCode) async {}

  @override
  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {}

  @override
  List<Map<String, dynamic>> getCartItems() => [];

  @override
  Future<void> clearCart() async {}

  @override
  Future<void> cacheActiveLocation({
    required double lat,
    required double lng,
    required String address,
    String? zoneId,
    String? zoneName,
    bool inZone = true,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSecureStorageService implements ISecureStorageService {
  final Map<String, String?> _store = {};

  @override
  Future<void> saveUserData({
    required String userId,
    required String role,
    required String name,
    required String phone,
    String? email,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    _store['userId'] = userId;
    _store['name'] = name;
    _store['phone'] = phone;
    if (email != null) _store['email'] = email;
  }

  @override
  Future<Map<String, String?>> getUserData() async => _store;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockWebSocketService implements IWebSocketService {
  final orderController = StreamController<Map<String, dynamic>>.broadcast();
  final notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final bannerController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get orderStatusStream => orderController.stream;

  @override
  Stream<Map<String, dynamic>> get locationStream => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get riderLocationStream => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get notificationStream => notificationController.stream;

  @override
  Stream<Map<String, dynamic>> get criticalAlertStream => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get bannerUpdateStream => bannerController.stream;

  @override
  Stream<bool> get connectionStateStream => const Stream.empty();

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  void disconnect() {}

  @override
  void subscribeOrder(String orderId) {}

  @override
  void unsubscribeOrder(String orderId) {}

  @override
  void emitRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    int? etaMins,
  }) {}

  @override
  void emitOrderStatus({
    required String orderId,
    required String status,
  }) {}

  @override
  void dispose() {
    orderController.close();
    notificationController.close();
    bannerController.close();
  }
}

class MockPushNotificationService implements IPushNotificationService {
  final controller = StreamController<PushNotificationPayload>.broadcast();
  PushNotificationPayload? pendingNotification;

  @override
  Stream<PushNotificationPayload> get onNotificationReceived => controller.stream;

  @override
  PushNotificationPayload? consumePendingNotification() {
    final pending = pendingNotification;
    pendingNotification = null;
    return pending;
  }

  @override
  Future<void> initialize({UserRole? role}) async {}

  @override
  Future<String?> getDeviceToken() async => 'fcm_live_test_token';

  @override
  Future<bool> registerDeviceWithBackend({
    required String fcmToken,
    required UserRole role,
    String? deviceId,
  }) async =>
      true;

  @override
  Future<bool> unregisterDeviceWithBackend({required UserRole role}) async => true;

  @override
  void showInAppBanner(BuildContext context, PushNotificationPayload payload, {VoidCallback? onTap}) {}

  @override
  void simulateIncomingPush(PushNotificationPayload payload) {
    controller.add(payload);
  }

  @override
  Future<void> showOngoingDeliveryNotification({
    required String title,
    required String body,
    String? subText,
  }) async {}

  @override
  Future<void> cancelOngoingDeliveryNotification() async {}

  @override
  void dispose() {
    controller.close();
  }
}

void main() {
  group('Customer SRS Complete UI & State Features', () {
    late MockCatalogRepository catalogRepo;
    late MockOrderRepository orderRepo;
    late MockLocalCacheService localCache;
    late CustomerBloc customerBloc;

    setUp(() {
      catalogRepo = MockCatalogRepository();
      orderRepo = MockOrderRepository();
      localCache = MockLocalCacheService();

      catalogRepo.mockProducts = [
        const ProductEntity(
          id: 'p1',
          storeId: 's1',
          categoryId: 'cat_groceries',
          name: 'Organic Farm Milk',
          description: 'Fresh cow milk',
          price: 35.0,
          originalPrice: 40.0,
          unit: '500ml',
          stock: 10,
          isAvailable: true,
          imageUrl: 'https://img.com/milk.jpg',
          rating: 4.8,
        ),
        const ProductEntity(
          id: 'p2',
          storeId: 's1',
          categoryId: 'cat_groceries',
          name: 'Whole Wheat Bread',
          description: 'Brown bread loaf',
          price: 50.0,
          unit: '400g',
          stock: 0,
          isAvailable: false,
          imageUrl: 'https://img.com/bread.jpg',
          rating: 4.2,
        ),
        const ProductEntity(
          id: 'p3',
          storeId: 's1',
          categoryId: 'cat_fruits',
          name: 'Fresh Fuji Apples',
          description: 'Sweet apples',
          price: 180.0,
          originalPrice: 220.0,
          unit: '1 kg',
          stock: 25,
          isAvailable: true,
          imageUrl: 'https://img.com/apples.jpg',
          rating: 4.9,
        ),
      ];

      customerBloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
      );
    });

    tearDown(() {
      customerBloc.close();
    });

    test('Sorting by Price Low to High orders products correctly', () {
      customerBloc.add(CustomerProductsStreamUpdated(catalogRepo.mockProducts));
      customerBloc.add(const ApplyProductFiltersEvent(sortOption: ProductSortOption.priceLowToHigh));

      expectLater(
        customerBloc.stream,
        emitsThrough(
          predicate<CustomerState>((s) {
            return s.filteredProducts.isNotEmpty &&
                s.filteredProducts.first.name == 'Organic Farm Milk' &&
                s.filteredProducts.last.name == 'Fresh Fuji Apples';
          }),
        ),
      );
    });

    test('Filtering by In-Stock Only excludes out of stock products', () {
      customerBloc.add(CustomerProductsStreamUpdated(catalogRepo.mockProducts));
      customerBloc.add(const ApplyProductFiltersEvent(inStockOnly: true));

      expectLater(
        customerBloc.stream,
        emitsThrough(
          predicate<CustomerState>((s) {
            return s.filteredProducts.length == 2 &&
                !s.filteredProducts.any((p) => p.name == 'Whole Wheat Bread');
          }),
        ),
      );
    });

    test('Filtering by Deals Only includes discounted items', () {
      customerBloc.add(CustomerProductsStreamUpdated(catalogRepo.mockProducts));
      customerBloc.add(const ApplyProductFiltersEvent(dealsOnly: true));

      expectLater(
        customerBloc.stream,
        emitsThrough(
          predicate<CustomerState>((s) {
            return s.filteredProducts.length == 2 &&
                s.filteredProducts.every((p) => p.originalPrice != null && p.originalPrice! > p.price);
          }),
        ),
      );
    });

    test('Address Addition and Selection works seamlessly in state', () async {
      const newAddr = CustomerAddressEntity(
        id: 'addr_101',
        label: 'HOME',
        line1: 'Flat 402, Sunshine Heights',
        city: 'Udupi',
        state: 'Karnataka',
        pincode: '576101',
        lat: 13.34,
        lng: 74.74,
        isDefault: true,
      );

      customerBloc.add(const AddAddressEvent(newAddr));

      await expectLater(
        customerBloc.stream,
        emitsThrough(
          predicate<CustomerState>((s) {
            return s.savedAddresses.length == 1 &&
                s.selectedAddress.contains('Flat 402, Sunshine Heights');
          }),
        ),
      );
    });

    test('Cart price calculation immediately updates when adding items and applies free delivery above threshold', () async {
      final p1 = catalogRepo.mockProducts[0]; // Organic Farm Milk: 35.0
      final p3 = catalogRepo.mockProducts[2]; // Fresh Fuji Apples: 180.0

      customerBloc.add(AddToCartEvent(p1));
      await expectLater(
        customerBloc.stream,
        emitsThrough(
          predicate<CustomerState>((s) {
            // Subtotal: 35.0. Under 199 -> delivery fee 15.0, platform fee 5.0 -> grandTotal = 55.0
            return s.cartItems.length == 1 &&
                s.cartSubtotal == 35.0 &&
                s.deliveryFee == 15.0 &&
                s.platformFee == 5.0 &&
                s.cartGrandTotal == 55.0;
          }),
        ),
      );

      // Now add 2nd item (Apples: 180.0). Subtotal = 215.0 (>= 199 -> Free delivery 0.0)
      customerBloc.add(AddToCartEvent(p3));
      await expectLater(
        customerBloc.stream,
        emitsThrough(
          predicate<CustomerState>((s) {
            // Subtotal: 215.0. Above 199 -> delivery fee 0.0, platform fee 5.0 -> grandTotal = 220.0
            return s.cartItems.length == 2 &&
                s.cartSubtotal == 215.0 &&
                s.deliveryFee == 0.0 &&
                s.platformFee == 5.0 &&
                s.cartGrandTotal == 220.0;
          }),
        ),
      );
    });

    test('Profile update via AuthBloc updates user state and storage', () async {
      final secureStorage = MockSecureStorageService();
      final authBloc = AuthBloc(secureStorage);

      const initialUser = UserEntity(
        id: 'user_01',
        name: 'Old Name',
        phone: '+91 9876543210',
        role: UserRole.customer,
      );

      authBloc.emit(const AuthenticatedState(initialUser));

      authBloc.add(const UpdateProfileEvent(
        name: 'Chetan Shetty (Updated)',
        email: 'chetan@quicklink.io',
      ));

      await expectLater(
        authBloc.stream,
        emitsThrough(
          predicate<AuthState>((s) {
            if (s is AuthenticatedState) {
              return s.user.name == 'Chetan Shetty (Updated)' &&
                  s.user.email == 'chetan@quicklink.io';
            }
            return false;
          }),
        ),
      );

      authBloc.close();
    });
  });

  group('Customer UI Sheets Responsive Widget Rendering Tests', () {
    testWidgets('CustomerAddressSheet renders address UI and fields', (tester) async {
      final catalogRepo = MockCatalogRepository();
      final orderRepo = MockOrderRepository();
      final localCache = MockLocalCacheService();
      final bloc = CustomerBloc(catalogRepo: catalogRepo, orderRepo: orderRepo, localCache: localCache);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: const CustomerAddressSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Select Delivery Address'), findsOneWidget);
      expect(find.text('Add New Delivery Address'), findsOneWidget);

      await tester.tap(find.text('Add New Delivery Address'));
      await tester.pumpAndSettle();

      expect(find.text('Add Delivery Address'), findsOneWidget);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('WORK'), findsOneWidget);
      expect(find.text('OTHER'), findsOneWidget);

      bloc.close();
    });

    testWidgets('CustomerNotificationsSheet renders empty and populated views', (tester) async {
      final catalogRepo = MockCatalogRepository();
      final orderRepo = MockOrderRepository();
      final localCache = MockLocalCacheService();
      final bloc = CustomerBloc(catalogRepo: catalogRepo, orderRepo: orderRepo, localCache: localCache);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: const CustomerNotificationsSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All Caught Up!'), findsOneWidget);

      bloc.close();
    });

    testWidgets('CustomerFilterSortSheet renders sorting and filter options', (tester) async {
      final catalogRepo = MockCatalogRepository();
      final orderRepo = MockOrderRepository();
      final localCache = MockLocalCacheService();
      final bloc = CustomerBloc(catalogRepo: catalogRepo, orderRepo: orderRepo, localCache: localCache);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: bloc,
              child: const CustomerFilterSortSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Sort & Filters'), findsOneWidget);
      expect(find.text('SORT BY'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('FILTER PRODUCTS'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);

      bloc.close();
    });

    testWidgets('CustomerProfileEditSheet renders editable inputs', (tester) async {
      final secureStorage = MockSecureStorageService();
      final authBloc = AuthBloc(secureStorage);

      const user = UserEntity(
        id: 'user_01',
        name: 'Chetan Shetty',
        phone: '+91 9876543210',
        email: 'chetan@example.com',
        role: UserRole.customer,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: authBloc,
              child: const CustomerProfileEditSheet(user: user),
            ),
          ),
        ),
      );

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Chetan Shetty'), findsOneWidget);
      expect(find.text('chetan@example.com'), findsOneWidget);
      expect(find.text('Save Profile Changes'), findsOneWidget);

      authBloc.close();
    });

    test('HeroBannerModel deserializes active/inactive variants and deepLinks cleanly', () {
      final jsonActiveBool = {
        '_id': 'b1',
        'title': 'Active Banner',
        'isActive': true,
        'ctaLink': '/category/cat_1',
      };
      final jsonInactiveBool = {
        '_id': 'b2',
        'title': 'Inactive Banner 1',
        'isActive': false,
      };
      final jsonInactiveString = {
        '_id': 'b3',
        'title': 'Inactive Banner 2',
        'isActive': 'false',
        'deepLink': '/search?q=milk',
      };
      final jsonInactiveStatus = {
        '_id': 'b4',
        'title': 'Inactive Banner 3',
        'status': 'INACTIVE',
      };
      final jsonInactiveZero = {
        '_id': 'b5',
        'title': 'Inactive Banner 4',
        'active': 0,
      };

      final m1 = HeroBannerModel.fromJson(jsonActiveBool);
      final m2 = HeroBannerModel.fromJson(jsonInactiveBool);
      final m3 = HeroBannerModel.fromJson(jsonInactiveString);
      final m4 = HeroBannerModel.fromJson(jsonInactiveStatus);
      final m5 = HeroBannerModel.fromJson(jsonInactiveZero);

      expect(m1.isActive, isTrue);
      expect(m1.ctaLink, '/category/cat_1');

      expect(m2.isActive, isFalse);
      expect(m3.isActive, isFalse);
      expect(m3.ctaLink, '/search?q=milk');
      expect(m4.isActive, isFalse);
      expect(m5.isActive, isFalse);
    });

    test('CustomerBloc updates banners immediately on add, delete, and active/inactive toggle', () async {
      final catalogRepo = MockCatalogRepository();
      final orderRepo = MockOrderRepository();
      final localCache = MockLocalCacheService();
      final secureStorage = MockSecureStorageService();

      const bannerA = HeroBannerEntity(
        id: 'banner_a',
        title: 'Monsoon Deal',
        order: 1,
        isActive: true,
      );
      const bannerB = HeroBannerEntity(
        id: 'banner_b',
        title: 'Summer Splash',
        order: 0,
        isActive: true,
      );
      const bannerC = HeroBannerEntity(
        id: 'banner_c',
        title: 'Old Inactive',
        order: 2,
        isActive: false,
      );

      catalogRepo.mockHeroBanners = [bannerA, bannerB, bannerC];

      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        secureStorage: secureStorage,
      );

      // 1. Initial fetch with forceRefresh: true
      bloc.add(const FetchHeroBannersEvent(forceRefresh: true));
      await Future.delayed(const Duration(milliseconds: 100));

      // Inactive bannerC should be filtered out, sorted by order (bannerB [0] then bannerA [1])
      expect(bloc.state.heroBanners.length, 2);
      expect(bloc.state.heroBanners.first.id, 'banner_b');
      expect(bloc.state.heroBanners.last.id, 'banner_a');

      // 2. Admin deletes banner_b and adds banner_d
      const bannerD = HeroBannerEntity(
        id: 'banner_d',
        title: 'Flash Sale',
        order: 0,
        isActive: true,
      );
      catalogRepo.mockHeroBanners = [bannerA, bannerD];

      bloc.add(const FetchHeroBannersEvent(forceRefresh: true));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.heroBanners.length, 2);
      expect(bloc.state.heroBanners.any((b) => b.id == 'banner_b'), isFalse); // Deleted banner gone
      expect(bloc.state.heroBanners.first.id, 'banner_d'); // Newly added banner present

      // 3. Admin deletes ALL banners
      catalogRepo.mockHeroBanners = [];
      bloc.add(const FetchHeroBannersEvent(forceRefresh: true));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.heroBanners, isEmpty); // All deleted banners removed cleanly

      await bloc.close();
    });

    test('CustomerBloc syncs banner updates and deletions immediately via WebSocket stream', () async {
      final catalogRepo = MockCatalogRepository();
      final orderRepo = MockOrderRepository();
      final localCache = MockLocalCacheService();
      final secureStorage = MockSecureStorageService();
      final webSocketService = MockWebSocketService();

      final initialTime = DateTime.utc(2026, 11, 11, 8, 0, 0);
      final updatedTime = DateTime.utc(2026, 11, 11, 8, 5, 0);

      catalogRepo.mockHeroBanners = [
        HeroBannerEntity(
          id: 'b1',
          title: 'Initial Banner',
          imageUrl: 'https://cdn.example.com/v1.png',
          order: 0,
          isActive: true,
          updatedAt: initialTime,
        ),
        HeroBannerEntity(
          id: 'b2',
          title: 'Temp Deal',
          order: 1,
          isActive: true,
          updatedAt: initialTime,
        ),
      ];

      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        secureStorage: secureStorage,
        webSocketService: webSocketService,
      );

      bloc.add(const FetchHeroBannersEvent(forceRefresh: true));
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.heroBanners.length, 2);
      expect(bloc.state.heroBanners.first.title, 'Initial Banner');

      // 1. Admin updates b1 (title + imageUrl + updatedAt) and backend emits bannerUpdateStream event
      catalogRepo.mockHeroBanners = [
        HeroBannerEntity(
          id: 'b1',
          title: 'Updated Instant Banner',
          imageUrl: 'https://cdn.example.com/v2.png',
          order: 0,
          isActive: true,
          updatedAt: updatedTime,
        ),
        HeroBannerEntity(
          id: 'b2',
          title: 'Temp Deal',
          order: 1,
          isActive: true,
          updatedAt: initialTime,
        ),
      ];
      webSocketService.bannerController.add({'event': 'hero-banner:updated', 'id': 'b1'});
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.heroBanners.length, 2);
      expect(bloc.state.heroBanners.first.title, 'Updated Instant Banner');
      expect(bloc.state.heroBanners.first.imageUrl, 'https://cdn.example.com/v2.png');
      expect(bloc.state.heroBanners.first.updatedAt, updatedTime);

      // 2. Admin deletes b2 and backend emits delete event
      catalogRepo.mockHeroBanners = [
        HeroBannerEntity(
          id: 'b1',
          title: 'Updated Instant Banner',
          imageUrl: 'https://cdn.example.com/v2.png',
          order: 0,
          isActive: true,
          updatedAt: updatedTime,
        ),
      ];
      webSocketService.bannerController.add({'event': 'hero-banner:deleted', 'id': 'b2'});
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.heroBanners.length, 1);
      expect(bloc.state.heroBanners.any((b) => b.id == 'b2'), isFalse);

      // 3. Socket notification payload with banner type also deletes remaining banner
      catalogRepo.mockHeroBanners = [];
      webSocketService.notificationController.add({'type': 'BANNER_DELETED', 'id': 'b1'});
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.heroBanners, isEmpty);

      await bloc.close();
      webSocketService.dispose();
    });

    test('CustomerBloc filters stores between All Shops and Express (<10km) cleanly', () async {
      final catalogRepo = MockCatalogRepository();
      final orderRepo = MockOrderRepository();
      final localCache = MockLocalCacheService();
      final secureStorage = MockSecureStorageService();

      const expressStore = StoreEntity(
        id: 'store_fast',
        name: 'QuickMart Near',
        category: 'Groceries',
        address: 'MG Road',
        rating: 4.8,
        deliveryTime: '15 mins',
        distanceKm: 3.2,
        isOpen: true,
        bannerUrl: '',
      );
      const farStore = StoreEntity(
        id: 'store_far',
        name: 'HyperMart Far',
        category: 'Groceries',
        address: 'Ring Road',
        rating: 4.5,
        deliveryTime: '45 mins',
        distanceKm: 14.5,
        isOpen: true,
        bannerUrl: '',
      );

      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        secureStorage: secureStorage,
      );

      bloc.add(const CustomerStoresStreamUpdated([expressStore, farStore]));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.storeFilter, StoreFilterType.all);
      expect(bloc.state.zoneStores.length, 2);
      expect(bloc.state.expressStoreCount, 1);
      expect(bloc.state.filteredZoneStores.length, 2);

      // Tap Express < 10km
      bloc.add(const FilterStoresEvent(StoreFilterType.express));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.storeFilter, StoreFilterType.express);
      expect(bloc.state.filteredZoneStores.length, 1);
      expect(bloc.state.filteredZoneStores.first.id, 'store_fast');

      // Tap All Shops
      bloc.add(const FilterStoresEvent(StoreFilterType.all));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.storeFilter, StoreFilterType.all);
      expect(bloc.state.filteredZoneStores.length, 2);

      await bloc.close();
    });

    test('CustomerBloc receives FCM pushes, replays pending cold-start notifications, and deduplicates duplicates', () async {
      final catalogRepo = MockCatalogRepository();
      final orderRepo = MockOrderRepository();
      final localCache = MockLocalCacheService();
      final secureStorage = MockSecureStorageService();
      final pushService = MockPushNotificationService();

      pushService.pendingNotification = PushNotificationPayload(
        id: 'cold_start_1',
        title: 'Order Delivered!',
        body: 'Order QC-112233-4455 was delivered.',
        type: 'ORDER_UPDATE',
        orderId: 'QC-112233-4455',
        receivedAt: DateTime.now(),
        fromTap: true,
      );

      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        secureStorage: secureStorage,
        pushNotificationService: pushService,
      );

      await Future.delayed(const Duration(milliseconds: 80));

      // Pending cold-start tap should be consumed immediately on init (without incrementing unread badge)
      expect(bloc.state.notifications.length, 1);
      expect(bloc.state.notifications.first['id'], 'cold_start_1');
      expect(bloc.state.latestPushNotification?['fromTap'], isTrue);
      expect(bloc.state.unreadNotificationsCount, 0);

      // Foreground FCM push arrives
      pushService.simulateIncomingPush(
        PushNotificationPayload(
          id: 'fg_push_1',
          title: 'Rider Out For Delivery',
          body: 'Your order is 5 mins away',
          type: 'ORDER_UPDATE',
          orderId: 'QC-998877-6655',
          receivedAt: DateTime.now(),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.notifications.length, 2);
      expect(bloc.state.unreadNotificationsCount, 1);
      expect(bloc.state.latestPushNotification?['title'], 'Rider Out For Delivery');

      // Duplicate notification within 10s (e.g. Socket + FCM simultaneous delivery) must be ignored
      pushService.simulateIncomingPush(
        PushNotificationPayload(
          id: 'fg_push_dup',
          title: 'Rider Out For Delivery',
          body: 'Your order is 5 mins away',
          type: 'ORDER_UPDATE',
          orderId: 'QC-998877-6655',
          receivedAt: DateTime.now(),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.notifications.length, 2);
      expect(bloc.state.unreadNotificationsCount, 1);

      await bloc.close();
      pushService.dispose();
    });

    test('CustomerBloc applies active zone fees, free threshold, and minOrderAmount cleanly', () async {
      final catalogRepo = MockCatalogRepository();
      final orderRepo = MockOrderRepository();
      final localCache = MockLocalCacheService();
      final secureStorage = MockSecureStorageService();

      const item50 = ProductEntity(
        id: 'p_50',
        storeId: 's_blr',
        categoryId: 'cat_1',
        name: 'Fresh Curd',
        description: '400g',
        price: 50.0,
        imageUrl: '',
        unit: '400g',
        stock: 10,
        isAvailable: true,
      );

      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        secureStorage: secureStorage,
      );

      bloc.add(const AddToCartEvent(item50));
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Bengaluru zone: deliveryFee=0, platformFee=0, freeDeliveryThreshold=0, minOrderAmount=100
      catalogRepo.mockZone = const CustomerZoneEntity(
        inZone: true,
        zoneId: 'zone_blr',
        zoneName: 'Bengaluru',
        deliveryFee: 0.0,
        platformFee: 0.0,
        freeDeliveryThreshold: 0.0,
        minOrderAmount: 100.0,
      );
      bloc.add(const CheckCustomerLocationEvent(lat: 12.9716, lng: 77.5946));
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.deliveryFee, 0.0);
      expect(bloc.state.platformFee, 0.0);
      expect(bloc.state.effectiveFreeDeliveryThreshold, 0.0);
      expect(bloc.state.isBelowMinOrder, isTrue); // 50 < 100
      expect(bloc.state.cartGrandTotal, 50.0);

      // 2. Switch to Channagiri zone: deliveryFee=25, platformFee=5, freeDeliveryThreshold=400, minOrderAmount=500
      catalogRepo.mockZone = const CustomerZoneEntity(
        inZone: true,
        zoneId: 'zone_chn',
        zoneName: 'Channagiri',
        deliveryFee: 25.0,
        platformFee: 5.0,
        freeDeliveryThreshold: 400.0,
        minOrderAmount: 500.0,
      );
      bloc.add(const CheckCustomerLocationEvent(lat: 14.0277, lng: 75.9327));
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.deliveryFee, 25.0);
      expect(bloc.state.platformFee, 5.0);
      expect(bloc.state.effectiveFreeDeliveryThreshold, 400.0);
      expect(bloc.state.isBelowMinOrder, isTrue); // 50 < 500
      expect(bloc.state.cartGrandTotal, 80.0); // 50 + 25 + 5

      // Increase qty to 10 (subtotal 500 >= 400 free delivery & >= 500 min order)
      bloc.add(const UpdateCartQuantityEvent('p_50', 10));
      await Future.delayed(const Duration(milliseconds: 80));

      expect(bloc.state.deliveryFee, 0.0);
      expect(bloc.state.platformFee, 5.0);
      expect(bloc.state.isBelowMinOrder, isFalse);
      expect(bloc.state.cartGrandTotal, 505.0);

      await bloc.close();
    });

    test('CustomerBloc manages search history (add, deduplicate, cap at 10, remove, clear) and persists via repository', () async {
      final catalogRepo = MockCatalogRepository()
        ..mockSearchHistory = ['Milk', 'Bread'];
      final orderRepo = MockOrderRepository();
      final localCache = MockLocalCacheService();
      final secureStorage = MockSecureStorageService();

      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        secureStorage: secureStorage,
      );

      expect(bloc.state.searchHistory, ['Milk', 'Bread']);

      // Ignore < 2 char queries
      bloc.add(const AddSearchHistoryEvent('a'));
      await Future.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.searchHistory, ['Milk', 'Bread']);

      // Case-insensitive deduplication moves item to top
      bloc.add(const AddSearchHistoryEvent('bread'));
      await Future.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.searchHistory, ['bread', 'Milk']);
      expect(catalogRepo.mockSearchHistory, ['bread', 'Milk']);

      // Cap at 10 items
      for (var i = 1; i <= 10; i++) {
        bloc.add(AddSearchHistoryEvent('Item $i'));
      }
      await Future.delayed(const Duration(milliseconds: 60));
      expect(bloc.state.searchHistory.length, 10);
      expect(bloc.state.searchHistory.first, 'Item 10');

      // Remove single item
      bloc.add(const RemoveSearchHistoryItemEvent('Item 10'));
      await Future.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.searchHistory.contains('Item 10'), isFalse);
      expect(bloc.state.searchHistory.length, 9);

      // Clear all
      bloc.add(const ClearSearchHistoryEvent());
      await Future.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.searchHistory, isEmpty);
      expect(catalogRepo.mockSearchHistory, isEmpty);

      await bloc.close();
    });
  });
}
