import 'package:dartz/dartz.dart' hide id;
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/retailer/data/datasources/retailer_remote_data_source.dart';
import 'package:quicklink/features/retailer/data/models/retailer_registration_models.dart';
import 'package:quicklink/features/retailer/data/repositories/retailer_repository_impl.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_entities.dart';
import 'package:quicklink/features/retailer/domain/repositories/retailer_repository.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';

class MockRetailerRemoteDataSource implements IRetailerRemoteDataSource {
  RetailerStoreProfileEntity mockProfile = const RetailerStoreProfileEntity(
    id: 'store_indiranagar_01',
    storeName: 'Indiranagar Quick Store',
    ownerName: 'Chetan Shetty',
    email: 'chetan@quickmart.com',
    phone: '9876543210',
    fssaiNumber: '11223344556677',
    gstin: '29ABCDE1234F1Z5',
    address: '100 Feet Road, Indiranagar, Bangalore',
    isOpen: true,
    isVerified: true,
    rating: 4.9,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<OrderEntity> mockOrders = [
    OrderEntity(
      id: 'order_live_01',
      orderNumber: 'QM-1001',
      customerId: 'cust_01',
      customerName: 'Aarav Sharma',
      customerPhone: '9876543210',
      deliveryAddress: 'Flat 302, Palm Heights',
      storeId: 'store_indiranagar_01',
      storeName: 'Indiranagar Quick Store',
      storeAddress: '100 Feet Road',
      items: const [
        OrderItemEntity(productId: 'prod_milk', nameSnapshot: 'Farm Milk', priceSnapshot: 30, unit: '500 ml', quantity: 2),
      ],
      subtotal: 60,
      deliveryFee: 15,
      platformFee: 5,
      grandTotal: 80,
      status: OrderStatus.placed,
      deliveryOtp: '5678',
      createdAt: DateTime.now(),
    ),
  ];

  final List<ProductEntity> mockProducts = [
    const ProductEntity(
      id: 'prod_milk',
      storeId: 'store_indiranagar_01',
      categoryId: 'cat_dairy',
      name: 'Farm Fresh Toned Milk',
      description: 'Pure cow milk',
      price: 30.0,
      originalPrice: 32.0,
      unit: '500 ml',
      stock: 50,
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150',
    ),
  ];

  RetailerDashboardStatsEntity mockStats = const RetailerDashboardStatsEntity(
    todayEarnings: 12500.0,
    totalOrders: 42,
    pendingOrders: 3,
    completedOrders: 39,
    commissionDeducted: 625.0,
    netPayout: 11875.0,
  );

  @override
  Future<RetailerStoreProfileEntity> registerStore(Map<String, dynamic> data) async => mockProfile;

  @override
  Future<RetailerStoreProfileEntity> updateStoreProfile(Map<String, dynamic> data) async {
    if (data['name'] != null) {
      mockProfile = RetailerStoreProfileEntity(
        id: mockProfile.id,
        storeName: data['name'].toString(),
        ownerName: mockProfile.ownerName,
        email: mockProfile.email,
        phone: mockProfile.phone,
        fssaiNumber: mockProfile.fssaiNumber,
        gstin: mockProfile.gstin,
        address: mockProfile.address,
        isOpen: mockProfile.isOpen,
        isVerified: mockProfile.isVerified,
        rating: mockProfile.rating,
      );
    }
    return mockProfile;
  }

  @override
  Future<RetailerStoreProfileEntity> getStoreProfile() async => mockProfile;

  @override
  Future<bool> toggleStoreStatus(bool isOpen) async {
    mockProfile = RetailerStoreProfileEntity(
      id: mockProfile.id,
      storeName: mockProfile.storeName,
      ownerName: mockProfile.ownerName,
      email: mockProfile.email,
      phone: mockProfile.phone,
      fssaiNumber: mockProfile.fssaiNumber,
      gstin: mockProfile.gstin,
      address: mockProfile.address,
      isOpen: isOpen,
      isVerified: mockProfile.isVerified,
      rating: mockProfile.rating,
    );
    return true;
  }

  @override
  Future<List<OrderEntity>> getLiveOrders() async => List.from(mockOrders);

  @override
  Future<List<OrderEntity>> getOrderHistory() async => List.from(mockOrders);

  @override
  Future<OrderEntity> acceptOrder(String orderId) async {
    final idx = mockOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = mockOrders[idx].copyWith(status: OrderStatus.accepted);
      mockOrders[idx] = updated;
      return updated;
    }
    final newOrder = OrderEntity(
      id: orderId,
      orderNumber: 'QM-1001',
      customerId: 'cust_01',
      customerName: 'Aarav Sharma',
      customerPhone: '9876543210',
      deliveryAddress: 'Flat 302, Palm Heights',
      storeId: 'store_indiranagar_01',
      storeName: 'Indiranagar Quick Store',
      storeAddress: '100 Feet Road',
      items: const [],
      subtotal: 60,
      deliveryFee: 15,
      platformFee: 5,
      grandTotal: 80,
      status: OrderStatus.accepted,
      deliveryOtp: '5678',
      createdAt: DateTime.now(),
    );
    mockOrders.add(newOrder);
    return newOrder;
  }

  @override
  Future<OrderEntity> markPreparing(String orderId) async {
    final idx = mockOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = mockOrders[idx].copyWith(status: OrderStatus.preparing);
      mockOrders[idx] = updated;
      return updated;
    }
    final newOrder = OrderEntity(
      id: orderId,
      orderNumber: 'QM-1001',
      customerId: 'cust_01',
      customerName: 'Aarav Sharma',
      customerPhone: '9876543210',
      deliveryAddress: 'Flat 302, Palm Heights',
      storeId: 'store_indiranagar_01',
      storeName: 'Indiranagar Quick Store',
      storeAddress: '100 Feet Road',
      items: const [],
      subtotal: 60,
      deliveryFee: 15,
      platformFee: 5,
      grandTotal: 80,
      status: OrderStatus.preparing,
      deliveryOtp: '5678',
      createdAt: DateTime.now(),
    );
    mockOrders.add(newOrder);
    return newOrder;
  }

  @override
  Future<OrderEntity> markReady(String orderId) async {
    final idx = mockOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = mockOrders[idx].copyWith(status: OrderStatus.readyForPickup);
      mockOrders[idx] = updated;
      return updated;
    }
    final newOrder = OrderEntity(
      id: orderId,
      orderNumber: 'QM-1001',
      customerId: 'cust_01',
      customerName: 'Aarav Sharma',
      customerPhone: '9876543210',
      deliveryAddress: 'Flat 302, Palm Heights',
      storeId: 'store_indiranagar_01',
      storeName: 'Indiranagar Quick Store',
      storeAddress: '100 Feet Road',
      items: const [],
      subtotal: 60,
      deliveryFee: 15,
      platformFee: 5,
      grandTotal: 80,
      status: OrderStatus.readyForPickup,
      deliveryOtp: '5678',
      createdAt: DateTime.now(),
    );
    mockOrders.add(newOrder);
    return newOrder;
  }

  @override
  Future<OrderEntity> rejectOrder(String orderId, String reason) async {
    final idx = mockOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = mockOrders[idx].copyWith(status: OrderStatus.rejected, rejectionReason: reason);
      mockOrders[idx] = updated;
      return updated;
    }
    final newOrder = OrderEntity(
      id: orderId,
      orderNumber: 'QM-1001',
      customerId: 'cust_01',
      customerName: 'Aarav Sharma',
      customerPhone: '9876543210',
      deliveryAddress: 'Flat 302, Palm Heights',
      storeId: 'store_indiranagar_01',
      storeName: 'Indiranagar Quick Store',
      storeAddress: '100 Feet Road',
      items: const [],
      subtotal: 60,
      deliveryFee: 15,
      platformFee: 5,
      grandTotal: 80,
      status: OrderStatus.rejected,
      deliveryOtp: '5678',
      createdAt: DateTime.now(),
      rejectionReason: reason,
    );
    mockOrders.add(newOrder);
    return newOrder;
  }

  @override
  Future<List<ProductEntity>> getCatalogItems() async => List.from(mockProducts);

  @override
  Future<ProductEntity> addProduct(ProductEntity product) async {
    mockProducts.add(product);
    return product;
  }

  @override
  Future<ProductEntity> updateProduct(ProductEntity product) async {
    final idx = mockProducts.indexWhere((p) => p.id == product.id);
    if (idx != -1) mockProducts[idx] = product;
    return product;
  }

  @override
  Future<bool> deleteProduct(String productId) async {
    mockProducts.removeWhere((p) => p.id == productId);
    return true;
  }

  @override
  Future<bool> toggleProductStock(String productId, bool isAvailable) async {
    final idx = mockProducts.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final p = mockProducts[idx];
      mockProducts[idx] = ProductEntity(
        id: p.id,
        storeId: p.storeId,
        categoryId: p.categoryId,
        name: p.name,
        description: p.description,
        price: p.price,
        unit: p.unit,
        stock: isAvailable ? 50 : 0,
        isAvailable: isAvailable,
        imageUrl: p.imageUrl,
      );
    }
    return true;
  }

  @override
  Future<RetailerDashboardStatsEntity> getDashboardStats() async => mockStats;

  @override
  Future<bool> registerDeviceToken({
    required String fcmToken,
    required String platform,
    required String deviceId,
  }) async => true;

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async => [];

  @override
  Future<int> getUnreadNotificationCount() async => 0;

  @override
  Future<bool> markAllNotificationsRead() async => true;

  @override
  Future<bool> markNotificationRead(String id) async => true;

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
  Future<FileUploadModel> uploadFile({required String filePath, String? folder}) async =>
      const FileUploadModel(url: 'https://cdn.example.com/doc.pdf', publicId: 'doc1', format: 'pdf', bytes: 1024);

  @override
  Future<RetailerSubscriptionEntity?> getSubscription() async => RetailerSubscriptionEntity.freeTier;
}

class MockOrderRepoStub implements IOrderRepository {
  final List<OrderEntity> orders = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

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
    final newOrder = OrderEntity(
      id: 'ord_test_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: 'QM-9999',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: items.fold(0.0, (acc, item) => acc + item.total),
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: items.fold(0.0, (acc, item) => acc + item.total) + deliveryFee + platformFee,
      status: OrderStatus.placed,
      deliveryOtp: '1234',
      createdAt: DateTime.now(),
    );
    orders.add(newOrder);
    return Right(newOrder);
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async =>
      Right(orders.where((o) => customerId.isEmpty || o.customerId == customerId).toList());
  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async =>
      Right(orders.where((o) => storeId.isEmpty || o.storeId == storeId).toList());

  @override
  Future<Either<Failure, OrderEntity>> updateOrderStatus({
    required String orderId,
    required OrderStatus nextStatus,
    String? reason,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = orders[idx].copyWith(status: nextStatus, rejectionReason: reason);
      orders[idx] = updated;
      return Right(updated);
    }
    return Right(OrderEntity(
      id: orderId,
      orderNumber: 'QM-1001',
      customerId: 'c1',
      customerName: 'C1',
      customerPhone: '987',
      deliveryAddress: 'Addr',
      storeId: 's1',
      storeName: 'S1',
      storeAddress: 'SA',
      items: const [],
      subtotal: 100,
      deliveryFee: 10,
      platformFee: 5,
      grandTotal: 115,
      status: nextStatus,
      deliveryOtp: '1234',
      createdAt: DateTime.now(),
    ));
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
      return Right(updated);
    }
    return const Left(ValidationFailure(message: 'Order not found'));
  }

  @override
  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason) async => const Right(true);
  @override
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async => const Right(true);
  @override
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId) async => const Right({});
  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({
    required String orderId,
    required String deliveryPartnerId,
    required String deliveryPartnerName,
    required String deliveryPartnerPhone,
  }) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({required String orderId, required String enteredOtp}) async => throw UnimplementedError();
}

class MockCatalogRepoStub implements ICatalogRepository {
  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();
  @override
  Stream<List<StoreEntity>> get storesStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product) async => Right(product);
  @override
  Future<Either<Failure, String>> deleteProduct(String productId) async => Right(productId);
  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async => Right(product);
  @override
  Future<Either<Failure, ProductEntity>> toggleProductStock(String productId, bool isAvailable) async => Right(ProductEntity(
        id: productId,
        storeId: 's1',
        categoryId: 'c1',
        name: 'Product',
        description: '',
        price: 50,
        unit: '1 item',
        stock: isAvailable ? 50 : 0,
        isAvailable: isAvailable,
        imageUrl: '',
      ));
  @override
  Future<Either<Failure, StoreEntity>> toggleStoreOpenStatus(String storeId, bool isOpen) async => Right(StoreEntity(
        id: storeId,
        name: 'Store',
        category: 'Grocery',
        address: 'Addr',
        rating: 4.8,
        deliveryTime: '20 min',
        distanceKm: 1.0,
        isOpen: isOpen,
        bannerUrl: '',
}

extension OrderEntityCopyWith on OrderEntity {
  OrderEntity copyWith({OrderStatus? status, String? rejectionReason}) {
    return OrderEntity(
      id: id,
      orderNumber: orderNumber,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: grandTotal,
      status: status ?? this.status,
      deliveryOtp: deliveryOtp,
      createdAt: createdAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Retailer API Full Flow Suite', () {
    late MockRetailerRemoteDataSource remoteDataSource;
    late IRetailerRepository retailerRepository;
    late IOrderRepository orderRepository;
    late RetailerBloc retailerBloc;

    setUp(() {
      remoteDataSource = MockRetailerRemoteDataSource();
      retailerRepository = RetailerRepositoryImpl(remoteDataSource);
      orderRepository = MockOrderRepoStub();
      retailerBloc = RetailerBloc(
        orderRepo: orderRepository,
        catalogRepo: MockCatalogRepoStub(),
        retailerRepo: retailerRepository,
      );
    });

    tearDown(() {
      retailerBloc.close();
    });

    test('1. Repository fetches store profile, live orders, catalog, and dashboard stats', () async {
      final profileRes = await retailerRepository.getStoreProfile();
      expect(profileRes.isRight(), isTrue);
      profileRes.fold((_) => fail('should succeed'), (profile) {
        expect(profile.storeName, 'Indiranagar Quick Store');
        expect(profile.isOpen, isTrue);
      });

      final ordersRes = await retailerRepository.getLiveOrders();
      expect(ordersRes.isRight(), isTrue);
      ordersRes.fold((_) => fail('should succeed'), (orders) {
        expect(orders.length, 1);
        expect(orders.first.status, OrderStatus.placed);
      });

      final catalogRes = await retailerRepository.getCatalogItems();
      expect(catalogRes.isRight(), isTrue);
      catalogRes.fold((_) => fail('should succeed'), (products) {
        expect(products.length, 1);
        expect(products.first.name, 'Farm Fresh Toned Milk');
      });

      final statsRes = await retailerRepository.getDashboardStats();
      expect(statsRes.isRight(), isTrue);
      statsRes.fold((_) => fail('should succeed'), (stats) {
        expect(stats.todayEarnings, 12500.0);
        expect(stats.totalOrders, 42);
      });
    });

    test('2. Order state pipeline: Placed -> Accepted -> Preparing -> Ready -> Reject', () async {
      final accepted = await retailerRepository.acceptOrder('order_live_01');
      expect(accepted.isRight(), isTrue);
      accepted.fold((_) => fail('should succeed'), (o) => expect(o.status, OrderStatus.accepted));

      final preparing = await retailerRepository.markPreparing('order_live_01');
      expect(preparing.isRight(), isTrue);
      preparing.fold((_) => fail('should succeed'), (o) => expect(o.status, OrderStatus.preparing));

      final ready = await retailerRepository.markReady('order_live_01');
      expect(ready.isRight(), isTrue);
      ready.fold((_) => fail('should succeed'), (o) => expect(o.status, OrderStatus.readyForPickup));

      final rejected = await retailerRepository.rejectOrder('order_live_01', 'Store closed early');
      expect(rejected.isRight(), isTrue);
      rejected.fold((_) => fail('should succeed'), (o) {
        expect(o.status, OrderStatus.rejected);
        expect(o.rejectionReason, 'Store closed early');
      });
    });

    test('3. Catalog CRUD & Stock Management via Repository', () async {
      const newProduct = ProductEntity(
        id: 'prod_bread',
        storeId: 'store_indiranagar_01',
        categoryId: 'cat_bakery',
        name: 'Whole Wheat Brown Bread',
        description: 'Fresh sliced bread',
        price: 45.0,
        unit: '400 g',
        stock: 25,
        isAvailable: true,
        imageUrl: 'https://images.unsplash.com/bread',
      );

      final addRes = await retailerRepository.addProduct(newProduct);
      expect(addRes.isRight(), isTrue);

      final toggleRes = await retailerRepository.toggleProductStock('prod_bread', false);
      expect(toggleRes.isRight(), isTrue);

      final deleteRes = await retailerRepository.deleteProduct('prod_bread');
      expect(deleteRes.isRight(), isTrue);
    });

    test('4. RetailerBloc LoadRetailerDataEvent populates state with live data', () async {
      retailerBloc.add(const LoadRetailerDataEvent());
      await expectLater(
        retailerBloc.stream,
        emitsThrough(
          predicate<RetailerState>((s) =>
              s.isLoading == false &&
              s.orders.length == 1 &&
              s.storeProducts.length == 1 &&
              s.profile?.storeName == 'Indiranagar Quick Store' &&
              s.dashboardStats?.totalOrders == 42),
        ),
      );
    });

    test('5. RetailerBloc Order Actions emit success messages', () async {
      retailerBloc.add(const AcceptOrderEvent('order_live_01'));
      await expectLater(
        retailerBloc.stream,
        emitsThrough(predicate<RetailerState>((s) => s.successMessage?.contains('Accepted') == true)),
      );

      retailerBloc.add(const MarkPreparingEvent('order_live_01'));
      await expectLater(
        retailerBloc.stream,
        emitsThrough(predicate<RetailerState>((s) => s.successMessage?.contains('Preparing') == true)),
      );

      retailerBloc.add(const MarkReadyForPickupEvent('order_live_01'));
      await expectLater(
        retailerBloc.stream,
        emitsThrough(predicate<RetailerState>((s) => s.successMessage?.contains('Ready for Rider') == true)),
      );
    });

    test('6. RetailerBloc Inventory Actions work seamlessly', () async {
      const p = ProductEntity(
        id: 'p_apple',
        storeId: 'store_01',
        categoryId: 'cat_fruits',
        name: 'Fresh Fuji Apples',
        description: 'Crisp apples',
        price: 120.0,
        unit: '1 kg',
        stock: 30,
        isAvailable: true,
        imageUrl: 'https://images.unsplash.com/apple',
      );

      retailerBloc.add(const AddProductToInventoryEvent(p));
      await expectLater(
        retailerBloc.stream,
        emitsThrough(predicate<RetailerState>((s) => s.successMessage?.contains('added to inventory') == true)),
      );

      retailerBloc.add(const ToggleProductStockEvent('p_apple', false));
      await expectLater(
        retailerBloc.stream,
        emitsThrough(predicate<RetailerState>((s) => s.successMessage?.contains('stock status updated') == true)),
      );
    });

    test('7. RetailerBloc Store Status Toggle updates state', () async {
      retailerBloc.add(const ToggleStoreStatusEvent('store_01', false));
      await expectLater(
        retailerBloc.stream,
        emitsThrough(predicate<RetailerState>((s) => s.isStoreOpen == false && s.successMessage?.contains('CLOSED') == true)),
      );
    });

    test('8. Cross-App Order Lifecycle Sync: Customer creates order -> Retailer accepts and prepares', () async {
      final orderRes = await orderRepository.createOrder(
        customerId: 'cust_01',
        customerName: 'Aarav Sharma',
        customerPhone: '9876543210',
        deliveryAddress: 'Flat 302, Palm Heights',
        storeId: 'store_indiranagar_01',
        storeName: 'Indiranagar Quick Store',
        storeAddress: '100 Feet Road',
        items: const [
          OrderItemEntity(
            productId: 'prod_bread',
            nameSnapshot: 'Whole Wheat Brown Bread',
            priceSnapshot: 45.0,
            unit: '400 g',
            quantity: 2,
          ),
        ],
        deliveryFee: 20,
        platformFee: 5,
      );

      expect(orderRes.isRight(), isTrue);
      final createdOrder = orderRes.getOrElse(() => throw Exception());
      expect(createdOrder.status, equals(OrderStatus.placed));

      // Retailer accepts the order
      final acceptRes = await retailerRepository.acceptOrder(createdOrder.id);
      expect(acceptRes.isRight(), isTrue);
      expect(acceptRes.getOrElse(() => throw Exception()).status, equals(OrderStatus.accepted));
      await orderRepository.updateOrderStatus(orderId: createdOrder.id, nextStatus: OrderStatus.accepted);

      // Retailer marks preparing
      final prepRes = await retailerRepository.markPreparing(createdOrder.id);
      expect(prepRes.isRight(), isTrue);
      expect(prepRes.getOrElse(() => throw Exception()).status, equals(OrderStatus.preparing));
      await orderRepository.updateOrderStatus(orderId: createdOrder.id, nextStatus: OrderStatus.preparing);

      // Retailer marks ready
      final readyRes = await retailerRepository.markReady(createdOrder.id);
      expect(readyRes.isRight(), isTrue);
      expect(readyRes.getOrElse(() => throw Exception()).status, equals(OrderStatus.readyForPickup));
      await orderRepository.updateOrderStatus(orderId: createdOrder.id, nextStatus: OrderStatus.readyForPickup);

      // Customer fetches orders -> status is readyForPickup
      final customerOrders = await orderRepository.getCustomerOrders('cust_01');
      expect(customerOrders.isRight(), isTrue);
      final found = customerOrders.getOrElse(() => []).firstWhere((o) => o.id == createdOrder.id);
      expect(found.status, equals(OrderStatus.readyForPickup));
    });
  });
}
