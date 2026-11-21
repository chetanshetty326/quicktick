import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/services/network_connectivity_service.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/hero_banner_entity.dart';
import 'package:quicklink/features/customer/domain/entities/coupon_entity.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_event.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_state.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/di/service_locator.dart';

class FakeCatalogRepository extends Fake implements ICatalogRepository {
  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();
  @override
  Stream<List<StoreEntity>> get storesStream => const Stream.empty();

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async {
    return const Right([CategoryEntity(id: 'cat_dairy', name: 'Dairy', icon: '', colorHex: '#FFFFFF')]);
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
    return const Right([
      ProductEntity(
        id: 'p1',
        storeId: 's1',
        name: 'Fresh Milk',
        description: '',
        price: 30.0,
        unit: '500ml',
        imageUrl: '',
        categoryId: 'cat_dairy',
        isAvailable: true,
        stock: 10,
      )
    ]);
  }

  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String app = 'CUSTOMER'}) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<CouponEntity>>> getAvailableCoupons({String? retailerId}) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async =>
      const Right([]);

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async =>
      const Right(0);

  @override
  Future<Either<Failure, CustomerZoneEntity>> checkLocation({required double lat, required double lng}) async =>
      const Right(CustomerZoneEntity(inZone: true, zoneId: 'z1', zoneName: 'Default Zone'));
}

class FakeOrderRepository extends Fake implements IOrderRepository {
  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async {
    return const Right([]);
  }
}

class FakeLocalCacheService extends Fake implements ILocalCacheService {
  @override
  List<Map<String, dynamic>> getCartItems() => [];

  @override
  Map<String, dynamic>? getCachedActiveLocation() => {'lat': 12.9716, 'lng': 77.5946, 'address': 'Bangalore, Karnataka'};

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
  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {}

  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {}

  @override
  Future<void> cacheStores(List<Map<String, dynamic>> stores) async {}
}

class FakeConnectivityService extends Fake implements INetworkConnectivityService {
  final _controller = StreamController<bool>.broadcast();
  bool _connected = true;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<bool> checkConnection() async => _connected;

  @override
  void dispose() {
    _controller.close();
  }

  void emitStatus(bool online) {
    _connected = online;
    _controller.add(online);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCatalogRepository fakeCatalogRepo;
  late FakeOrderRepository fakeOrderRepo;
  late FakeLocalCacheService fakeLocalCache;
  late FakeConnectivityService fakeConnectivityService;
  late CustomerBloc customerBloc;

  setUp(() {
    fakeCatalogRepo = FakeCatalogRepository();
    fakeOrderRepo = FakeOrderRepository();
    fakeLocalCache = FakeLocalCacheService();
    fakeConnectivityService = FakeConnectivityService();

    if (sl.isRegistered<INetworkConnectivityService>()) {
      sl.unregister<INetworkConnectivityService>();
    }
    sl.registerSingleton<INetworkConnectivityService>(fakeConnectivityService);

    customerBloc = CustomerBloc(
      catalogRepo: fakeCatalogRepo,
      orderRepo: fakeOrderRepo,
      localCache: fakeLocalCache,
      paymentDataSource: null,
      webSocketService: null,
    );
  });

  tearDown(() {
    customerBloc.close();
    fakeConnectivityService.dispose();
    if (sl.isRegistered<INetworkConnectivityService>()) {
      sl.unregister<INetworkConnectivityService>();
    }
  });

  test('Auto-refresh flow: Going offline sets failureType.noInternet, coming online auto-refreshes data', () async {
    // 1. Initial State
    expect(customerBloc.state.failureType, FailureType.none);

    // 2. Network drops offline via service stream
    fakeConnectivityService.emitStatus(false);
    await Future.delayed(const Duration(milliseconds: 60));

    expect(customerBloc.state.failureType, FailureType.noInternet);
    expect(customerBloc.state.isOffline, isTrue);

    // 3. Network restored -> triggers auto-refresh of catalog & orders
    fakeConnectivityService.emitStatus(true);
    await Future.delayed(const Duration(milliseconds: 150));

    // Offline status is immediately cleared and live products are auto-loaded
    expect(customerBloc.state.isOffline, isFalse);
    expect(customerBloc.state.failureType, FailureType.none);
    expect(customerBloc.state.allProducts.isNotEmpty, isTrue);
    expect(customerBloc.state.allProducts.first.name, 'Fresh Milk');
  });
}
