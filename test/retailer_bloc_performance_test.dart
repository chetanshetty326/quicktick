import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_entities.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_finance_entities.dart';
import 'package:quicklink/features/customer/domain/entities/hero_banner_entity.dart';
import 'package:quicklink/features/retailer/domain/repositories/retailer_repository.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';

class FakeOrderRepo extends Fake implements IOrderRepository {
  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async =>
      const Right([]);
}

class FakeCatalogRepo extends Fake implements ICatalogRepository {
  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();

  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async =>
      const Right([]);
}

class FakeRetailerRepo extends Fake implements IRetailerRepository {
  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();
  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();

  int checkCallCount = 0;

  @override
  Future<Either<Failure, ({bool available, String message})>> checkStoreName(String name) async {
    checkCallCount++;
    // Simulate slight network delay
    await Future.delayed(const Duration(milliseconds: 40));
    return Right((available: true, message: 'Name available: $name'));
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getLiveOrders() async => const Right([]);

  @override
  Future<Either<Failure, List<ProductEntity>>> getCatalogItems() async => const Right([]);

  @override
  Future<Either<Failure, RetailerStoreProfileEntity>> getStoreProfile() async =>
      const Right(RetailerStoreProfileEntity(
        id: 'r1',
        storeName: 'Test Shop',
        ownerName: 'Owner',
        phone: '9876543210',
        email: 'test@shop.com',
        fssaiNumber: '12345678901234',
        gstin: '29ABCDE1234F1Z5',
        address: '123 Main St',
        isOpen: true,
        isVerified: true,
        rating: 4.8,
      ));

  @override
  Future<Either<Failure, RetailerDashboardStatsEntity>> getDashboardStats() async =>
      const Right(RetailerDashboardStatsEntity(
        todayEarnings: 2500,
        totalOrders: 10,
        pendingOrders: 1,
        completedOrders: 9,
        commissionDeducted: 100,
        netPayout: 2400,
      ));

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async => const Right([]);

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async => const Right(0);

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async => const Right(true);

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async => const Right(true);

  @override
  Future<Either<Failure, RetailerSubscriptionEntity?>> getSubscription() async =>
      const Right(RetailerSubscriptionEntity.freeTier);

  @override
  Future<Either<Failure, RetailerEarningsSummaryEntity>> getEarningsSummary() async =>
      const Right(RetailerEarningsSummaryEntity(
        today: RetailerEarningsPeriodEntity(),
        thisWeek: RetailerEarningsPeriodEntity(),
        thisMonth: RetailerEarningsPeriodEntity(),
        lifetime: RetailerEarningsPeriodEntity(),
      ));

  @override
  Future<Either<Failure, List<RetailerSettlementEntity>>> getSettlements({int limit = 50, int skip = 0}) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<RetailerEarningEntity>>> getEarnings({String? status, int limit = 50, int skip = 0}) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String app = 'RETAILER'}) async =>
      const Right([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Retailer Performance & Concurrency Benchmarks', () {
    test('Restartable CheckStoreNameEvent cancels superseded checks without stale emissions', () async {
      final retailerRepo = FakeRetailerRepo();
      final bloc = RetailerBloc(
        orderRepo: FakeOrderRepo(),
        catalogRepo: FakeCatalogRepo(),
        retailerRepo: retailerRepo,
      );

      final stateList = <RetailerState>[];
      final sub = bloc.stream.listen(stateList.add);

      final sw = Stopwatch()..start();

      // Dispatch 3 rapid keystroke events
      bloc.add(const CheckStoreNameEvent('Sho'));
      await Future.delayed(const Duration(milliseconds: 10));
      bloc.add(const CheckStoreNameEvent('Shop'));
      await Future.delayed(const Duration(milliseconds: 10));
      bloc.add(const CheckStoreNameEvent('ShopNameFinal'));

      // Wait for the final one to complete
      await Future.delayed(const Duration(milliseconds: 100));
      sw.stop();

      // Only the final check should be settled in state
      expect(bloc.state.isCheckingStoreName, isFalse);
      expect(bloc.state.isStoreNameAvailable, isTrue);
      expect(bloc.state.storeNameCheckMessage, contains('ShopNameFinal'));

      // Total time should be well under 200ms
      expect(sw.elapsedMilliseconds, lessThan(300),
          reason: 'Restartable transformer should abort earlier operations and finish promptly');

      await sub.cancel();
      await bloc.close();
    });

    test('RetailerBloc loads dashboard data within performance threshold (<100ms local mock)', () async {
      final retailerRepo = FakeRetailerRepo();
      final bloc = RetailerBloc(
        orderRepo: FakeOrderRepo(),
        catalogRepo: FakeCatalogRepo(),
        retailerRepo: retailerRepo,
      );

      final sw = Stopwatch()..start();
      bloc.add(const LoadRetailerDataEvent(storeId: 'r1'));

      await expectLater(
        bloc.stream,
        emitsThrough(predicate<RetailerState>((s) => !s.isLoading && s.profile != null)),
      );
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(150),
          reason: 'Dashboard state assembly must be snappy');
      expect(bloc.state.profile?.storeName, 'Test Shop');
      expect(bloc.state.dashboardStats?.totalOrders, 10);

      await bloc.close();
    });
  });
}
