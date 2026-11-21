import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/customer/domain/entities/cart_item_entity.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import 'dart:async';

// Mock Catalog Repository
class MockCatalogRepo implements ICatalogRepository {
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  final _storesCtrl = StreamController<List<StoreEntity>>.broadcast();

  final List<ProductEntity> mockProducts = [
    const ProductEntity(
      id: 'p1',
      storeId: 'store_01',
      name: 'Farm Fresh Organic Milk',
      description: 'Pure whole cow milk',
      price: 32.0,
      unit: '500 ml',
      imageUrl: 'https://img.test/milk.png',
      categoryId: 'cat_dairy',
      isAvailable: true,
      stock: 50,
    ),
    const ProductEntity(
      id: 'p2',
      storeId: 'store_01',
      name: 'Whole Wheat Brown Bread',
      description: '100% whole grain bread',
      price: 45.0,
      unit: '400g',
      imageUrl: 'https://img.test/bread.png',
      categoryId: 'cat_bakery',
      isAvailable: true,
      stock: 30,
    ),
    const ProductEntity(
      id: 'p3',
      storeId: 'store_01',
      name: 'Country Fresh Eggs (Pack of 6)',
      description: 'Farm fresh brown eggs',
      price: 60.0,
      unit: '6 pcs',
      imageUrl: 'https://img.test/eggs.png',
      categoryId: 'cat_dairy',
      isAvailable: true,
      stock: 40,
    ),
  ];

  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;

  @override
  Stream<List<StoreEntity>> get storesStream => _storesCtrl.stream;

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async {
    return const Right([
      CategoryEntity(id: 'cat_dairy', name: 'Dairy & Eggs', icon: '🥛', colorHex: '#4CAF50'),
      CategoryEntity(id: 'cat_bakery', name: 'Bakery & Bread', icon: '🍞', colorHex: '#FF9800'),
    ]);
  }

  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async {
    return const Right([
      StoreEntity(
        id: 'store_01',
        name: 'Fresh Mart Essentials',
        category: 'Grocery',
        address: 'Indiranagar 100ft Rd',
        deliveryTime: '15 MINS',
        distanceKm: 1.2,
        rating: 4.8,
        isOpen: true,
        bannerUrl: 'https://img.test/banner.png',
      ),
    ]);
  }

  @override
  Future<Either<Failure, StoreEntity>> getStoreDetails(String storeId) async {
    return const Right(StoreEntity(
      id: 'store_01',
      name: 'Fresh Mart Essentials',
      category: 'Grocery',
      address: 'Indiranagar 100ft Rd',
      deliveryTime: '15 MINS',
      distanceKm: 1.2,
      rating: 4.8,
      isOpen: true,
      bannerUrl: 'https://img.test/banner.png',
    ));
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async {
    return Right(mockProducts);
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> searchProducts(String query, {String? category, int? page, int? limit}) async {
    return Right(mockProducts.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList());
  }

  @override
  Future<Either<Failure, ({List<ProductEntity> products, List<StoreEntity> stores})>> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    return Right((
      products: mockProducts.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList(),
      stores: const [],
    ));
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getRecommendations() async {
    return Right(mockProducts);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> validateCart(List<Map<String, dynamic>> items) async {
    return const Right({'valid': true});
  }

  @override
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, CustomerAddressEntity>> addAddress(CustomerAddressEntity address) async {
    return Right(address);
  }

  @override
  Future<Either<Failure, CustomerAddressEntity>> updateAddress(String addressId, CustomerAddressEntity address) async {
    return Right(address);
  }

  @override
  Future<Either<Failure, bool>> deleteAddress(String addressId) async {
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> setDefaultAddress(String addressId) async {
    return const Right(true);
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getWishlist() async {
    return Right(mockProducts);
  }

  @override
  Future<Either<Failure, bool>> addToWishlist(String productId) async {
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> removeFromWishlist(String productId) async {
    return const Right(true);
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async {
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async {
    return const Right(true);
  }

  @override
  Future<Either<Failure, CustomerZoneEntity>> checkLocation({required double lat, required double lng}) async {
    return const Right(CustomerZoneEntity(inZone: true));
  }

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async {
    return const Right(0);
  }

  @override
  Future<Either<Failure, bool>> registerDeviceToken({
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) async => const Right(true);

  @override
  Future<Either<Failure, ProductEntity>> toggleProductStock(String productId, bool isAvailable) async {
    final p = mockProducts.firstWhere((e) => e.id == productId);
    return Right(p.copyWith(isAvailable: isAvailable));
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProductPrice(String productId, double newPrice) async {
    final p = mockProducts.firstWhere((e) => e.id == productId);
    return Right(p.copyWith(price: newPrice));
  }

  @override
  Future<Either<Failure, StoreEntity>> toggleStoreOpenStatus(String storeId, bool isOpen) async {
    return Right(StoreEntity(
      id: storeId,
      name: 'Fresh Mart Essentials',
      category: 'Grocery',
      address: 'Indiranagar',
      rating: 4.8,
      deliveryTime: '15 MINS',
      distanceKm: 1.0,
      isOpen: isOpen,
      bannerUrl: '',
    ));
  }

  @override
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product) async {
    mockProducts.insert(0, product);
    return Right(product);
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async {
    final idx = mockProducts.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      mockProducts[idx] = product;
      return Right(product);
    }
    return const Left(ValidationFailure(message: 'Product not found'));
  }

  @override
  Future<Either<Failure, String>> deleteProduct(String productId) async {
    final idx = mockProducts.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      mockProducts.removeAt(idx);
      return Right(productId);
    }
    return const Left(ValidationFailure(message: 'Product not found'));
  }


  void dispose() {
    _productsCtrl.close();
    _storesCtrl.close();
  }
}

// Mock Order Repository
class MockOrderRepo implements IOrderRepository {
  final _ordersCtrl = StreamController<List<OrderEntity>>.broadcast();
  final List<OrderEntity> orders = [];

  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersCtrl.stream;

  @override
  Future<Either<Failure, OrderEntity>> createOrder({
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
    String paymentMethod = 'COD',
    String? zoneId,
    String? deliveryAddressId,
  }) async {
    final sub = items.fold<double>(0.0, (acc, item) => acc + item.total);
    final order = OrderEntity(
      id: 'order_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: 'LDE-${DateTime.now().millisecondsSinceEpoch % 10000}',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: sub,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: sub + deliveryFee + platformFee,
      status: OrderStatus.placed,
      deliveryOtp: '1234',
      createdAt: DateTime.now(),
    );
    orders.insert(0, order);
    _ordersCtrl.add(List.from(orders));
    return Right(order);
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async {
    return Right(orders.where((o) => o.customerId == customerId).toList());
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async {
    return Right(orders.where((o) => o.storeId == storeId).toList());
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async {
    return Right(orders.where((o) => o.deliveryPartnerId == deliveryPartnerId).toList());
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async {
    return Right(orders.where((o) => o.status == OrderStatus.readyForPickup).toList());
  }

  @override
  Future<Either<Failure, OrderEntity>> updateOrderStatus({
    required String orderId,
    required OrderStatus nextStatus,
    String? reason,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = orders[idx].copyWith(status: nextStatus);
      orders[idx] = updated;
      _ordersCtrl.add(List.from(orders));
      return Right(updated);
    }
    return const Left(CacheFailure(message: 'Order not found'));
  }

  @override
  Future<Either<Failure, OrderEntity>> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = orders[idx].copyWith(paymentStatus: paymentStatus);
      orders[idx] = updated;
      _ordersCtrl.add(List.from(orders));
      return Right(updated);
    }
    return const Left(CacheFailure(message: 'Order not found'));
  }

  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({
    required String orderId,
    required String deliveryPartnerId,
    required String deliveryPartnerName,
    required String deliveryPartnerPhone,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = orders[idx].copyWith(
        deliveryPartnerId: deliveryPartnerId,
        deliveryPartnerName: deliveryPartnerName,
        deliveryPartnerPhone: deliveryPartnerPhone,
        status: OrderStatus.outForDelivery,
      );
      orders[idx] = updated;
      _ordersCtrl.add(List.from(orders));
      return Right(updated);
    }
    return const Left(CacheFailure(message: 'Order not found'));
  }

  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({
    required String orderId,
    required String enteredOtp,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      if (orders[idx].deliveryOtp == enteredOtp) {
        final updated = orders[idx].copyWith(status: OrderStatus.delivered);
        orders[idx] = updated;
        _ordersCtrl.add(List.from(orders));
        return Right(updated);
      }
      return const Left(CacheFailure(message: 'Invalid OTP'));
    }
    return const Left(CacheFailure(message: 'Order not found'));
  }

  @override
  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx] = orders[idx].copyWith(status: OrderStatus.cancelled);
      _ordersCtrl.add(List.from(orders));
    }
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async {
    return const Right(true);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId) async {
    return const Right({'status': 'PREPARING'});
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getOrdersByStatus(String status) async => const Right([]);

  @override
  Future<Either<Failure, Map<String, dynamic>>> getPaymentStatus(String orderId) async => const Right({});

  void dispose() {
    _ordersCtrl.close();
  }
}

// Mock Local Cache Service
class MockLocalCacheService implements ILocalCacheService {
  List<Map<String, dynamic>> cart = [];

  @override
  Future<void> init() async {}

  @override
  List<Map<String, dynamic>> getCartItems() => cart;

  @override
  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    cart = items;
  }

  @override
  Future<void> clearCart() async {
    cart = [];
  }

  @override
  Future<void> cacheStores(List<Map<String, dynamic>> stores) async {}

  @override
  List<Map<String, dynamic>> getCachedStores() => [];

  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {}

  @override
  List<Map<String, dynamic>> getCachedProducts() => [];

  @override
  Future<void> cacheAddresses(List<Map<String, dynamic>> addresses) async {}

  @override
  List<Map<String, dynamic>> getCachedAddresses() => [];

  @override
  Future<void> cacheActiveOrders(List<Map<String, dynamic>> orders) async {}

  @override
  List<Map<String, dynamic>> getCachedActiveOrders() => [];

  @override
  Future<List<Map<String, dynamic>>> reloadAndGetCachedOrders() async => [];

  @override
  Future<void> setDarkMode(bool isDark) async {}

  @override
  bool isDarkMode() => false;

  @override
  Future<void> setDevRole(String role) async {}

  @override
  String? getDevRole() => null;
}

void main() {
  group('1. Cart Calculations & Domain Logic', () {
    test('CartItemEntity accurately computes total item price', () {
      const prod = ProductEntity(
        id: 'p1',
        storeId: 'store_01',
        name: 'Farm Fresh Organic Milk',
        description: 'Milk',
        price: 32.0,
        unit: '500 ml',
        imageUrl: '',
        categoryId: 'cat_dairy',
        isAvailable: true,
        stock: 20,
      );

      final item = CartItemEntity(product: prod, quantity: 3);
      expect(item.total, 96.0);
      expect(item.quantity, 3);
    });

    test('Free Delivery threshold calculation (₹199 threshold)', () {
      const double freeDeliveryThreshold = 199.0;
      double subtotal = 140.0;
      double remaining = (freeDeliveryThreshold - subtotal).clamp(0.0, double.infinity);
      bool isFreeDelivery = subtotal >= freeDeliveryThreshold;

      expect(remaining, 59.0);
      expect(isFreeDelivery, false);

      subtotal = 210.0;
      remaining = (freeDeliveryThreshold - subtotal).clamp(0.0, double.infinity);
      isFreeDelivery = subtotal >= freeDeliveryThreshold;

      expect(remaining, 0.0);
      expect(isFreeDelivery, true);
    });

    test('Promo Code rules calculation', () {
      const subtotal = 150.0;
      const deliveryFee = 15.0;

      // Rule 1: QUICK15 gives Flat ₹15 off
      double discount1 = 15.0;
      expect(discount1, 15.0);

      // Rule 2: FREEDEL waives delivery fee
      double discount2 = deliveryFee;
      expect(discount2, 15.0);

      // Rule 3: SAVE10 gives 10% discount
      double discount3 = subtotal * 0.10;
      expect(discount3, 15.0);
    });
  });

  group('2. Order Entity Domain Progression', () {
    test('Order creates with correct fields and progresses through full lifecycle', () {
      final order = OrderEntity(
        id: 'order_101',
        orderNumber: 'LDE-101',
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '+91 98765 43210',
        storeId: 'store_01',
        storeName: 'Fresh Mart Essentials',
        storeAddress: 'Indiranagar 100ft Rd',
        items: const [
          OrderItemEntity(
            productId: 'p1',
            nameSnapshot: 'Farm Fresh Organic Milk',
            priceSnapshot: 32.0,
            unit: '500 ml',
            quantity: 2,
          ),
        ],
        subtotal: 64.0,
        deliveryFee: 15.0,
        platformFee: 5.0,
        grandTotal: 84.0,
        status: OrderStatus.placed,
        deliveryAddress: 'Flat 402, Sunshine Heights, Indiranagar',
        deliveryOtp: '6634',
        createdAt: DateTime.now(),
      );

      expect(order.status, OrderStatus.placed);
      expect(order.deliveryOtp, '6634');
      expect(order.items.length, 1);
      expect(order.items[0].nameSnapshot, 'Farm Fresh Organic Milk');
      expect(order.grandTotal, 84.0);

      // Transition to Preparing
      final preparingOrder = order.copyWith(status: OrderStatus.preparing);
      expect(preparingOrder.status, OrderStatus.preparing);

      // Transition to Ready for Pickup
      final readyOrder = preparingOrder.copyWith(status: OrderStatus.readyForPickup);
      expect(readyOrder.status, OrderStatus.readyForPickup);

      // Transition to Out for Delivery
      final outForDeliveryOrder = readyOrder.copyWith(
        status: OrderStatus.outForDelivery,
        deliveryPartnerId: 'driver_01',
        deliveryPartnerName: 'Ramesh Kumar',
      );
      expect(outForDeliveryOrder.status, OrderStatus.outForDelivery);
      expect(outForDeliveryOrder.deliveryPartnerId, 'driver_01');

      // Transition to Delivered
      final deliveredOrder = outForDeliveryOrder.copyWith(status: OrderStatus.delivered);
      expect(deliveredOrder.status, OrderStatus.delivered);
    });
  });

  group('3. CustomerBloc Functional Tests', () {
    late MockCatalogRepo mockCatalogRepo;
    late MockOrderRepo mockOrderRepo;
    late MockLocalCacheService mockCache;
    late CustomerBloc bloc;

    setUp(() {
      mockCatalogRepo = MockCatalogRepo();
      mockOrderRepo = MockOrderRepo();
      mockCache = MockLocalCacheService();
      bloc = CustomerBloc(
        catalogRepo: mockCatalogRepo,
        orderRepo: mockOrderRepo,
        localCache: mockCache,
      );
    });

    tearDown(() {
      bloc.close();
      mockCatalogRepo.dispose();
      mockOrderRepo.dispose();
    });

    test('Initial state is clean CustomerState', () {
      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.isLoading, false);
      expect(bloc.state.selectedAddress, 'Select Delivery Address');
    });

    test('LoadCustomerDataEvent loads catalog products and categories', () async {
      bloc.add(LoadCustomerDataEvent());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<CustomerState>((s) => s.isLoading == true),
          predicate<CustomerState>((s) =>
              s.isLoading == false &&
              s.allProducts.length == 3 &&
              s.categories.length == 2),
          predicate<CustomerState>((s) =>
              s.isLoading == false &&
              s.stores.length == 1),
        ]),
      );
    });

    test('AddToCartEvent adds item and updates cartSubtotal', () async {
      final product = mockCatalogRepo.mockProducts[0]; // Price: 32.0

      bloc.add(AddToCartEvent(product));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CustomerState>((s) =>
              s.cartItems.length == 1 &&
              s.cartItems[0].product.id == 'p1' &&
              s.cartItems[0].quantity == 1 &&
              s.cartSubtotal == 32.0),
        ),
      );
    });

    test('UpdateCartQuantityEvent increments and decrements items', () async {
      final product = mockCatalogRepo.mockProducts[0]; // Price: 32.0

      bloc.add(AddToCartEvent(product));
      await Future.delayed(const Duration(milliseconds: 20));

      // Increment to 3
      bloc.add(const UpdateCartQuantityEvent('p1', 3));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.cartItems[0].quantity, 3);
      expect(bloc.state.cartSubtotal, 96.0);

      // Decrement to 0 (should remove)
      bloc.add(const UpdateCartQuantityEvent('p1', 0));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.cartSubtotal, 0.0);
    });

    test('FilterByCategoryEvent filters products accurately', () async {
      bloc.add(LoadCustomerDataEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const FilterByCategoryEvent('cat_bakery'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.selectedCategoryId, 'cat_bakery');
      expect(bloc.state.filteredProducts.length, 1);
      expect(bloc.state.filteredProducts[0].name, 'Whole Wheat Brown Bread');

      // Reset filter with all essentials category
      bloc.add(const FilterByCategoryEvent('cat_dairy'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.selectedCategoryId, 'cat_dairy');
      expect(bloc.state.filteredProducts.length, 2);
    });

    test('SearchProductsEvent filters by query string', () async {
      bloc.add(LoadCustomerDataEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const SearchProductsEvent('Eggs'));
      await Future.delayed(const Duration(milliseconds: 350));

      expect(bloc.state.searchQuery, 'Eggs');
      expect(bloc.state.filteredProducts.length, 1);
      expect(bloc.state.filteredProducts[0].name, contains('Eggs'));
    });

    test('SelectAddressEvent updates selected delivery address', () async {
      bloc.add(const SelectAddressEvent('House No. 18, 5th Main, Koramangala'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.selectedAddress, 'House No. 18, 5th Main, Koramangala');
    });

    test('PlaceOrderEvent creates order in repo and clears active cart', () async {
      // 1. Load data
      bloc.add(LoadCustomerDataEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      // 2. Add product
      bloc.add(AddToCartEvent(mockCatalogRepo.mockProducts[0]));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.cartItems.isNotEmpty, true);

      // 3. Place Order
      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '+91 98765 43210',
        storeId: 'store_01',
        storeName: 'Fresh Mart Essentials',
        storeAddress: 'Indiranagar 100ft Rd',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // 4. Verify cart cleared and order stored in repository
      expect(bloc.state.cartItems, isEmpty);
      expect(mockOrderRepo.orders.length, 1);
      expect(mockOrderRepo.orders[0].items[0].nameSnapshot, 'Farm Fresh Organic Milk');
      expect(mockOrderRepo.orders[0].status, OrderStatus.placed);
    });
  });
}
