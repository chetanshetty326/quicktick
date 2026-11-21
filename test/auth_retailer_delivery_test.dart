import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import 'dart:async';

// Mock Secure Storage Service
class MockSecureStorageService implements ISecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    _store['accessToken'] = accessToken;
    _store['refreshToken'] = refreshToken;
    _store['sessionExpiry'] = DateTime.now().add(expiryDuration).toIso8601String();
  }

  @override
  Future<String?> getAccessToken() async => _store['accessToken'];

  @override
  Future<String?> getRefreshToken() async => _store['refreshToken'];

  @override
  Future<DateTime?> getSessionExpiry() async {
    final str = _store['sessionExpiry'];
    return str != null ? DateTime.tryParse(str) : null;
  }

  @override
  Future<Duration?> getSessionRemainingTime() async {
    final exp = await getSessionExpiry();
    if (exp == null) return null;
    final diff = exp.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Future<void> saveUserRole(String role) async => _store['role'] = role;

  @override
  Future<String?> getUserRole() async => _store['role'];

  @override
  Future<void> saveUserId(String userId) async => _store['userId'] = userId;

  @override
  Future<String?> getUserId() async => _store['userId'];

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
    _store['role'] = role;
    _store['name'] = name;
    _store['phone'] = phone;
    if (email != null) _store['email'] = email;
    _store['sessionExpiry'] = DateTime.now().add(expiryDuration).toIso8601String();
  }

  @override
  Future<Map<String, String?>> getUserData() async => {
        'userId': _store['userId'],
        'role': _store['role'],
        'name': _store['name'],
        'phone': _store['phone'],
      };

  @override
  Future<bool> isSessionValid() async {
    final expiryStr = _store['sessionExpiry'];
    if (expiryStr == null) return false;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  @override
  Future<void> clearAuthData() async => _store.clear();
}

// Mock Shared Repos
class MockCatalogRepo implements ICatalogRepository {
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  final _storesCtrl = StreamController<List<StoreEntity>>.broadcast();

  final List<ProductEntity> mockProducts = [
    const ProductEntity(
      id: 'p1',
      storeId: 'store_01',
      name: 'Farm Fresh Organic Milk',
      description: 'Milk',
      price: 32.0,
      unit: '500 ml',
      imageUrl: '',
      categoryId: 'cat_dairy',
      isAvailable: true,
      stock: 50,
    ),
  ];

  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;
  @override
  Stream<List<StoreEntity>> get storesStream => _storesCtrl.stream;

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async => const Right([]);
  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async => const Right([]);
  @override
  Future<Either<Failure, StoreEntity>> getStoreDetails(String storeId) async => Right(StoreEntity(
        id: storeId,
        name: 'Store',
        category: 'Grocery',
        address: 'Indiranagar',
        rating: 4.8,
        deliveryTime: '15 MINS',
        distanceKm: 0.5,
        isOpen: true,
        bannerUrl: '',
      ));
  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async => Right(mockProducts);
  @override
  Future<Either<Failure, List<ProductEntity>>> searchProducts(String query, {String? category, int? page, int? limit}) async => Right(mockProducts);
  @override
  Future<Either<Failure, ({List<ProductEntity> products, List<StoreEntity> stores})>> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
  }) async => Right((products: mockProducts, stores: const []));
  @override
  Future<Either<Failure, List<ProductEntity>>> getRecommendations() async => Right(mockProducts);
  @override
  Future<Either<Failure, Map<String, dynamic>>> validateCart(List<Map<String, dynamic>> items) async => const Right({'valid': true});
  @override
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async => const Right([]);
  @override
  Future<Either<Failure, CustomerAddressEntity>> addAddress(CustomerAddressEntity address) async => Right(address);
  @override
  Future<Either<Failure, CustomerAddressEntity>> updateAddress(String addressId, CustomerAddressEntity address) async => Right(address);
  @override
  Future<Either<Failure, bool>> deleteAddress(String addressId) async => const Right(true);
  @override
  Future<Either<Failure, bool>> setDefaultAddress(String addressId) async => const Right(true);
  @override
  Future<Either<Failure, List<ProductEntity>>> getWishlist() async => Right(mockProducts);
  @override
  Future<Either<Failure, bool>> addToWishlist(String productId) async => const Right(true);
  @override
  Future<Either<Failure, bool>> removeFromWishlist(String productId) async => const Right(true);
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async => const Right([]);
  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async => const Right(true);
  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async => const Right(true);
  @override
  Future<Either<Failure, bool>> registerDeviceToken({
    required String fcmToken,
    required String platform,
    required String deviceId,
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
      name: 'Fresh Mart',
      category: 'Grocery',
      address: 'Indiranagar',
      rating: 4.8,
      deliveryTime: '15 MINS',
      distanceKm: 0.5,
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
  }) async {
    final o = OrderEntity(
      id: 'order_1',
      orderNumber: 'LDE-1',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: 32.0,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: 52.0,
      status: OrderStatus.placed,
      deliveryOtp: '6634',
      createdAt: DateTime.now(),
    );
    orders.add(o);
    _ordersCtrl.add(List.from(orders));
    return Right(o);
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => Right(orders);

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

  void dispose() {
    _ordersCtrl.close();
  }
}

void main() {
  group('1. AuthBloc Functional Tests', () {
    late MockSecureStorageService mockStorage;
    late AuthBloc authBloc;

    setUp(() {
      mockStorage = MockSecureStorageService();
      authBloc = AuthBloc(mockStorage);
    });

    tearDown(() {
      authBloc.close();
    });

    test('Initial State is AuthInitial', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    test('CheckAuthSessionEvent on empty storage emits UnauthenticatedState', () async {
      authBloc.add(CheckAuthSessionEvent());

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<UnauthenticatedState>(),
        ]),
      );
    });

    test('SwitchRoleEvent switches to Retailer role and saves in secure storage', () async {
      authBloc.add(const SwitchRoleEvent(UserRole.retailer));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthState>((s) =>
              s is AuthenticatedState && s.user.role == UserRole.retailer),
        ]),
      );

      final role = await mockStorage.getUserRole();
      expect(role, 'retailer');
    });

    test('LogoutEvent clears secure storage and emits UnauthenticatedState', () async {
      authBloc.add(LogoutEvent());

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<UnauthenticatedState>(),
        ]),
      );
    });
  });

  group('2. RetailerBloc Functional Tests', () {
    late MockCatalogRepo mockCatalogRepo;
    late MockOrderRepo mockOrderRepo;
    late RetailerBloc retailerBloc;

    setUp(() async {
      mockCatalogRepo = MockCatalogRepo();
      mockOrderRepo = MockOrderRepo();
      await mockOrderRepo.createOrder(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '+91 98765 43210',
        deliveryAddress: 'Flat 402, Indiranagar',
        storeId: 'store_01',
        storeName: 'Fresh Mart',
        storeAddress: '100ft Rd',
        items: const [
          OrderItemEntity(
            productId: 'p1',
            nameSnapshot: 'Milk',
            priceSnapshot: 32.0,
            unit: '500ml',
            quantity: 1,
          ),
        ],
        deliveryFee: 15.0,
        platformFee: 5.0,
      );

      retailerBloc = RetailerBloc(
        orderRepo: mockOrderRepo,
        catalogRepo: mockCatalogRepo,
      );
    });

    tearDown(() {
      retailerBloc.close();
      mockCatalogRepo.dispose();
      mockOrderRepo.dispose();
    });

    test('LoadRetailerDataEvent loads store orders and products', () async {
      retailerBloc.add(const LoadRetailerDataEvent(storeId: 'store_01'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(retailerBloc.state.orders.length, 1);
      expect(retailerBloc.state.orders[0].status, OrderStatus.placed);
    });

    test('AcceptOrderEvent moves order from Placed to Accepted', () async {
      retailerBloc.add(const LoadRetailerDataEvent(storeId: 'store_01'));
      await Future.delayed(const Duration(milliseconds: 50));

      retailerBloc.add(const AcceptOrderEvent('order_1'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockOrderRepo.orders[0].status, OrderStatus.accepted);
    });

    test('MarkPreparingEvent moves order to Preparing', () async {
      retailerBloc.add(const MarkPreparingEvent('order_1'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockOrderRepo.orders[0].status, OrderStatus.preparing);
    });

    test('MarkReadyForPickupEvent moves order to Ready for Pickup', () async {
      retailerBloc.add(const MarkReadyForPickupEvent('order_1'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockOrderRepo.orders[0].status, OrderStatus.readyForPickup);
    });

    test('UpdateProductInInventoryEvent modifies item in catalog', () async {
      const originalProduct = ProductEntity(
        id: 'p_test',
        storeId: 'store_01',
        categoryId: 'cat_dairy',
        name: 'Organic Milk',
        description: 'Pure cow milk',
        price: 32.0,
        originalPrice: 35.0,
        unit: '500ml',
        stock: 20,
        isAvailable: true,
        imageUrl: '',
      );
      await mockCatalogRepo.addProduct(originalProduct);

      final updatedProduct = originalProduct.copyWith(price: 34.0, name: 'A2 Organic Milk', stock: 15);
      retailerBloc.add(UpdateProductInInventoryEvent(updatedProduct));
      await Future.delayed(const Duration(milliseconds: 50));

      final fetched = mockCatalogRepo.mockProducts.firstWhere((p) => p.id == 'p_test');
      expect(fetched.name, 'A2 Organic Milk');
      expect(fetched.price, 34.0);
      expect(fetched.stock, 15);
    });

    test('DeleteProductFromInventoryEvent removes item from catalog', () async {
      const productToDelete = ProductEntity(
        id: 'p_delete',
        storeId: 'store_01',
        categoryId: 'cat_dairy',
        name: 'Bread',
        description: 'Brown bread',
        price: 45.0,
        originalPrice: 50.0,
        unit: '400g',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );
      await mockCatalogRepo.addProduct(productToDelete);
      expect(mockCatalogRepo.mockProducts.any((p) => p.id == 'p_delete'), isTrue);

      retailerBloc.add(const DeleteProductFromInventoryEvent('p_delete', productName: 'Bread'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockCatalogRepo.mockProducts.any((p) => p.id == 'p_delete'), isFalse);
    });
  });


  group('3. DeliveryBloc Functional Tests', () {
    late MockOrderRepo mockOrderRepo;
    late DeliveryBloc deliveryBloc;

    setUp(() async {
      mockOrderRepo = MockOrderRepo();
      await mockOrderRepo.createOrder(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '+91 98765 43210',
        deliveryAddress: 'Flat 402, Indiranagar',
        storeId: 'store_01',
        storeName: 'Fresh Mart',
        storeAddress: '100ft Rd',
        items: const [
          OrderItemEntity(
            productId: 'p1',
            nameSnapshot: 'Milk',
            priceSnapshot: 32.0,
            unit: '500ml',
            quantity: 1,
          ),
        ],
        deliveryFee: 15.0,
        platformFee: 5.0,
      );

      deliveryBloc = DeliveryBloc(orderRepo: mockOrderRepo);
    });

    tearDown(() {
      deliveryBloc.close();
      mockOrderRepo.dispose();
    });

    test('ToggleDutyEvent switches driver status online and offline', () async {
      deliveryBloc.add(const ToggleDutyEvent(true));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(deliveryBloc.state.isOnline, true);

      deliveryBloc.add(const ToggleDutyEvent(false));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(deliveryBloc.state.isOnline, false);
    });

    test('AcceptDeliveryJobEvent assigns driver and moves order to Out for Delivery', () async {
      deliveryBloc.add(const AcceptDeliveryJobEvent(
        orderId: 'order_1',
        driverId: 'driver_01',
        driverName: 'Ramesh Kumar',
        driverPhone: '+91 91234 56789',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockOrderRepo.orders[0].status, OrderStatus.outForDelivery);
      expect(mockOrderRepo.orders[0].deliveryPartnerId, 'driver_01');
    });

    test('VerifyDeliveryOtpEvent validates correct OTP and marks Delivered', () async {
      // Valid OTP '6634'
      deliveryBloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'order_1',
        otp: '6634',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockOrderRepo.orders[0].status, OrderStatus.delivered);
    });

    test('VerifyDeliveryOtpEvent rejects incorrect OTP', () async {
      // Reset order status
      mockOrderRepo.orders[0] = mockOrderRepo.orders[0].copyWith(status: OrderStatus.outForDelivery);

      // Invalid OTP '0000'
      deliveryBloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'order_1',
        otp: '0000',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockOrderRepo.orders[0].status, OrderStatus.outForDelivery);
      expect(deliveryBloc.state.errorMessage, 'Invalid OTP');
    });
  });
}
