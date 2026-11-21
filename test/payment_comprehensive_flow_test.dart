import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/order/data/datasources/payment_remote_data_source.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'dart:async';

// Mock Catalog Repository
class MockPaymentTestCatalogRepo implements ICatalogRepository {
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  final _storesCtrl = StreamController<List<StoreEntity>>.broadcast();

  final List<ProductEntity> products = [
    const ProductEntity(
      id: 'prod_milk_1',
      storeId: 'store_01',
      name: 'Organic Milk 1L',
      description: 'Fresh cow milk',
      price: 60.0,
      unit: '1L',
      imageUrl: '',
      categoryId: 'cat_dairy',
      isAvailable: true,
      stock: 50,
    ),
    const ProductEntity(
      id: 'prod_bread_1',
      storeId: 'store_01',
      name: 'Brown Bread',
      description: 'Whole wheat bread',
      price: 45.0,
      unit: '400g',
      imageUrl: '',
      categoryId: 'cat_bakery',
      isAvailable: true,
      stock: 30,
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
        name: 'Quick Mart',
        category: 'Grocery',
        address: 'MG Road',
        rating: 4.8,
        deliveryTime: '15 min',
        distanceKm: 1.0,
        isOpen: true,
        bannerUrl: '',
      ));
  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async => Right(products);
  @override
  Future<Either<Failure, List<ProductEntity>>> searchProducts(String query, {String? category, int? page, int? limit}) async => Right(products);
  @override
  Future<Either<Failure, ({List<ProductEntity> products, List<StoreEntity> stores})>> searchCatalog({
    required String query,
    int page = 1,
    int limit = 20,
  }) async => Right((products: products, stores: const []));
  @override
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async => const Right([]);
  @override
  Future<Either<Failure, CustomerAddressEntity>> addAddress(CustomerAddressEntity address) async => Right(address);
  @override
  Future<Either<Failure, CustomerAddressEntity>> updateAddress(String id, CustomerAddressEntity address) async => Right(address);
  @override
  Future<Either<Failure, bool>> deleteAddress(String id) async => const Right(true);
  @override
  Future<Either<Failure, bool>> setDefaultAddress(String id) async => const Right(true);
  @override
  Future<Either<Failure, List<ProductEntity>>> getRecommendations() async => Right(products);
  @override
  Future<Either<Failure, List<ProductEntity>>> getWishlist() async => Right(products);
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
  Future<Either<Failure, ProductEntity>> toggleProductStock(String productId, bool isAvailable) async => Right(products.first);
  @override
  Future<Either<Failure, ProductEntity>> updateProductPrice(String productId, double newPrice) async => Right(products.first);
  @override
  Future<Either<Failure, StoreEntity>> toggleStoreOpenStatus(String storeId, bool isOpen) async => Right(StoreEntity(
        id: storeId,
        name: 'Quick Mart',
        category: 'Grocery',
        address: 'MG Road',
        rating: 4.8,
        deliveryTime: '15 min',
        distanceKm: 1.0,
        isOpen: isOpen,
        bannerUrl: '',
      ));
  @override
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product) async => Right(product);
  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async => Right(product);
  @override
  Future<Either<Failure, String>> deleteProduct(String productId) async => Right(productId);
  @override
  Future<Either<Failure, Map<String, dynamic>>> validateCart(List<Map<String, dynamic>> items) async => const Right({'valid': true});
}

// Mock Order Repository
class MockPaymentTestOrderRepo implements IOrderRepository {
  final _ctrl = StreamController<List<OrderEntity>>.broadcast();
  OrderEntity? lastCreated;

  @override
  Stream<List<OrderEntity>> get ordersStream => _ctrl.stream;
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
    final sub = items.fold(0.0, (acc, it) => acc + (it.priceSnapshot * it.quantity));
    final ord = OrderEntity(
      id: 'ord_live_test_01',
      orderNumber: 'QT-98124',
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
      deliveryOtp: '5678',
      paymentMethod: paymentMethod,
      paymentStatus: 'PENDING',
      createdAt: DateTime.now(),
    );
    lastCreated = ord;
    return Right(ord);
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async {
    return Right(lastCreated != null ? [lastCreated!] : []);
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => const Right([]);
  @override
  Future<Either<Failure, OrderEntity>> updateOrderStatus({required String orderId, required OrderStatus nextStatus, String? reason}) async => Right(lastCreated!);
  @override
  Future<Either<Failure, OrderEntity>> updatePaymentStatus({required String orderId, required String paymentStatus}) async {
    if (lastCreated != null) {
      lastCreated = lastCreated!.copyWith(paymentStatus: paymentStatus);
      return Right(lastCreated!);
    }
    return const Left(ValidationFailure(message: 'Order not found'));
  }
  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({required String orderId, required String deliveryPartnerId, required String deliveryPartnerName, required String deliveryPartnerPhone}) async => Right(lastCreated!);
  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({required String orderId, required String enteredOtp}) async => Right(lastCreated!);

  @override
  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason) async => const Right(true);
  @override
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async => const Right(true);
  @override
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId) async => const Right({'status': 'PLACED'});
}

// Mock Local Cache Service
class MockPaymentTestCacheService implements ILocalCacheService {
  final List<Map<String, dynamic>> _cart = [];
  @override
  Future<void> init() async {}
  @override
  List<Map<String, dynamic>> getCartItems() => _cart;
  @override
  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    _cart.clear();
    _cart.addAll(items);
  }
  @override
  Future<void> clearCart() async {
    _cart.clear();
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

// Configurable Mock Payment Remote Data Source
class ConfigurableMockPaymentRemoteDataSource implements IPaymentRemoteDataSource {
  bool shouldFailCreateOrder = false;
  bool shouldFailSignatureVerification = false;
  bool shouldFailRefund = false;

  @override
  Future<bool> confirmCodPayment(String orderId) async {
    return true;
  }

  @override
  Future<RazorpayOrderModel> createRazorpayOrder(String orderId) async {
    if (shouldFailCreateOrder) {
      throw Exception('Payment gateway server timeout: 504 Gateway Timeout');
    }
    return RazorpayOrderModel(
      orderId: orderId,
      razorpayOrderId: 'order_rzp_mock_live_789',
      amount: 8000,
      currency: 'INR',
      keyId: 'rzp_test_quicklink_key',
    );
  }

  @override
  Future<PaymentVerificationModel> verifyPaymentSignature({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String orderId,
  }) async {
    if (shouldFailSignatureVerification) {
      return PaymentVerificationModel(
        success: false,
        paymentId: razorpayPaymentId,
        status: 'FAILED',
        orderId: orderId,
      );
    }
    return PaymentVerificationModel(
      success: true,
      paymentId: razorpayPaymentId,
      status: 'CAPTURED',
      orderId: orderId,
    );
  }

  @override
  Future<bool> initiateRefund({
    required String orderId,
    required double amount,
    required String reason,
  }) async {
    if (shouldFailRefund) {
      return false;
    }
    return true;
  }
}

void main() {
  group('Payment Suite 1: Remote Data Source API Contract (Positive & Negative)', () {
    late ConfigurableMockPaymentRemoteDataSource paymentDs;

    setUp(() {
      paymentDs = ConfigurableMockPaymentRemoteDataSource();
    });

    test('[POS-01] createRazorpayOrder returns valid token with amount in paise and INR currency', () async {
      final res = await paymentDs.createRazorpayOrder('ord_101');
      expect(res.orderId, 'ord_101');
      expect(res.razorpayOrderId, 'order_rzp_mock_live_789');
      expect(res.amount, 8000);
      expect(res.currency, 'INR');
      expect(res.keyId, 'rzp_test_quicklink_key');
    });

    test('[POS-02] verifyPaymentSignature returns CAPTURED status with valid paymentId', () async {
      final res = await paymentDs.verifyPaymentSignature(
        razorpayOrderId: 'order_rzp_mock_live_789',
        razorpayPaymentId: 'pay_rzp_mock_999',
        razorpaySignature: 'valid_hmac_signature',
        orderId: 'ord_101',
      );
      expect(res.success, true);
      expect(res.status, 'CAPTURED');
      expect(res.paymentId, 'pay_rzp_mock_999');
      expect(res.orderId, 'ord_101');
    });

    test('[POS-03] initiateRefund returns true for valid refund request', () async {
      final res = await paymentDs.initiateRefund(
        orderId: 'ord_101',
        amount: 80.0,
        reason: 'Item unavailable',
      );
      expect(res, true);
    });

    test('[NEG-01] createRazorpayOrder throws exception on gateway failure', () async {
      paymentDs.shouldFailCreateOrder = true;
      expect(() => paymentDs.createRazorpayOrder('ord_101'), throwsA(isA<Exception>()));
    });

    test('[NEG-02] verifyPaymentSignature returns success=false on signature mismatch', () async {
      paymentDs.shouldFailSignatureVerification = true;
      final res = await paymentDs.verifyPaymentSignature(
        razorpayOrderId: 'order_rzp_mock_live_789',
        razorpayPaymentId: 'pay_invalid_000',
        razorpaySignature: 'tampered_signature',
        orderId: 'ord_101',
      );
      expect(res.success, false);
      expect(res.status, 'FAILED');
    });

    test('[NEG-03] initiateRefund returns false on rejection', () async {
      paymentDs.shouldFailRefund = true;
      final res = await paymentDs.initiateRefund(
        orderId: 'ord_101',
        amount: 80.0,
        reason: 'Invalid order',
      );
      expect(res, false);
    });
  });

  group('Payment Suite 2: Customer BLoC Payment Flow & Edge Cases', () {
    late MockPaymentTestCatalogRepo catalogRepo;
    late MockPaymentTestOrderRepo orderRepo;
    late MockPaymentTestCacheService cacheService;
    late ConfigurableMockPaymentRemoteDataSource paymentDs;
    late CustomerBloc bloc;

    setUp(() {
      catalogRepo = MockPaymentTestCatalogRepo();
      orderRepo = MockPaymentTestOrderRepo();
      cacheService = MockPaymentTestCacheService();
      paymentDs = ConfigurableMockPaymentRemoteDataSource();
      bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: cacheService,
        paymentDataSource: paymentDs,
      );
    });

    tearDown(() => bloc.close());

    test('[POS-04] Full Online UPI Checkout: PlaceOrder -> Intent -> Verification -> Order Confirmed', () async {
      // 1. Add item to cart
      bloc.add(AddToCartEvent(catalogRepo.products.first));
      await Future.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.cartItems.length, 1);
      expect(bloc.state.cartGrandTotal, 80.0); // 60 item + 15 del + 5 plat

      // 2. Place Order with UPI
      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '9876543210',
        storeId: 'store_01',
        storeName: 'Quick Mart',
        storeAddress: 'MG Road',
        paymentMethod: 'UPI',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.latestPlacedOrder, isNotNull);
      expect(bloc.state.activeRazorpayOrder, isNotNull);
      expect(bloc.state.activeRazorpayOrder!.razorpayOrderId, 'order_rzp_mock_live_789');

      // 3. Verify Payment
      bloc.add(VerifyRazorpayPaymentEvent(
        razorpayOrderId: bloc.state.activeRazorpayOrder!.razorpayOrderId,
        razorpayPaymentId: 'pay_live_test_777',
        razorpaySignature: 'valid_sig_123',
        orderId: bloc.state.latestPlacedOrder!.id,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.paymentVerification, isNotNull);
      expect(bloc.state.paymentVerification!.success, true);
      expect(bloc.state.latestPlacedOrder!.paymentStatus, 'COMPLETED');
      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.isPaymentProcessing, false);
      expect(bloc.state.successMessage, contains('Payment verified successfully'));
    });

    test('[POS-05] Full Online Cards/Netbanking Checkout completes successfully', () async {
      bloc.add(AddToCartEvent(catalogRepo.products[1]));
      await Future.delayed(const Duration(milliseconds: 30));

      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '9876543210',
        storeId: 'store_01',
        storeName: 'Quick Mart',
        storeAddress: 'MG Road',
        paymentMethod: 'CARD',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.activeRazorpayOrder, isNotNull);

      bloc.add(VerifyRazorpayPaymentEvent(
        razorpayOrderId: bloc.state.activeRazorpayOrder!.razorpayOrderId,
        razorpayPaymentId: 'pay_card_test_888',
        razorpaySignature: 'card_sig_456',
        orderId: bloc.state.latestPlacedOrder!.id,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.latestPlacedOrder!.paymentStatus, 'COMPLETED');
      expect(bloc.state.cartItems, isEmpty);
    });

    test('[POS-06] Cash on Delivery (COD) places order immediately without Razorpay intent', () async {
      bloc.add(AddToCartEvent(catalogRepo.products.first));
      await Future.delayed(const Duration(milliseconds: 30));

      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '9876543210',
        storeId: 'store_01',
        storeName: 'Quick Mart',
        storeAddress: 'MG Road',
        paymentMethod: 'COD',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.latestPlacedOrder, isNotNull);
      expect(bloc.state.latestPlacedOrder!.paymentMethod, 'COD');
      expect(bloc.state.activeRazorpayOrder, isNull);
      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.successMessage, contains('placed successfully'));
    });

    test('[NEG-04] Empty Cart checkout is rejected safely without creating order', () async {
      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '9876543210',
        storeId: 'store_01',
        storeName: 'Quick Mart',
        storeAddress: 'MG Road',
        paymentMethod: 'UPI',
      ));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(bloc.state.errorMessage, 'Cart is empty. Please add items.');
      expect(bloc.state.latestPlacedOrder, isNull);
      expect(bloc.state.activeRazorpayOrder, isNull);
    });

    test('[NEG-05] Payment Cancelled by customer preserves cart items and resets processing state', () async {
      // Add items
      bloc.add(AddToCartEvent(catalogRepo.products.first));
      bloc.add(AddToCartEvent(catalogRepo.products[1]));
      await Future.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.cartItems.length, 2);

      // Trigger payment cancellation event
      bloc.add(const RazorpayPaymentFailedEvent('Payment cancelled by customer'));
      await Future.delayed(const Duration(milliseconds: 30));

      // Assert cart is intact
      expect(bloc.state.cartItems.length, 2);
      expect(bloc.state.isPaymentProcessing, false);
      expect(bloc.state.paymentErrorMessage, 'Payment cancelled by customer');
    });

    test('[NEG-06] Failed signature verification emits paymentErrorMessage without false confirmation', () async {
      paymentDs.shouldFailSignatureVerification = true;

      bloc.add(AddToCartEvent(catalogRepo.products.first));
      await Future.delayed(const Duration(milliseconds: 30));

      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '9876543210',
        storeId: 'store_01',
        storeName: 'Quick Mart',
        storeAddress: 'MG Road',
        paymentMethod: 'UPI',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(VerifyRazorpayPaymentEvent(
        razorpayOrderId: 'order_rzp_mock_live_789',
        razorpayPaymentId: 'pay_tampered_000',
        razorpaySignature: 'tampered_signature',
        orderId: bloc.state.latestPlacedOrder!.id,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.paymentErrorMessage, contains('Payment verification failed'));
      expect(bloc.state.isPaymentProcessing, false);
    });

    test('[POS-07] Razorpay order fallback generates client token if remote gateway is offline', () async {
      paymentDs.shouldFailCreateOrder = true;

      bloc.add(AddToCartEvent(catalogRepo.products.first));
      await Future.delayed(const Duration(milliseconds: 30));

      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '9876543210',
        storeId: 'store_01',
        storeName: 'Quick Mart',
        storeAddress: 'MG Road',
        paymentMethod: 'UPI',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Verifies fallback token was created gracefully
      expect(bloc.state.activeRazorpayOrder, isNotNull);
      expect(bloc.state.activeRazorpayOrder!.currency, 'INR');
      expect(bloc.state.activeRazorpayOrder!.amount, 8000);
      expect(bloc.state.activeRazorpayOrder!.keyId, 'rzp_test_quicklink');
    });
  });
}
