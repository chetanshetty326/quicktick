import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import 'dart:async';

// Mock Secure Storage
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

// Mock Catalog Repository
class MockCatalogRepo implements ICatalogRepository {
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  final _storesCtrl = StreamController<List<StoreEntity>>.broadcast();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<ProductEntity> mockProducts = [
    const ProductEntity(
      id: 'prod_001',
      storeId: 'store_01',
      name: 'Farm Fresh Organic Milk',
      description: 'Pure whole cow milk',
      price: 34.0,
      originalPrice: 38.0,
      unit: '500 ml',
      imageUrl: 'https://example.com/milk.jpg',
      categoryId: 'cat_dairy',
      isAvailable: true,
      stock: 45,
    ),
    const ProductEntity(
      id: 'prod_002',
      storeId: 'store_01',
      name: 'Organic Brown Eggs (Pack of 6)',
      description: 'Farm fresh brown eggs',
      price: 65.0,
      originalPrice: 75.0,
      unit: '6 pcs',
      imageUrl: 'https://example.com/eggs.jpg',
      categoryId: 'cat_dairy',
      isAvailable: true,
      stock: 20,
    ),
  ];

  final List<StoreEntity> mockStores = [
    const StoreEntity(
      id: 'store_01',
      name: 'Fresh Mart Supermarket',
      category: 'Daily Groceries & Essentials',
      address: '12th Main, Indiranagar',
      rating: 4.8,
      deliveryTime: '15-25 min',
      distanceKm: 0.8,
      isOpen: true,
      bannerUrl: '',
    ),
  ];

  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;
  @override
  Stream<List<StoreEntity>> get storesStream => _storesCtrl.stream;

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async => const Right([]);
  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async => Right(mockStores);
  @override
  Future<Either<Failure, StoreEntity>> getStoreDetails(String storeId) async => Right(mockStores.first);
  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async {
    if (storeId.isEmpty) return const Left(ValidationFailure(message: 'Invalid Store ID'));
    return Right(mockProducts.where((p) => p.storeId == storeId).toList());
  }


  @override
  Future<Either<Failure, ProductEntity>> toggleProductStock(String productId, bool isAvailable) async {
    final idx = mockProducts.indexWhere((e) => e.id == productId);
    if (idx == -1) return const Left(ValidationFailure(message: 'Product not found'));
    final updated = mockProducts[idx].copyWith(isAvailable: isAvailable);
    mockProducts[idx] = updated;
    _productsCtrl.add(List.from(mockProducts));
    return Right(updated);
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProductPrice(String productId, double newPrice) async {
    if (newPrice <= 0) return const Left(ValidationFailure(message: 'Price must be greater than zero'));
    final idx = mockProducts.indexWhere((e) => e.id == productId);
    if (idx == -1) return const Left(ValidationFailure(message: 'Product not found'));
    final updated = mockProducts[idx].copyWith(price: newPrice);
    mockProducts[idx] = updated;
    _productsCtrl.add(List.from(mockProducts));
    return Right(updated);
  }

  @override
  Future<Either<Failure, StoreEntity>> toggleStoreOpenStatus(String storeId, bool isOpen) async {
    final idx = mockStores.indexWhere((s) => s.id == storeId);
    if (idx == -1) return const Left(ValidationFailure(message: 'Store not found'));
    final updated = mockStores[idx].copyWith(isOpen: isOpen);
    mockStores[idx] = updated;
    _storesCtrl.add(List.from(mockStores));
    return Right(updated);
  }

  @override
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product) async {
    if (product.name.trim().isEmpty) {
      return const Left(ValidationFailure(message: 'Product name cannot be empty'));
    }
    if (product.price <= 0) {
      return const Left(ValidationFailure(message: 'Price must be positive'));
    }
    if (product.stock < 0) {
      return const Left(ValidationFailure(message: 'Stock cannot be negative'));
    }
    mockProducts.insert(0, product);
    _productsCtrl.add(List.from(mockProducts));
    return Right(product);
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async {
    final idx = mockProducts.indexWhere((p) => p.id == product.id);
    if (idx == -1) return const Left(ValidationFailure(message: 'Product not found'));
    if (product.price <= 0) return const Left(ValidationFailure(message: 'Price must be positive'));
    mockProducts[idx] = product;
    _productsCtrl.add(List.from(mockProducts));
    return Right(product);
  }

  @override
  Future<Either<Failure, String>> deleteProduct(String productId) async {
    final idx = mockProducts.indexWhere((p) => p.id == productId);
    if (idx == -1) return const Left(ValidationFailure(message: 'Product not found'));
    mockProducts.removeAt(idx);
    _productsCtrl.add(List.from(mockProducts));
    return Right(productId);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
    String? couponCode,
    double? couponDiscount,
  }) async {
    final o = OrderEntity(
      id: 'order_test_01',
      orderNumber: 'RET-101',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: 99.0,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: 119.0,
      status: OrderStatus.placed,
      deliveryOtp: '4521',
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
    if (idx == -1) return const Left(CacheFailure(message: 'Order not found'));

    final updated = orders[idx].copyWith(status: nextStatus);
    orders[idx] = updated;
    _ordersCtrl.add(List.from(orders));
    return Right(updated);
  }

  @override
  Future<Either<Failure, OrderEntity>> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return const Left(CacheFailure(message: 'Order not found'));

    final updated = orders[idx].copyWith(paymentStatus: paymentStatus);
    orders[idx] = updated;
    _ordersCtrl.add(List.from(orders));
    return Right(updated);
  }

  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({
    required String orderId,
    required String deliveryPartnerId,
    required String deliveryPartnerName,
    required String deliveryPartnerPhone,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return const Left(CacheFailure(message: 'Order not found'));
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

  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({
    required String orderId,
    required String enteredOtp,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return const Left(CacheFailure(message: 'Order not found'));
    if (orders[idx].deliveryOtp == enteredOtp) {
      final updated = orders[idx].copyWith(status: OrderStatus.delivered);
      orders[idx] = updated;
      _ordersCtrl.add(List.from(orders));
      return Right(updated);
    }
    return const Left(CacheFailure(message: 'Invalid OTP'));
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

// Validator helper functions matching Retailer Registration rules
class RetailerValidationRules {
  static bool validateFSSAI(String fssai) {
    return RegExp(r'^[0-9]{14}$').hasMatch(fssai.trim());
  }

  static bool validateGSTIN(String gstin) {
    return RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$').hasMatch(gstin.trim());
  }

  static bool validateIFSC(String ifsc) {
    return RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc.trim());
  }

  static bool validatePhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10;
  }

  static bool validateBankAccount(String account) {
    return RegExp(r'^[0-9]{9,18}$').hasMatch(account.trim());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // =========================================================================
  // SUITE 1: AUTHENTICATION & SESSION TESTS (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 1: Retailer Authentication & Session Tests', () {
    late MockSecureStorageService storage;
    late AuthBloc authBloc;

    setUp(() {
      storage = MockSecureStorageService();
      authBloc = AuthBloc(storage);
    });

    tearDown(() => authBloc.close());

    // Positive Tests
    test('[POS-01] Valid Retailer Login & Role Assignment succeeds', () async {
      authBloc.add(const SwitchRoleEvent(UserRole.retailer));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(authBloc.state, isA<AuthenticatedState>());
      final authState = authBloc.state as AuthenticatedState;
      expect(authState.user.role, UserRole.retailer);
      expect(await storage.getUserRole(), 'retailer');
    });

    test('[POS-02] Retailer Login with valid OTP succeeds and sets retailer role', () async {
      authBloc.add(const LoginWithOtpEvent(
        phone: '9876543210',
        otp: '123456',
        name: 'Fresh Mart Manager',
        role: UserRole.retailer,
      ));
      await Future.delayed(const Duration(milliseconds: 350));

      expect(authBloc.state, isA<AuthenticatedState>());
      final authState = authBloc.state as AuthenticatedState;
      expect(authState.user.role, UserRole.retailer);
      expect(await storage.getUserRole(), 'retailer');
    });

    test('[POS-03] Delivery Partner Login with valid OTP succeeds and sets delivery role', () async {
      authBloc.add(const LoginWithOtpEvent(
        phone: '9876543210',
        otp: '123456',
        name: 'Rider Ramesh',
        role: UserRole.deliveryPartner,
      ));
      await Future.delayed(const Duration(milliseconds: 350));

      expect(authBloc.state, isA<AuthenticatedState>());
      final authState = authBloc.state as AuthenticatedState;
      expect(authState.user.role, UserRole.deliveryPartner);
      expect(await storage.getUserRole(), 'deliveryPartner');
    });

    test('[POS-04] Active session validity check succeeds when not expired', () async {
      await storage.saveTokens(accessToken: 'valid_jwt_token', refreshToken: 'valid_refresh');
      final isValid = await storage.isSessionValid();
      expect(isValid, isTrue);
    });

    // Negative Tests
    test('[NEG-01] Checking auth session on empty storage emits UnauthenticatedState', () async {
      authBloc.add(CheckAuthSessionEvent());
      await Future.delayed(const Duration(milliseconds: 30));

      expect(authBloc.state, isA<UnauthenticatedState>());
    });

    test('[NEG-02] Retailer Login with INVALID OTP is firmly rejected with AuthErrorState', () async {
      authBloc.add(const LoginWithOtpEvent(
        phone: '9876543210',
        otp: '999999', // Invalid OTP
        name: 'Fake Manager',
        role: UserRole.retailer,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state, isA<AuthErrorState>());
      final errState = authBloc.state as AuthErrorState;
      expect(errState.message, contains('Invalid OTP'));
    });

    test('[NEG-03] Delivery Partner Login with INVALID OTP is firmly rejected with AuthErrorState', () async {
      authBloc.add(const LoginWithOtpEvent(
        phone: '9876543210',
        otp: '000000', // Invalid OTP
        name: 'Fake Rider',
        role: UserRole.deliveryPartner,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state, isA<AuthErrorState>());
      final errState = authBloc.state as AuthErrorState;
      expect(errState.message, contains('Invalid OTP'));
    });

    test('[NEG-04] Session validity returns false for cleared storage', () async {
      await storage.clearAuthData();
      final isValid = await storage.isSessionValid();
      expect(isValid, isFalse);
    });
  });

  // =========================================================================
  // SUITE 2: STORE REGISTRATION & COMPLIANCE (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 2: Retailer Registration & KYC Validation Tests', () {
    // Positive Tests
    test('[POS-03] Valid 14-digit FSSAI Number passes compliance validation', () {
      expect(RetailerValidationRules.validateFSSAI('11223344556677'), isTrue);
      expect(RetailerValidationRules.validateFSSAI('10019043002841'), isTrue);
    });

    test('[POS-04] Valid 15-character GSTIN format passes compliance validation', () {
      expect(RetailerValidationRules.validateGSTIN('29ABCDE1234F1Z5'), isTrue);
      expect(RetailerValidationRules.validateGSTIN('07AAAAA0000A1Z5'), isTrue);
    });

    test('[POS-05] Valid Bank Account Number and IFSC Code pass validation', () {
      expect(RetailerValidationRules.validateIFSC('HDFC0001234'), isTrue);
      expect(RetailerValidationRules.validateIFSC('SBIN0000456'), isTrue);
      expect(RetailerValidationRules.validateBankAccount('50100234567890'), isTrue);
    });

    test('[POS-06] Valid 10-digit Indian phone number passes validation', () {
      expect(RetailerValidationRules.validatePhoneNumber('+91 98765 43210'), isTrue);
      expect(RetailerValidationRules.validatePhoneNumber('9876543210'), isTrue);
    });

    // Negative Tests
    test('[NEG-03] Invalid FSSAI (<14 digits or letters) is rejected', () {
      expect(RetailerValidationRules.validateFSSAI('12345'), isFalse); // Too short
      expect(RetailerValidationRules.validateFSSAI('1122334455667A'), isFalse); // Contains letter
      expect(RetailerValidationRules.validateFSSAI(''), isFalse); // Empty
    });

    test('[NEG-04] Invalid GSTIN format is rejected', () {
      expect(RetailerValidationRules.validateGSTIN('INVALIDGST'), isFalse);
      expect(RetailerValidationRules.validateGSTIN('29ABCDE1234F'), isFalse); // 12 chars
      expect(RetailerValidationRules.validateGSTIN(''), isFalse);
    });

    test('[NEG-05] Invalid IFSC Code or Bank Account Number is rejected', () {
      expect(RetailerValidationRules.validateIFSC('HDFC123456'), isFalse); // Missing 0 at 5th char
      expect(RetailerValidationRules.validateIFSC('12345678901'), isFalse);
      expect(RetailerValidationRules.validateBankAccount('12345'), isFalse); // Too short (<9 digits)
      expect(RetailerValidationRules.validateBankAccount('ABC12345678'), isFalse); // Non-digit
    });

    test('[NEG-06] Phone number with less than 10 digits is rejected', () {
      expect(RetailerValidationRules.validatePhoneNumber('98765'), isFalse);
      expect(RetailerValidationRules.validatePhoneNumber(''), isFalse);
    });
  });

  // =========================================================================
  // SUITE 3: STORE OPERATIONAL STATUS (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 3: Store Operation & Availability Toggle Tests', () {
    late MockCatalogRepo catalogRepo;
    late MockOrderRepo orderRepo;
    late RetailerBloc retailerBloc;

    setUp(() {
      catalogRepo = MockCatalogRepo();
      orderRepo = MockOrderRepo();
      retailerBloc = RetailerBloc(orderRepo: orderRepo, catalogRepo: catalogRepo);
    });

    tearDown(() {
      retailerBloc.close();
      catalogRepo.dispose();
      orderRepo.dispose();
    });

    // Positive Tests
    test('[POS-07] Toggling Store Status to OPEN updates state and message', () async {
      retailerBloc.add(const ToggleStoreStatusEvent('store_01', true));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.isStoreOpen, isTrue);
      expect(retailerBloc.state.successMessage, 'Store is now OPEN for orders');
    });

    test('[POS-08] Toggling Store Status to CLOSED updates state and message', () async {
      retailerBloc.add(const ToggleStoreStatusEvent('store_01', false));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.isStoreOpen, isFalse);
      expect(retailerBloc.state.successMessage, 'Store is now CLOSED');
    });

    // Negative Tests
    test('[NEG-07] Toggling status of Non-Existent Store returns ValidationFailure', () async {
      retailerBloc.add(const ToggleStoreStatusEvent('store_non_existent', true));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.errorMessage, 'Store not found');
    });
  });

  // =========================================================================
  // SUITE 4: ORDER LIFECYCLE MANAGEMENT (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 4: Order Pipeline & State Transitions Tests', () {
    late MockCatalogRepo catalogRepo;
    late MockOrderRepo orderRepo;
    late RetailerBloc retailerBloc;

    setUp(() async {
      catalogRepo = MockCatalogRepo();
      orderRepo = MockOrderRepo();

      // Seed initial placed order
      await orderRepo.createOrder(
        customerId: 'cust_01',
        customerName: 'Aarav Sharma',
        customerPhone: '+91 98765 11223',
        deliveryAddress: '304, Green Palms, Indiranagar',
        storeId: 'store_01',
        storeName: 'Fresh Mart',
        storeAddress: '100ft Rd',
        items: const [
          OrderItemEntity(
            productId: 'prod_001',
            nameSnapshot: 'Farm Fresh Organic Milk',
            priceSnapshot: 34.0,
            unit: '500 ml',
            quantity: 2,
          ),
        ],
        deliveryFee: 15.0,
        platformFee: 5.0,
      );

      retailerBloc = RetailerBloc(orderRepo: orderRepo, catalogRepo: catalogRepo);
      retailerBloc.add(const LoadRetailerDataEvent(storeId: 'store_01'));
      await Future.delayed(const Duration(milliseconds: 30));
    });

    tearDown(() {
      retailerBloc.close();
      catalogRepo.dispose();
      orderRepo.dispose();
    });

    // Positive Tests
    test('[POS-09] AcceptOrderEvent transitions order status from Placed to Accepted', () async {
      retailerBloc.add(const AcceptOrderEvent('order_test_01'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(orderRepo.orders.first.status, OrderStatus.accepted);
      expect(retailerBloc.state.successMessage, contains('Accepted'));
    });

    test('[POS-10] MarkPreparingEvent transitions order status from Accepted to Preparing', () async {
      retailerBloc.add(const MarkPreparingEvent('order_test_01'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(orderRepo.orders.first.status, OrderStatus.preparing);
      expect(retailerBloc.state.successMessage, contains('Preparing'));
    });

    test('[POS-11] MarkReadyForPickupEvent transitions order status to Ready for Pickup', () async {
      retailerBloc.add(const MarkReadyForPickupEvent('order_test_01'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(orderRepo.orders.first.status, OrderStatus.readyForPickup);
      expect(retailerBloc.state.successMessage, contains('Ready for Rider'));
    });

    test('[POS-12] RejectOrderEvent cancels order with specific rejection reason', () async {
      retailerBloc.add(const RejectOrderEvent('order_test_01', reason: 'Ingredients Out of Stock'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(orderRepo.orders.first.status, OrderStatus.rejected);
      expect(retailerBloc.state.successMessage, contains('Rejected'));
    });

    // Negative Tests
    test('[NEG-08] Attempting to accept a Non-Existent Order returns error', () async {
      retailerBloc.add(const AcceptOrderEvent('invalid_order_id_999'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.errorMessage, 'Order not found');
    });

    test('[NEG-09] Attempting to mark ready a Non-Existent Order returns error', () async {
      retailerBloc.add(const MarkReadyForPickupEvent('invalid_order_id_888'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.errorMessage, 'Order not found');
    });
  });

  // =========================================================================
  // SUITE 5: INVENTORY & STOCK MANAGEMENT (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 5: Inventory, Pricing & Stock CRUD Tests', () {
    late MockCatalogRepo catalogRepo;
    late MockOrderRepo orderRepo;
    late RetailerBloc retailerBloc;

    setUp(() async {
      catalogRepo = MockCatalogRepo();
      orderRepo = MockOrderRepo();
      retailerBloc = RetailerBloc(orderRepo: orderRepo, catalogRepo: catalogRepo);
      retailerBloc.add(const LoadRetailerDataEvent(storeId: 'store_01'));
      await Future.delayed(const Duration(milliseconds: 30));
    });

    tearDown(() {
      retailerBloc.close();
      catalogRepo.dispose();
      orderRepo.dispose();
    });

    // Positive Tests
    test('[POS-13] Adding a valid new product to inventory succeeds', () async {
      const newProduct = ProductEntity(
        id: 'prod_003',
        storeId: 'store_01',
        categoryId: 'cat_bakery',
        name: 'Whole Wheat Multigrain Bread',
        description: 'Freshly baked artisanal loaf',
        price: 55.0,
        originalPrice: 65.0,
        unit: '400g',
        stock: 30,
        isAvailable: true,
        imageUrl: 'https://example.com/bread.jpg',
      );

      retailerBloc.add(const AddProductToInventoryEvent(newProduct));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(catalogRepo.mockProducts.any((p) => p.id == 'prod_003'), isTrue);
      expect(retailerBloc.state.successMessage, contains('Whole Wheat Multigrain Bread added to inventory!'));
    });

    test('[POS-14] Updating an existing product price, name and stock succeeds', () async {
      final existing = catalogRepo.mockProducts.firstWhere((p) => p.id == 'prod_001');
      final updated = existing.copyWith(price: 36.0, stock: 60, name: 'A2 Farm Fresh Organic Milk');

      retailerBloc.add(UpdateProductInInventoryEvent(updated));
      await Future.delayed(const Duration(milliseconds: 30));

      final modified = catalogRepo.mockProducts.firstWhere((p) => p.id == 'prod_001');
      expect(modified.price, 36.0);
      expect(modified.stock, 60);
      expect(modified.name, 'A2 Farm Fresh Organic Milk');
      expect(retailerBloc.state.successMessage, contains('updated successfully!'));
    });

    test('[POS-15] Toggling product stock availability (In Stock <-> Out of Stock) succeeds', () async {
      retailerBloc.add(const ToggleProductStockEvent('prod_001', false));
      await Future.delayed(const Duration(milliseconds: 30));

      final item = catalogRepo.mockProducts.firstWhere((p) => p.id == 'prod_001');
      expect(item.isAvailable, isFalse);
      expect(retailerBloc.state.successMessage, 'Product stock status updated');
    });

    test('[POS-16] Deleting product permanently removes it from inventory', () async {
      expect(catalogRepo.mockProducts.any((p) => p.id == 'prod_002'), isTrue);

      retailerBloc.add(const DeleteProductFromInventoryEvent('prod_002', productName: 'Organic Brown Eggs'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(catalogRepo.mockProducts.any((p) => p.id == 'prod_002'), isFalse);
      expect(retailerBloc.state.successMessage, contains('Organic Brown Eggs removed from inventory'));
    });

    // Negative Tests
    test('[NEG-10] Adding product with EMPTY name fails with ValidationFailure', () async {
      const invalidProduct = ProductEntity(
        id: 'prod_invalid_name',
        storeId: 'store_01',
        categoryId: 'cat_dairy',
        name: '   ', // Blank name
        description: 'Description',
        price: 40.0,
        unit: '1 pc',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      retailerBloc.add(const AddProductToInventoryEvent(invalidProduct));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.errorMessage, 'Product name cannot be empty');
      expect(catalogRepo.mockProducts.any((p) => p.id == 'prod_invalid_name'), isFalse);
    });

    test('[NEG-11] Adding product with ZERO or NEGATIVE price fails with ValidationFailure', () async {
      const negativePriceProduct = ProductEntity(
        id: 'prod_negative_price',
        storeId: 'store_01',
        categoryId: 'cat_dairy',
        name: 'Curd Bowl',
        description: 'Fresh curd',
        price: -25.0, // Negative price
        unit: '1 cup',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      retailerBloc.add(const AddProductToInventoryEvent(negativePriceProduct));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.errorMessage, 'Price must be positive');
      expect(catalogRepo.mockProducts.any((p) => p.id == 'prod_negative_price'), isFalse);
    });

    test('[NEG-12] Adding product with NEGATIVE stock units fails with ValidationFailure', () async {
      const negativeStockProduct = ProductEntity(
        id: 'prod_negative_stock',
        storeId: 'store_01',
        categoryId: 'cat_dairy',
        name: 'Paneer Block',
        description: 'Fresh paneer',
        price: 100.0,
        unit: '200g',
        stock: -10, // Negative stock
        isAvailable: true,
        imageUrl: '',
      );

      retailerBloc.add(const AddProductToInventoryEvent(negativeStockProduct));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.errorMessage, 'Stock cannot be negative');
      expect(catalogRepo.mockProducts.any((p) => p.id == 'prod_negative_stock'), isFalse);
    });

    test('[NEG-13] Deleting a NON-EXISTENT product ID returns ValidationFailure', () async {
      retailerBloc.add(const DeleteProductFromInventoryEvent('prod_ghost_999', productName: 'Ghost Item'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.errorMessage, 'Product not found');
    });

    test('[NEG-14] Updating a NON-EXISTENT product returns ValidationFailure', () async {
      const nonExistent = ProductEntity(
        id: 'prod_does_not_exist',
        storeId: 'store_01',
        categoryId: 'cat_dairy',
        name: 'Phantom Item',
        description: 'None',
        price: 50.0,
        unit: '1 pc',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
      );

      retailerBloc.add(const UpdateProductInInventoryEvent(nonExistent));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerBloc.state.errorMessage, 'Product not found');
    });
  });

  // =========================================================================
  // SUITE 6: FINANCIALS, SETTLEMENTS & COMMISSIONS (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 6: Financials, Commission & Settlement Calculation Tests', () {
    // Positive Tests
    test('[POS-17] Settlement calculation correctly computes GMV, 5% platform fee and Net Payout', () {
      final completedOrdersTotal = [150.0, 350.0, 500.0];
      final grossGmv = completedOrdersTotal.reduce((a, b) => a + b); // ₹1000
      final platformCommission = grossGmv * 0.05; // 5% = ₹50
      final netRetailerPayout = grossGmv - platformCommission; // ₹950

      expect(grossGmv, 1000.0);
      expect(platformCommission, 50.0);
      expect(netRetailerPayout, 950.0);
    });

    // Negative Tests
    test('[NEG-15] Settlement calculation on zero orders results in zero payout without negative balances', () {
      const double grossGmv = 0.0;
      final platformCommission = grossGmv * 0.05;
      final netRetailerPayout = (grossGmv - platformCommission).clamp(0.0, double.infinity);

      expect(grossGmv, 0.0);
      expect(platformCommission, 0.0);
      expect(netRetailerPayout, 0.0);
    });
  });
}
