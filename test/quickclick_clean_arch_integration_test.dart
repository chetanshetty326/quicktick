import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/error/user_suspended_exception.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_entities.dart';
import 'package:quicklink/features/retailer/domain/repositories/retailer_repository.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_api_entities.dart';
import 'package:quicklink/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/customer/data/models/product_model.dart';
import 'dart:async';

class FakeSuspendedAuthRemoteDataSource implements IAuthRemoteDataSource {
  @override
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? challengeId,
  }) async {
    throw const UserSuspendedException('Account suspended for compliance violation');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSecureStorage implements ISecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCatalogRepo implements ICatalogRepository {
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  final _storesCtrl = StreamController<List<StoreEntity>>.broadcast();

  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;
  @override
  Stream<List<StoreEntity>> get storesStream => _storesCtrl.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCacheService implements ILocalCacheService {
  @override
  Future<List<Map<String, dynamic>>> reloadAndGetCachedOrders() async => [];
  @override
  Future<void> saveCartItems(List<dynamic> items) async {}
  @override
  List<Map<String, dynamic>> getCartItems() => [];
  @override
  Future<void> clearCart() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOrderRepo implements IOrderRepository {
  final _ordersCtrl = StreamController<List<OrderEntity>>.broadcast();
  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersCtrl.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRetailerRepo implements IRetailerRepository {
  final _ordersCtrl = StreamController<List<OrderEntity>>.broadcast();
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();

  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersCtrl.stream;
  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;

  @override
  Future<Either<Failure, RetailerSubscriptionEntity>> getSubscription() async {
    return const Right(RetailerSubscriptionEntity(
      id: 'sub_expired_1',
      planName: 'Starter Free',
      status: 'EXPIRED',
      isFreeTier: false,
      price: 999.0,
      commissionPercent: 5.0,
      daysRemaining: 0,
      isTrial: false,
      canAcceptOrders: false,
    ));
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async {
    return Right(product);
  }

  @override
  Future<Either<Failure, bool>> toggleProductStock(String productId, bool isAvailable, {int? currentStock}) async {
    return const Right(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDeliveryRepo implements IDeliveryRepository {
  bool getJobsCalled = false;

  @override
  Future<Either<Failure, List<DeliveryJobEntity>>> getJobs({String filter = 'all'}) async {
    getJobsCalled = true;
    return const Right([]);
  }

  @override
  Future<Either<Failure, bool>> rejectJob({required String jobId, required String reason}) async {
    return const Right(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickClick Clean Architecture Integration Tests', () {
    test('1. AuthBloc emits UserSuspendedState when remote throws UserSuspendedException', () async {
      final authBloc = AuthBloc(
        FakeSecureStorage(),
        FakeSuspendedAuthRemoteDataSource(),
      );

      final states = <AuthState>[];
      final sub = authBloc.stream.listen(states.add);

      authBloc.add(const LoginWithOtpEvent(
        phone: '9876543210',
        otp: '999999',
        role: UserRole.customer,
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.any((s) => s is UserSuspendedState), isTrue);
      final suspendedState = states.firstWhere((s) => s is UserSuspendedState) as UserSuspendedState;
      expect(suspendedState.message, contains('Account suspended'));

      await sub.cancel();
      await authBloc.close();
    });

    test('2. CustomerBloc dietary filter accurately filters products by foodType', () async {
      final catalogRepo = FakeCatalogRepo();
      final cacheService = FakeCacheService();
      final orderRepo = FakeOrderRepo();

      final customerBloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: cacheService,
      );

      const pVeg = ProductEntity(
        id: 'p1',
        storeId: 's1',
        name: 'Veg Salad',
        description: 'Fresh salad',
        price: 100,
        unit: 'bowl',
        imageUrl: '',
        categoryId: 'cat_food',
        foodType: 'VEG',
        stock: 25,
        isAvailable: true,
      );
      const pNonVeg = ProductEntity(
        id: 'p2',
        storeId: 's1',
        name: 'Chicken Burger',
        description: 'Crispy burger',
        price: 180,
        unit: 'pc',
        imageUrl: '',
        categoryId: 'cat_food',
        foodType: 'NON_VEG',
        stock: 15,
        isAvailable: true,
      );

      customerBloc.emit(customerBloc.state.copyWith(
        allProducts: [pVeg, pNonVeg],
        filteredProducts: [pVeg, pNonVeg],
      ));

      // Apply VEG dietary filter
      customerBloc.add(const ApplyProductFiltersEvent(foodType: 'VEG'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(customerBloc.state.selectedFoodType, 'VEG');
      expect(customerBloc.state.filteredProducts.length, 1);
      expect(customerBloc.state.filteredProducts.first.foodType, 'VEG');

      // Apply NON_VEG dietary filter
      customerBloc.add(const ApplyProductFiltersEvent(foodType: 'NON_VEG'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(customerBloc.state.selectedFoodType, 'NON_VEG');
      expect(customerBloc.state.filteredProducts.length, 1);
      expect(customerBloc.state.filteredProducts.first.foodType, 'NON_VEG');

      await customerBloc.close();
    });

    test('3. RetailerBloc guards order transitions when subscription is expired', () async {
      final retailerBloc = RetailerBloc(
        orderRepo: FakeOrderRepo(),
        catalogRepo: FakeCatalogRepo(),
        retailerRepo: FakeRetailerRepo(),
      );

      // Set subscription as expired
      retailerBloc.emit(retailerBloc.state.copyWith(
        subscription: const RetailerSubscriptionEntity(
          id: 'sub_exp',
          planName: 'Starter',
          status: 'EXPIRED',
          isFreeTier: false,
          price: 999,
          commissionPercent: 5.0,
          daysRemaining: 0,
          isTrial: false,
          canAcceptOrders: false,
        ),
      ));

      // Guarded transition: Accept Order
      retailerBloc.add(const AcceptOrderEvent('ord_100'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(retailerBloc.state.showSubscriptionRequiredSheet, isTrue);

      // Dismiss sheet
      retailerBloc.add(const DismissSubscriptionRequiredSheetEvent());
      await Future.delayed(const Duration(milliseconds: 20));
      expect(retailerBloc.state.showSubscriptionRequiredSheet, isFalse);

      await retailerBloc.close();
    });

    test('4. DeliveryBloc automatically triggers FetchDeliveryJobsEvent on DeclineDeliveryJobEvent', () async {
      final deliveryRepo = FakeDeliveryRepo();
      final orderRepo = FakeOrderRepo();
      final deliveryBloc = DeliveryBloc(
        orderRepo: orderRepo,
        deliveryRepo: deliveryRepo,
      );

      deliveryBloc.add(const DeclineDeliveryJobEvent('job_99', reason: 'Too far'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(deliveryRepo.getJobsCalled, isTrue);

      await deliveryBloc.close();
    });

    test('5. OrderEntity accurately parses the backend deliveryPartner and rider object', () {
      final jsonResponse = {
        '_id': 'ord_test_dp',
        'orderNumber': 'QC-261010-0031',
        'customerId': 'cust_1',
        'customerName': 'Aman Gupta',
        'customerPhone': '9876543210',
        'deliveryAddress': 'HSR Layout Sector 2',
        'storeId': 'store_1',
        'storeName': 'Daily Mart',
        'status': 'OUT_FOR_DELIVERY',
        'items': [],
        'subtotal': 300,
        'grandTotal': 330,
        'deliveryPartnerId': '6aca5ee537118c1a66ba0f76',
        'deliveryPartner': {
          '_id': '6aca5ee537118c1a66ba0f76',
          'name': 'Rama',
          'phone': '9535746411',
          'avatarUrl': 'https://example.com/avatar.jpg',
          'rating': 4.8,
          'totalDeliveries': 42,
          'vehicleType': 'SCOOTER',
          'vehicleNumber': 'KA18D5055',
          'latitude': 13.7272768,
          'longitude': 76.0074385,
          'updatedAt': '2026-10-11T10:47:47.488Z',
        },
      };

      final order = OrderEntity.fromJson(jsonResponse);

      // Verify Entity population
      expect(order.deliveryPartner, isNotNull);
      expect(order.deliveryPartner!.id, '6aca5ee537118c1a66ba0f76');
      expect(order.deliveryPartner!.name, 'Rama');
      expect(order.deliveryPartner!.phone, '9535746411');
      expect(order.deliveryPartner!.avatarUrl, 'https://example.com/avatar.jpg');
      expect(order.deliveryPartner!.rating, 4.8);
      expect(order.deliveryPartner!.totalDeliveries, 42);
      expect(order.deliveryPartner!.vehicleType, 'SCOOTER');
      expect(order.deliveryPartner!.vehicleNumber, 'KA18D5055');
      expect(order.deliveryPartner!.latitude, 13.7272768);
      expect(order.deliveryPartner!.longitude, 76.0074385);

      // Verify Backward Compatibility with legacy accessors
      expect(order.deliveryPartnerId, '6aca5ee537118c1a66ba0f76');
      expect(order.deliveryPartnerName, 'Rama');
      expect(order.deliveryPartnerPhone, '9535746411');
    });

    test('6. ProductModel.fromJson accurately maps stock and pricing without arbitrary 50 default or price inversion', () {
      final jsonWithStock = {
        '_id': 'prod_101',
        'name': 'Fresh Milk',
        'price': 45.0,
        'discountPrice': 40.0,
        'mrp': 50.0,
        'stockQty': 15,
        'isAvailable': true,
      };

      final product1 = ProductModel.fromJson(jsonWithStock);
      expect(product1.id, 'prod_101');
      expect(product1.name, 'Fresh Milk');
      expect(product1.price, 40.0); // discountPrice < price is the selling price
      expect(product1.originalPrice, 50.0); // mrp is the strike price
      expect(product1.stock, 15);
      expect(product1.isAvailable, true);

      // Verify that missing stock defaults to 0 (NOT 50) and marks unavailable
      final jsonZeroStock = {
        '_id': 'prod_102',
        'name': 'Out of stock item',
        'price': 100.0,
      };
      final product2 = ProductModel.fromJson(jsonZeroStock);
      expect(product2.stock, 0); // No arbitrary 50!
      expect(product2.isAvailable, false);
    });

    test('7. CustomerBloc enforces stock limitations on AddToCartEvent and UpdateCartQuantityEvent', () async {
      final fakeCatalog = FakeCatalogRepo();
      final fakeCache = FakeCacheService();
      final fakeOrder = FakeOrderRepo();
      final customerBloc = CustomerBloc(
        catalogRepo: fakeCatalog,
        localCache: fakeCache,
        orderRepo: fakeOrder,
      );

      const outOfStockProduct = ProductEntity(
        id: 'prod_oos',
        name: 'Sold Out Item',
        description: 'Sold out item description',
        price: 99.0,
        unit: '1 kg',
        storeId: 'store_1',
        categoryId: 'cat_all',
        imageUrl: '',
        stock: 0,
        isAvailable: false,
      );

      // Adding out-of-stock product should be blocked
      customerBloc.add(const AddToCartEvent(outOfStockProduct));
      await pumpEventQueue();

      expect(customerBloc.state.cartItems.isEmpty, isTrue);
      expect(customerBloc.state.errorMessage, contains('out of stock'));

      const limitedProduct = ProductEntity(
        id: 'prod_limited',
        name: 'Limited Stock Item',
        description: 'Limited stock item description',
        price: 50.0,
        unit: '1 pc',
        storeId: 'store_1',
        categoryId: 'cat_all',
        imageUrl: '',
        stock: 2,
        isAvailable: true,
      );

      // Add first item -> OK (qty=1)
      customerBloc.add(const AddToCartEvent(limitedProduct));
      await pumpEventQueue();
      expect(customerBloc.state.cartItems.length, 1);
      expect(customerBloc.state.cartItems.first.quantity, 1);

      // Add second item -> OK (qty=2, max stock)
      customerBloc.add(const AddToCartEvent(limitedProduct));
      await pumpEventQueue();
      expect(customerBloc.state.cartItems.first.quantity, 2);

      // Add third item -> BLOCKED by stock limitation!
      customerBloc.add(const AddToCartEvent(limitedProduct));
      await pumpEventQueue();
      expect(customerBloc.state.cartItems.first.quantity, 2);
      expect(customerBloc.state.errorMessage, contains('Only 2 units available'));

      // Updating quantity beyond stock limit is also blocked
      customerBloc.add(const UpdateCartQuantityEvent('prod_limited', 5));
      await pumpEventQueue();
      expect(customerBloc.state.cartItems.first.quantity, 2);
      expect(customerBloc.state.errorMessage, contains('Stock limit reached'));

      await customerBloc.close();
    });

    test('8. RetailerBloc updates product price and stock in state on UpdateProductInInventoryEvent', () async {
      final fakeRetailerRepo = FakeRetailerRepo();
      final fakeOrderRepo = FakeOrderRepo();
      final fakeCatalogRepo = FakeCatalogRepo();

      final retailerBloc = RetailerBloc(
        retailerRepo: fakeRetailerRepo,
        orderRepo: fakeOrderRepo,
        catalogRepo: fakeCatalogRepo,
        enablePeriodicPolling: false,
      );

      const initialProduct = ProductEntity(
        id: 'prod_ret_1',
        name: 'Organic Honey',
        description: 'Pure forest honey',
        price: 250.0,
        unit: '500g',
        storeId: 'store_ret',
        categoryId: 'cat_all',
        imageUrl: '',
        stock: 10,
        isAvailable: true,
      );

      retailerBloc.emit(retailerBloc.state.copyWith(storeProducts: [initialProduct]));

      const updatedProduct = ProductEntity(
        id: 'prod_ret_1',
        name: 'Organic Honey',
        description: 'Pure forest honey',
        price: 299.0,
        unit: '500g',
        storeId: 'store_ret',
        categoryId: 'cat_all',
        imageUrl: '',
        stock: 25,
        isAvailable: true,
      );

      retailerBloc.add(const UpdateProductInInventoryEvent(updatedProduct));
      await pumpEventQueue();

      expect(retailerBloc.state.storeProducts.first.price, 299.0);
      expect(retailerBloc.state.storeProducts.first.stock, 25);
      expect(retailerBloc.state.successMessage, contains('updated successfully'));

      await retailerBloc.close();
    });
  });
}
