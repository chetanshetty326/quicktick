import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/retailer/data/models/retailer_notification_model.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_notification_entity.dart';
import 'package:quicklink/features/retailer/domain/repositories/retailer_repository.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';

class MockOrderRepo extends Fake implements IOrderRepository {}

class MockCatalogRepo extends Fake implements ICatalogRepository {
  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();
  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async =>
      const Right([]);
}

class MockRetailerRepo extends Fake implements IRetailerRepository {
  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();
  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();

  List<Map<String, dynamic>> mockNotifications = [];
  int mockUnreadCount = 0;
  bool markReadCalled = false;
  bool markAllReadCalled = false;

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async =>
      Right(mockNotifications);

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async =>
      Right(mockUnreadCount);

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async {
    markReadCalled = true;
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async {
    markAllReadCalled = true;
    return const Right(true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Retailer Clean Architecture - Notification Entities & Models', () {
    test('RetailerNotificationEntity formats timeAgo and handles map operator access', () {
      final now = DateTime.now();
      final entity = RetailerNotificationEntity(
        id: 'notif_100',
        userId: 'ret_01',
        title: 'New Order Received',
        body: 'Order #QC-123456-7890 placed',
        type: 'ORDER_CREATED',
        isRead: false,
        priority: 'HIGH',
        createdAt: now.subtract(const Duration(minutes: 5)),
        orderId: 'QC-123456-7890',
      );

      expect(entity.id, 'notif_100');
      expect(entity['id'], 'notif_100');
      expect(entity['title'], 'New Order Received');
      expect(entity['body'], 'Order #QC-123456-7890 placed');
      expect(entity['read'], false);
      expect(entity['orderId'], 'QC-123456-7890');
      expect(entity.timeAgo, '5m ago');
    });

    test('RetailerNotificationModel parses backend payload accurately and extracts orderId', () {
      final backendJson = {
        '_id': 'mongo_id_999',
        'userId': 'ret_user_42',
        'title': 'Delivery Partner Assigned 🛵',
        'body': 'Driver Ramesh Kumar assigned to pickup Order QC-889900-1122.',
        'type': 'DELIVERY_ASSIGNED',
        'read': false,
        'priority': 'MEDIUM',
        'createdAt': '2026-09-30T10:00:00.000Z',
      };

      final model = RetailerNotificationModel.fromJson(backendJson);
      expect(model.id, 'mongo_id_999');
      expect(model.type, 'DELIVERY_ASSIGNED');
      expect(model.isRead, false);
      expect(model.orderId, 'QC-889900-1122');

      final map = model.toMap();
      expect(map['id'], 'mongo_id_999');
      expect(map['title'], 'Delivery Partner Assigned 🛵');
      expect(map['orderId'], 'QC-889900-1122');
      expect(map['isRead'], false);
    });
  });

  group('RetailerBloc - Clean Architecture Notifications Flow', () {
    late MockOrderRepo mockOrderRepo;
    late MockCatalogRepo mockCatalogRepo;
    late MockRetailerRepo mockRetailerRepo;
    late RetailerBloc bloc;

    setUp(() {
      mockOrderRepo = MockOrderRepo();
      mockCatalogRepo = MockCatalogRepo();
      mockRetailerRepo = MockRetailerRepo();
      bloc = RetailerBloc(
        orderRepo: mockOrderRepo,
        catalogRepo: mockCatalogRepo,
        retailerRepo: mockRetailerRepo,
        enablePeriodicPolling: false,
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('LoadRetailerNotificationsEvent fetches notifications and syncs unread count', () async {
      mockRetailerRepo.mockNotifications = [
        {
          'id': 'n1',
          'title': 'Fresh Order',
          'body': 'Order placed',
          'read': false,
          'isRead': false,
          'type': 'ORDER',
        },
        {
          'id': 'n2',
          'title': 'Settlement Processed',
          'body': 'Payout credited',
          'read': true,
          'isRead': true,
          'type': 'PAYOUT',
        },
      ];
      mockRetailerRepo.mockUnreadCount = 1;

      bloc.add(const LoadRetailerNotificationsEvent());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<RetailerState>((state) {
            return state.notifications.length == 2 &&
                state.unreadNotificationsCount == 1 &&
                state.notifications.first['id'] == 'n1';
          }),
        ),
      );
    });

    test('MarkRetailerNotificationReadEvent updates read status and unread count', () async {
      mockRetailerRepo.mockNotifications = [
        {
          'id': 'n1',
          'title': 'Fresh Order',
          'read': false,
          'isRead': false,
        },
      ];
      mockRetailerRepo.mockUnreadCount = 1;

      bloc.add(const LoadRetailerNotificationsEvent());
      await pumpEventQueue();

      bloc.add(const MarkRetailerNotificationReadEvent('n1'));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<RetailerState>((state) {
            return state.notifications.first['isRead'] == true &&
                state.unreadNotificationsCount == 0;
          }),
        ),
      );
      expect(mockRetailerRepo.markReadCalled, true);
    });

    test('MarkAllRetailerNotificationsReadEvent marks all notifications read', () async {
      mockRetailerRepo.mockNotifications = [
        {'id': 'n1', 'read': false, 'isRead': false},
        {'id': 'n2', 'read': false, 'isRead': false},
      ];
      mockRetailerRepo.mockUnreadCount = 2;

      bloc.add(const LoadRetailerNotificationsEvent());
      await pumpEventQueue();

      bloc.add(const MarkAllRetailerNotificationsReadEvent());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<RetailerState>((state) {
            return state.unreadNotificationsCount == 0 &&
                state.notifications.every((n) => n['isRead'] == true);
          }),
        ),
      );
      expect(mockRetailerRepo.markAllReadCalled, true);
    });

    test('RetailerPushNotificationReceivedEvent inserts incoming notification and updates unread count', () async {
      bloc.add(const RetailerPushNotificationReceivedEvent({
        '_id': 'push_live_01',
        'title': 'Driver at store counter',
        'body': 'Driver has arrived to pick up',
        'type': 'PICKUP',
        'read': false,
      }));

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<RetailerState>((state) {
            return state.notifications.length == 1 &&
                state.notifications.first['id'] == 'push_live_01' &&
                state.unreadNotificationsCount == 1 &&
                state.latestPushNotification?['id'] == 'push_live_01';
          }),
        ),
      );
    });
  });
}
