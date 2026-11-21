import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/customer_address_entity.dart';
import 'package:quicklink/features/customer/domain/entities/hero_banner_entity.dart';
import 'package:quicklink/features/customer/domain/entities/coupon_entity.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';

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
        name: 'Milk',
        description: '',
        price: 25.0,
        unit: '1L',
        imageUrl: '',
        categoryId: 'cat_dairy',
        isAvailable: true,
        stock: 10,
      )
    ]);
  }

  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async {
    await Future.delayed(const Duration(milliseconds: 60));
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<CustomerAddressEntity>>> getAddresses() async {
    await Future.delayed(const Duration(milliseconds: 60));
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
    await Future.delayed(const Duration(milliseconds: 90));
    return const Right([]);
  }
}

class FakeLocalCacheService extends Fake implements ILocalCacheService {
  @override
  List<Map<String, dynamic>> getCartItems() => [];

  @override
  Map<String, dynamic>? getCachedActiveLocation() => null;

  @override
  Future<void> cacheActiveLocation({
    required double lat,
    required double lng,
    required String address,
    String? zoneId,
    String? zoneName,
    bool inZone = true,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CustomerBloc progressive staged loading: Stage 1 unlocks UI immediately before background requests finish', () async {
    final catalogRepo = FakeCatalogRepository();
    final orderRepo = FakeOrderRepository();
    final localCache = FakeLocalCacheService();

    final bloc = CustomerBloc(
      catalogRepo: catalogRepo,
      orderRepo: orderRepo,
      localCache: localCache,
    );

    final emittedStates = <CustomerState>[];
    final sub = bloc.stream.listen((state) {
      emittedStates.add(state);
    });

    bloc.add(const LoadCustomerDataEvent());

    // Allow Stage 1 to complete (takes ~5-15ms)
    await Future.delayed(const Duration(milliseconds: 30));

    // UI MUST ALREADY BE UNLOCKED!
    final unblockedState = emittedStates.firstWhere(
      (s) => s.isLoading == false && s.allProducts.isNotEmpty,
      orElse: () => const CustomerState(isLoading: true),
    );

    expect(unblockedState.isLoading, isFalse,
        reason: 'Stage 1 must emit isLoading: false as soon as Categories & Products are ready');
    expect(unblockedState.allProducts.length, 1);
    expect(unblockedState.categories.length, 1);

    // Notice: At this instant, background requests (stores, orders) are still in flight
    expect(unblockedState.myOrders.isEmpty, isTrue,
        reason: 'myOrders should still be running in background and not block UI');

    // Allow Stage 2 & 3 to finish
    await Future.delayed(const Duration(milliseconds: 100));

    await sub.cancel();
    await bloc.close();
  });
}
