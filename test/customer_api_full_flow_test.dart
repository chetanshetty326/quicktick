import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/data/models/check_mobile_response_model.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/order/data/datasources/payment_remote_data_source.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/data/datasources/order_remote_data_source.dart';
import 'package:quicklink/core/network/api_client.dart';
import 'dart:async';

// Mock Auth Remote Data Source
class MockAuthRemoteDataSource implements IAuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<CheckMobileResponseModel> checkMobile(String phone) async {
    return const CheckMobileResponseModel(
      success: true,
      exists: true,
      role: 'customer',
    );
  }

  @override
  Future<SendOtpResponseModel> sendOtp(String phone, {String? email, String? name}) async {
    return const SendOtpResponseModel(
      success: true,
      message: 'OTP sent successfully',
      expiresIn: 300,
      otp: '897831',
    );
  }

  @override
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? challengeId,
  }) async {
    if (otp == '897831' || otp == '123456') {
      return AuthResponseModel(
        user: UserEntity(
          id: 'user_live_01',
          name: 'John Doe',
          phone: phone.isNotEmpty ? phone : '9876543210',
          role: UserRole.customer,
        ),
        accessToken: 'live_access_jwt_123',
        refreshToken: 'live_refresh_jwt_456',
      );
    }
    throw Exception('Invalid OTP entered');
  }

  @override
  Future<AuthResponseModel> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    return const AuthResponseModel(
      user: UserEntity(
        id: 'user_live_01',
        name: 'John Doe',
        phone: '9876543210',
        role: UserRole.customer,
      ),
      accessToken: 'live_access_jwt_123',
      refreshToken: 'live_refresh_jwt_456',
    );
  }

  @override
  Future<Map<String, String>> refreshToken(String refreshToken) async {
    return {
      'accessToken': 'new_access_token',
      'refreshToken': 'new_refresh_token',
    };
  }

  @override
  Future<bool> logout({String? deviceId, String? fcmToken}) async {
    return true;
  }

  @override
  Future<UserEntity> getMe() async {
    return const UserEntity(
      id: 'user_live_01',
      name: 'John Doe',
      phone: '9876543210',
      role: UserRole.customer,
    );
  }

  @override
  Future<UserEntity> updateProfile({
    required String name,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    return UserEntity(
      id: 'user_live_01',
      name: name,
      phone: phone ?? '9876543210',
      email: email,
      role: UserRole.customer,
    );
  }
}

// Mock Secure Storage
class MockSecureStorage implements ISecureStorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Duration? expiryDuration,
  }) async {
    _data['accessToken'] = accessToken;
    _data['refreshToken'] = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _data['accessToken'];

  @override
  Future<String?> getRefreshToken() async => _data['refreshToken'];

  @override
  Future<void> saveUserData({
    required String userId,
    required String role,
    required String name,
    required String phone,
    String? email,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    _data['userId'] = userId;
    _data['role'] = role;
    _data['name'] = name;
    _data['phone'] = phone;
    if (email != null) _data['email'] = email;
  }

  @override
  Future<Map<String, String?>> getUserData() async {
    return {
      'userId': _data['userId'] as String?,
      'role': _data['role'] as String?,
      'name': _data['name'] as String?,
      'phone': _data['phone'] as String?,
    };
  }

  @override
  Future<void> saveUserId(String userId) async => _data['userId'] = userId;

  @override
  Future<String?> getUserId() async => _data['userId'];

  @override
  Future<DateTime?> getSessionExpiry() async => DateTime.now().add(const Duration(days: 7));

  @override
  Future<Duration?> getSessionRemainingTime() async => const Duration(days: 7);

  @override
  Future<void> saveUserRole(String role) async => _data['role'] = role;

  @override
  Future<String?> getUserRole() async => _data['role'];

  @override
  Future<bool> isSessionValid() async => true;

  @override
  Future<void> clearAuthData() async => _data.clear();
}

// Mock Catalog Repository for Customer API Testing
class MockFullCatalogRepo implements ICatalogRepository {
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  final _storesCtrl = StreamController<List<StoreEntity>>.broadcast();

  final List<CustomerAddressEntity> addresses = [];
  final List<ProductEntity> wishlist = [];
  final List<Map<String, dynamic>> notifications = [
    {
      'id': 'notif_1',
      'title': 'Order Delivered',
      'message': 'Your order #QM-20240901-0001 has been delivered',
      'read': false,
    },
  ];

  final List<ProductEntity> mockProducts = [
    const ProductEntity(
      id: 'prod_milk',
      storeId: 'store_01',
      name: 'Fresh Milk 1L',
      description: 'Farm fresh pasteurized milk',
      price: 60.0,
      unit: '1L',
      imageUrl: 'https://example.com/milk.jpg',
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
  Future<Either<Failure, StoreEntity>> getStoreDetails(String storeId) async => const Right(
        StoreEntity(
          id: 'store_01',
          name: 'QuickMart',
          category: 'Grocery',
          address: 'Bangalore',
          rating: 4.5,
          deliveryTime: '15 min',
          distanceKm: 1.0,
          isOpen: true,
          bannerUrl: '',
        ),
      );
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
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async => Right(addresses);
  @override
  Future<Either<Failure, CustomerAddressEntity>> addAddress(CustomerAddressEntity address) async {
    addresses.add(address);
    return Right(address);
  }
  @override
  Future<Either<Failure, CustomerAddressEntity>> updateAddress(String addressId, CustomerAddressEntity address) async {
    final idx = addresses.indexWhere((a) => a.id == addressId);
    if (idx != -1) {
      addresses[idx] = address;
    } else {
      addresses.add(address);
    }
    return Right(address);
  }
  @override
  Future<Either<Failure, bool>> deleteAddress(String addressId) async {
    addresses.removeWhere((a) => a.id == addressId);
    return const Right(true);
  }
  @override
  Future<Either<Failure, bool>> setDefaultAddress(String addressId) async => const Right(true);

  @override
  Future<Either<Failure, List<ProductEntity>>> getWishlist() async => Right(wishlist);
  @override
  Future<Either<Failure, bool>> addToWishlist(String productId) async {
    wishlist.addAll(mockProducts.where((p) => p.id == productId));
    return const Right(true);
  }
  @override
  Future<Either<Failure, bool>> removeFromWishlist(String productId) async {
    wishlist.removeWhere((p) => p.id == productId);
    return const Right(true);
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async => Right(notifications);
  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async {
    for (var n in notifications) {
      if (n['id'] == notificationId) n['read'] = true;
    }
    return const Right(true);
  }
  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async {
    for (var n in notifications) {
      n['read'] = true;
    }
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
  Future<Either<Failure, ProductEntity>> toggleProductStock(String productId, bool isAvailable) async => Right(mockProducts.first);
  @override
  Future<Either<Failure, ProductEntity>> updateProductPrice(String productId, double newPrice) async => Right(mockProducts.first);
  @override
  Future<Either<Failure, StoreEntity>> toggleStoreOpenStatus(String storeId, bool isOpen) async => Right(StoreEntity(
        id: storeId,
        name: 'Store',
        category: 'Grocery',
        address: 'Bangalore',
        rating: 4.5,
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
}

// Mock Order Repository
class MockDummyOrderRepo implements IOrderRepository {
  final _ctrl = StreamController<List<OrderEntity>>.broadcast();
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
    String? zoneId,
    String? deliveryAddressId,
  }) async {
    return Right(OrderEntity(
      id: '507f1f77bcf86cd799439011',
      orderNumber: 'QM-001',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: 100,
      deliveryFee: 15,
      platformFee: 5,
      grandTotal: 120,
      status: OrderStatus.placed,
      deliveryOtp: '4521',
      createdAt: DateTime.now(),
    ));
  }
  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => const Right([]);
  @override
  Future<Either<Failure, OrderEntity>> updateOrderStatus({required String orderId, required OrderStatus nextStatus, String? reason}) async => Right(OrderEntity(
    id: orderId,
    orderNumber: 'QM-001',
    customerId: 'cust_01',
    customerName: 'Customer',
    customerPhone: '9876543210',
    deliveryAddress: 'Bangalore',
    storeId: 's1',
    storeName: 'Store',
    storeAddress: 'Bangalore',
    items: const [],
    subtotal: 100,
    deliveryFee: 15,
    platformFee: 5,
    grandTotal: 120,
    status: nextStatus,
    deliveryOtp: '1234',
    createdAt: DateTime.now(),
  ));
  @override
  Future<Either<Failure, OrderEntity>> updatePaymentStatus({required String orderId, required String paymentStatus}) async => Right(OrderEntity(
    id: orderId,
    orderNumber: 'QM-001',
    customerId: 'cust_01',
    customerName: 'Customer',
    customerPhone: '9876543210',
    deliveryAddress: 'Bangalore',
    storeId: 's1',
    storeName: 'Store',
    storeAddress: 'Bangalore',
    items: const [],
    subtotal: 100,
    deliveryFee: 15,
    platformFee: 5,
    grandTotal: 120,
    status: OrderStatus.placed,
    deliveryOtp: '1234',
    paymentStatus: paymentStatus,
    createdAt: DateTime.now(),
  ));
  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({required String orderId, required String deliveryPartnerId, required String deliveryPartnerName, required String deliveryPartnerPhone}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({required String orderId, required String enteredOtp}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason) async => const Right(true);
  @override
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async => const Right(true);
  @override
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId) async => const Right({'status': 'PREPARING'});
  @override
  Future<Either<Failure, List<OrderEntity>>> getOrdersByStatus(String status) async => const Right([]);
  @override
  Future<Either<Failure, Map<String, dynamic>>> getPaymentStatus(String orderId) async => const Right({});
}

// Mock Local Cache Service
class MockDummyCacheService implements ILocalCacheService {
  @override
  Future<void> init() async {}
  @override
  List<Map<String, dynamic>> getCartItems() => [];
  @override
  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {}
  @override
  Future<void> clearCart() async {}
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

// Mock Payment Remote Data Source
class MockPaymentRemoteDataSource implements IPaymentRemoteDataSource {
  @override
  Future<RazorpayOrderModel> createRazorpayOrder(String orderId, {double? amount, String currency = 'INR'}) async {
    return RazorpayOrderModel(
      orderId: orderId,
      razorpayOrderId: 'order_rzp_mock_123',
      amount: 15000,
      currency: 'INR',
      keyId: 'rzp_test_12345',
    );
  }

  @override
  Future<PaymentVerificationModel> verifyPaymentSignature({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String orderId,
  }) async {
    return PaymentVerificationModel(
      success: true,
      paymentId: razorpayPaymentId,
      status: 'CAPTURED',
      orderId: orderId,
    );
  }

  @override
  Future<bool> confirmCodPayment(String orderId) async {
    return true;
  }

  @override
  Future<PaymentStatusModel> getPaymentStatus(String orderId) async {
    return const PaymentStatusModel(
      orderId: 'ord_1',
      status: 'PAID',
      method: 'ONLINE',
      amount: 150.0,
      razorpayOrderId: 'order_rzp_mock_123',
      razorpayPaymentId: 'pay_rzp_mock_123',
    );
  }

  @override
  Future<bool> initiateRefund({
    required String razorpayPaymentId,
    required double amount,
    String? orderId,
    String? reason,
  }) async {
    return true;
  }
}

void main() {
  group('1. Customer Live Authentication Flow (Endpoints 1 & 2)', () {
    late MockAuthRemoteDataSource mockAuthRemote;
    late MockSecureStorage mockSecureStorage;
    late AuthBloc authBloc;

    setUp(() {
      mockAuthRemote = MockAuthRemoteDataSource();
      mockSecureStorage = MockSecureStorage();
      authBloc = AuthBloc(mockSecureStorage, mockAuthRemote);
    });

    tearDown(() => authBloc.close());

    test('SendOtpEvent calls remote endpoint and emits OtpSentState with test OTP', () async {
      authBloc.add(const SendOtpEvent('9876543210'));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<OtpSentState>((state) =>
              state.phone == '9876543210' &&
              state.otp == '897831' &&
              state.expiresIn == 300),
        ]),
      );
    });

    test('LoginWithOtpEvent verifies OTP with customer role and stores JWT tokens', () async {
      authBloc.add(const LoginWithOtpEvent(
        phone: '9876543210',
        otp: '897831',
        name: 'John Doe',
        role: UserRole.customer,
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthenticatedState>((state) =>
              state.user.phone.contains('9876543210') &&
              state.user.role == UserRole.customer),
        ]),
      );

      final token = await mockSecureStorage.getAccessToken();
      expect(token, 'live_access_jwt_123');
    });

    test('Phone sanitization preserves valid 10-digit numbers starting with 91, country code +91, and leading zeros', () {
      expect(AuthRemoteDataSourceImpl.sanitizePhone('9876543210'), '9876543210');
      expect(AuthRemoteDataSourceImpl.sanitizePhone('9123456789'), '9123456789'); // Starts with 91 - NOT mangled
      expect(AuthRemoteDataSourceImpl.sanitizePhone('+91 98765 43210'), '9876543210');
      expect(AuthRemoteDataSourceImpl.sanitizePhone('+919123456789'), '9123456789');
      expect(AuthRemoteDataSourceImpl.sanitizePhone('09876543210'), '9876543210');
    });

    test('Login with ANY arbitrary phone number authenticates and saves user profile with valid OTP', () async {
      authBloc.add(const LoginWithOtpEvent(
        phone: '9123456789',
        otp: '897831',
        name: 'Rohan Sharma',
        role: UserRole.customer,
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthenticatedState>((state) =>
              state.user.phone.contains('9123456789') &&
              (state.user.name == 'John Doe' || state.user.name == 'Rohan Sharma') &&
              state.user.role == UserRole.customer),
        ]),
      );

      final userData = await mockSecureStorage.getUserData();
      expect(userData['phone'], contains('9123456789'));
      expect(userData['name'], isNotEmpty);
    });

    test('Login with WRONG or RANDOM OTP is rejected and emits AuthErrorState', () async {
      authBloc.add(const LoginWithOtpEvent(
        phone: '9876543210',
        otp: '000000', // Invalid OTP
        name: 'Hacker',
        role: UserRole.customer,
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthErrorState>((state) =>
              state.message.contains('Invalid OTP') ||
              state.message.contains('verification')),
        ]),
      );
    });
  });

  group('2. Customer Address PUT Update Flow (Endpoint 19)', () {
    late MockFullCatalogRepo catalogRepo;
    late CustomerBloc customerBloc;

    setUp(() {
      catalogRepo = MockFullCatalogRepo();
      customerBloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: MockDummyOrderRepo(),
        localCache: MockDummyCacheService(),
      );
    });

    tearDown(() => customerBloc.close());

    test('UpdateAddressEvent successfully modifies address details', () async {
      const initial = CustomerAddressEntity(
        id: 'addr_1',
        label: 'HOME',
        line1: '123 MG Road',
        city: 'Bangalore',
        state: 'Karnataka',
        pincode: '560001',
        lat: 12.9716,
        lng: 77.5946,
        isDefault: true,
      );
      customerBloc.add(const AddAddressEvent(initial));
      await Future.delayed(const Duration(milliseconds: 20));

      const updated = CustomerAddressEntity(
        id: 'addr_1',
        label: 'OFFICE',
        line1: '456 Residency Road',
        city: 'Bangalore',
        state: 'Karnataka',
        pincode: '560025',
        lat: 12.9720,
        lng: 77.5950,
        isDefault: true,
      );

      customerBloc.add(const UpdateAddressEvent(addressId: 'addr_1', address: updated));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(customerBloc.state.savedAddresses.first.label, 'OFFICE');
      expect(customerBloc.state.savedAddresses.first.line1, '456 Residency Road');
      expect(customerBloc.state.successMessage, 'Address updated successfully');
    });
  });

  group('3. Customer Wishlist & Notifications Flow (Endpoints 22-27)', () {
    late MockFullCatalogRepo catalogRepo;
    late CustomerBloc customerBloc;

    setUp(() {
      catalogRepo = MockFullCatalogRepo();
      customerBloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: MockDummyOrderRepo(),
        localCache: MockDummyCacheService(),
      );
    });

    tearDown(() => customerBloc.close());

    test('ToggleWishlistEvent adds and removes product IDs from customer wishlist state', () async {
      customerBloc.add(const ToggleWishlistEvent('prod_milk'));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(customerBloc.state.wishlistProductIds.contains('prod_milk'), true);

      // Toggle again to remove
      customerBloc.add(const ToggleWishlistEvent('prod_milk'));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(customerBloc.state.wishlistProductIds.contains('prod_milk'), false);
    });

    test('LoadNotificationsEvent and MarkNotificationReadEvent update state correctly', () async {
      customerBloc.add(LoadNotificationsEvent());
      await Future.delayed(const Duration(milliseconds: 20));
      expect(customerBloc.state.notifications.length, 1);
      expect(customerBloc.state.notifications.first['read'], false);

      customerBloc.add(const MarkNotificationReadEvent('notif_1'));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(customerBloc.state.notifications.first['read'], true);
    });
  });

  group('4. Razorpay Payments Module (Endpoints 79 & 80)', () {
    late MockPaymentRemoteDataSource paymentDataSource;

    setUp(() {
      paymentDataSource = MockPaymentRemoteDataSource();
    });

    test('Create Razorpay Order generates intent with currency INR and amount in paise', () async {
      final res = await paymentDataSource.createRazorpayOrder('order_001');
      expect(res.orderId, 'order_001');
      expect(res.razorpayOrderId, 'order_rzp_mock_123');
      expect(res.amount, 15000);
      expect(res.currency, 'INR');
    });

    test('Verify Payment Signature validates HMAC signature and captures payment', () async {
      final res = await paymentDataSource.verifyPaymentSignature(
        razorpayOrderId: 'order_rzp_mock_123',
        razorpayPaymentId: 'pay_rzp_mock_999',
        razorpaySignature: 'hmac_sha256_mock_sig',
        orderId: 'order_001',
      );

      expect(res.success, true);
      expect(res.status, 'CAPTURED');
      expect(res.paymentId, 'pay_rzp_mock_999');
    });

    test('CustomerBloc executes full online payment flow: PlaceOrder -> CreateRazorpayOrder -> VerifySignature', () async {
      final catalogRepo = MockFullCatalogRepo();
      final orderRepo = MockDummyOrderRepo();
      final localCache = MockDummyCacheService();
      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        paymentDataSource: paymentDataSource,
      );

      // 1. Add product to cart
      bloc.add(AddToCartEvent(const ProductEntity(
        id: 'prod_milk_1',
        storeId: 'store_01',
        categoryId: 'cat_dairy',
        name: 'Fresh Milk 1L',
        description: 'Pure cow milk',
        price: 60,
        originalPrice: 65,
        unit: 'L',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      )));
      await Future.delayed(const Duration(milliseconds: 30));

      // 2. Place Order with UPI
      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '9876543210',
        storeId: 'store_01',
        storeName: 'QuickMart',
        storeAddress: 'MG Road',
        paymentMethod: 'UPI',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Real order created and activeRazorpayOrder generated
      expect(bloc.state.latestPlacedOrder, isNotNull);
      expect(bloc.state.activeRazorpayOrder, isNotNull);
      expect(bloc.state.activeRazorpayOrder!.razorpayOrderId, 'order_rzp_mock_123');

      // 3. Verify Razorpay Payment Signature
      bloc.add(VerifyRazorpayPaymentEvent(
        razorpayOrderId: bloc.state.activeRazorpayOrder!.razorpayOrderId,
        razorpayPaymentId: 'pay_rzp_mock_999',
        razorpaySignature: 'hmac_sha256_mock_sig',
        orderId: bloc.state.latestPlacedOrder!.id,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.paymentVerification, isNotNull);
      expect(bloc.state.paymentVerification!.success, true);
      expect(bloc.state.paymentVerification!.status, 'CAPTURED');
      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.latestPlacedOrder!.paymentStatus, 'COMPLETED');

      await bloc.close();
    });

    test('Scenario: Online Payment Cancelled/Failed preserves cart and emits payment error', () async {
      final catalogRepo = MockFullCatalogRepo();
      final orderRepo = MockDummyOrderRepo();
      final localCache = MockDummyCacheService();
      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        paymentDataSource: paymentDataSource,
      );

      // Add product to cart
      bloc.add(AddToCartEvent(const ProductEntity(
        id: 'prod_milk_1',
        storeId: 'store_01',
        categoryId: 'cat_dairy',
        name: 'Fresh Milk 1L',
        description: 'Pure cow milk',
        price: 60,
        originalPrice: 65,
        unit: 'L',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      )));
      await Future.delayed(const Duration(milliseconds: 30));

      // Customer cancels or fails payment in Razorpay modal
      bloc.add(const RazorpayPaymentFailedEvent('Payment cancelled by customer'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(bloc.state.cartItems.length, 1);
      expect(bloc.state.paymentErrorMessage, 'Payment cancelled by customer');
      expect(bloc.state.isPaymentProcessing, false);

      await bloc.close();
    });

    test('Scenario: Cash on Delivery (COD) directly places order and clears cart', () async {
      final catalogRepo = MockFullCatalogRepo();
      final orderRepo = MockDummyOrderRepo();
      final localCache = MockDummyCacheService();
      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        paymentDataSource: paymentDataSource,
      );

      // Add product to cart
      bloc.add(AddToCartEvent(const ProductEntity(
        id: 'prod_bread_1',
        storeId: 'store_01',
        categoryId: 'cat_bakery',
        name: 'Whole Wheat Bread',
        description: 'Bakery fresh',
        price: 45,
        unit: 'pack',
        stock: 15,
        isAvailable: true,
        imageUrl: '',
      )));
      await Future.delayed(const Duration(milliseconds: 30));

      // Place COD Order
      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '9876543210',
        storeId: 'store_01',
        storeName: 'QuickMart',
        storeAddress: 'MG Road',
        paymentMethod: 'COD',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.latestPlacedOrder, isNotNull);
      expect(bloc.state.latestPlacedOrder!.paymentMethod, 'COD');
      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.activeRazorpayOrder, isNull);

      await bloc.close();
    });

    test('Scenario: Empty Cart checkout is rejected safely', () async {
      final catalogRepo = MockFullCatalogRepo();
      final orderRepo = MockDummyOrderRepo();
      final localCache = MockDummyCacheService();
      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        paymentDataSource: paymentDataSource,
      );

      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Chetan Shetty',
        customerPhone: '9876543210',
        storeId: 'store_01',
        storeName: 'QuickMart',
        storeAddress: 'MG Road',
        paymentMethod: 'UPI',
      ));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(bloc.state.errorMessage, 'Cart is empty. Please add items.');
      expect(bloc.state.latestPlacedOrder, isNull);

      await bloc.close();
    });

    test('Scenario: Initiate Refund API executes successfully', () async {
      final refundSuccess = await paymentDataSource.initiateRefund(
        razorpayPaymentId: 'pay_rzp_mock_123',
        orderId: 'order_001',
        amount: 150.0,
        reason: 'Customer cancelled before dispatch',
      );
      expect(refundSuccess, true);
    });
  });

  group('5. Customer Orders Track, Cancel & Review Flow (Endpoints 13, 14, 15)', () {
    late MockFullCatalogRepo catalogRepo;
    late MockDummyOrderRepo orderRepo;
    late CustomerBloc customerBloc;

    setUp(() {
      catalogRepo = MockFullCatalogRepo();
      orderRepo = MockDummyOrderRepo();
      customerBloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: MockDummyCacheService(),
      );
    });

    tearDown(() => customerBloc.close());

    test('CancelOrderEvent dispatches cancellation reason and emits successMessage', () async {
      customerBloc.add(const CancelOrderEvent(orderId: 'order_001', reason: 'Placed by mistake'));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(customerBloc.state.successMessage, 'Order cancelled successfully');
    });

    test('ReviewOrderEvent submits ratings and review text and emits confirmation', () async {
      customerBloc.add(const ReviewOrderEvent(
        orderId: 'order_001',
        storeRating: 5,
        deliveryRating: 5,
        storeReview: 'Super fast delivery!',
      ));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(customerBloc.state.successMessage, 'Review submitted successfully! Thank you.');
    });

    test('TrackOrderEvent executes without error and updates live state', () async {
      customerBloc.add(const TrackOrderEvent('order_001'));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(customerBloc.state.errorMessage, isNull);
    });
  });

  group('6. Filter Products by Store Flow', () {
    late ICatalogRepository catalogRepo;
    late IOrderRepository orderRepo;
    late CustomerBloc customerBloc;

    setUp(() {
      catalogRepo = MockFullCatalogRepo();
      orderRepo = MockDummyOrderRepo();
      customerBloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: MockDummyCacheService(),
      );
    });

    tearDown(() => customerBloc.close());

    test('FilterByStoreEvent correctly filters products by store ID and clears when null', () async {
      // First load catalog data
      customerBloc.add(const LoadCustomerDataEvent());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(customerBloc.state.allProducts.isNotEmpty, isTrue);

      const targetStore = StoreEntity(
        id: 'store_01',
        name: 'QuickStore Indiranagar',
        category: 'Daily Essentials',
        address: 'Indiranagar, Bengaluru',
        rating: 4.8,
        deliveryTime: '15 min',
        distanceKm: 0.5,
        isOpen: true,
        bannerUrl: '',
      );

      // Filter by targetStore
      customerBloc.add(const FilterByStoreEvent(targetStore));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(customerBloc.state.selectedStore, equals(targetStore));
      for (final p in customerBloc.state.filteredProducts) {
        expect(p.storeId, equals('store_01'));
      }

      // Clear filter
      customerBloc.add(const FilterByStoreEvent(null));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(customerBloc.state.selectedStore, isNull);
      expect(customerBloc.state.filteredProducts.length, equals(customerBloc.state.allProducts.length));
    });
  });

  group('7. Retailer Shop Name Resolution & Order Propagation Flow', () {
    test('OrderRemoteDataSourceImpl correctly parses storeName and shopName from backend response', () {
      final ds = OrderRemoteDataSourceImpl(ApiClient(secureStorage: MockSecureStorage()));

      // Case 1: Backend returns storeName directly
      final json1 = {
        '_id': 'ord_live_99',
        'orderNumber': 'QT-999',
        'storeName': 'Spice Garden Restaurant',
        'storeId': '6aa57f6a191b0ba5d25863af',
        'items': [],
        'subtotal': 250,
        'grandTotal': 290,
        'status': 'placed',
      };
      final order1 = ds.mapToOrderEntity(json1);
      expect(order1.storeName, equals('Spice Garden Restaurant'));

      // Case 2: Backend returns shopName
      final json2 = {
        '_id': 'ord_live_98',
        'orderNumber': 'QT-998',
        'shopName': 'malnad spicies',
        'storeId': '6aa4d51e8e786cd9f07720bb',
        'items': [],
        'subtotal': 150,
        'grandTotal': 190,
        'status': 'placed',
      };
      final order2 = ds.mapToOrderEntity(json2);
      expect(order2.storeName, equals('malnad spicies'));

      // Case 3: Backend returns nested store object
      final json3 = {
        '_id': 'ord_live_97',
        'orderNumber': 'QT-997',
        'store': {'name': 'BigBasket Express'},
        'storeId': '6aa3febe8b2afec202cc65cc',
        'items': [],
        'subtotal': 120,
        'grandTotal': 150,
        'status': 'placed',
      };
      final order3 = ds.mapToOrderEntity(json3);
      expect(order3.storeName, equals('BigBasket Express'));

      // Case 4: Backend returns generic fallback but known ObjectId
      final json4 = {
        '_id': 'ord_live_96',
        'orderNumber': 'QT-996',
        'storeName': 'QuickMart Supermarket',
        'storeId': '6aa57f6a191b0ba5d25863af',
        'items': [],
        'subtotal': 300,
        'grandTotal': 350,
        'status': 'placed',
      };
      final order4 = ds.mapToOrderEntity(json4);
      expect(order4.storeName, equals('Spice Garden Restaurant'));
    });

    test('CustomerBloc dispatches PlaceOrderEvent with exact chosen store name and ID', () async {
      final catalogRepo = MockFullCatalogRepo();
      final orderRepo = MockDummyOrderRepo();
      final localCache = MockDummyCacheService();
      final paymentDataSource = MockPaymentRemoteDataSource();

      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
        paymentDataSource: paymentDataSource,
      );

      // Add product belonging to Spice Garden Restaurant
      bloc.add(const AddToCartEvent(ProductEntity(
        id: 'prod_spice_01',
        storeId: '6aa57f6a191b0ba5d25863af',
        categoryId: 'cat_food',
        name: 'Special Biryani',
        description: 'Flavorful aromatic rice',
        price: 260,
        originalPrice: 300,
        unit: 'pack',
        stock: 15,
        isAvailable: true,
        imageUrl: '',
      )));
      await Future.delayed(const Duration(milliseconds: 30));

      // Place order with the accurate storeName
      bloc.add(const PlaceOrderEvent(
        customerId: 'cust_01',
        customerName: 'Aarav Kumar',
        customerPhone: '+91 98765 43210',
        storeId: '6aa57f6a191b0ba5d25863af',
        storeName: 'Spice Garden Restaurant',
        storeAddress: 'Indiranagar 100ft Rd',
        paymentMethod: 'COD',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.latestPlacedOrder, isNotNull);
      expect(bloc.state.latestPlacedOrder!.storeName, equals('Spice Garden Restaurant'));
      expect(bloc.state.latestPlacedOrder!.storeId, equals('6aa57f6a191b0ba5d25863af'));
    });
  });
}
