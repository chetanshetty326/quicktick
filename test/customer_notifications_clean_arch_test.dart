import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/customer/data/models/customer_notification_model.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/cart_item_entity.dart';

class MockOrderRepo implements IOrderRepository {
  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders([String customerId = '']) async => const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocalCache implements ILocalCacheService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCatalogRepo implements ICatalogRepository {
  List<Map<String, dynamic>> notificationsList = [];
  int unreadCount = 0;

  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();
  @override
  Stream<List<CategoryEntity>> get categoriesStream => const Stream.empty();
  @override
  Stream<List<StoreEntity>> get storesStream => const Stream.empty();
  @override
  Stream<List<CartItemEntity>> get cartStream => const Stream.empty();

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async => Right(notificationsList);

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async => Right(unreadCount);

  @override
  Future<Either<Failure, bool>> markNotificationRead(String notificationId) async {
    for (var n in notificationsList) {
      if (n['id'] == notificationId || n['_id'] == notificationId) {
        n['read'] = true;
        n['isRead'] = true;
      }
    }
    unreadCount = notificationsList.where((n) => n['read'] != true && n['isRead'] != true).length;
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async {
    for (var n in notificationsList) {
      n['read'] = true;
      n['isRead'] = true;
    }
    unreadCount = 0;
    return const Right(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Customer Notification Clean Architecture & BLoC Tests', () {
    test('CustomerNotificationModel parses backend payload with _id and extracts orderId', () {
      final backendJson = {
        "_id": "6abcb83a1894c8586cd4fca9",
        "userId": "6ab7e44b9f576227ff7259cb",
        "title": "Order assigned",
        "body": "Your order QC-260930-0006 is on the way to be picked up",
        "type": "ORDER_UPDATE",
        "read": false,
        "priority": "MEDIUM",
        "sentAt": "2026-09-30T07:20:26.457Z",
        "createdAt": "2026-09-30T07:20:26.457Z",
      };

      final model = CustomerNotificationModel.fromJson(backendJson);

      expect(model.id, "6abcb83a1894c8586cd4fca9");
      expect(model.title, "Order assigned");
      expect(model.body, "Your order QC-260930-0006 is on the way to be picked up");
      expect(model.isRead, false);
      expect(model.orderId, "QC-260930-0006");
      expect(model['read'], false);
      expect(model['_id'], "6abcb83a1894c8586cd4fca9");
      expect(model['id'], "6abcb83a1894c8586cd4fca9");

      final map = model.toMap();
      expect(map['id'], "6abcb83a1894c8586cd4fca9");
      expect(map['_id'], "6abcb83a1894c8586cd4fca9");
      expect(map['read'], false);
      expect(map['orderId'], "QC-260930-0006");
      expect(map['time'], isNotEmpty);
    });

    test('CustomerBloc loads notifications and keeps unread count synchronized', () async {
      final catalogRepo = MockCatalogRepo();
      final orderRepo = MockOrderRepo();
      final localCache = MockLocalCache();

      final model1 = CustomerNotificationModel.fromJson({
        "_id": "notif_1",
        "title": "Order update",
        "body": "Order QC-260930-0001 is now READY_FOR_PICKUP",
        "read": false,
      });
      final model2 = CustomerNotificationModel.fromJson({
        "_id": "notif_2",
        "title": "Order update",
        "body": "Order QC-260930-0002 is now DELIVERED",
        "read": true,
      });

      catalogRepo.notificationsList = [model1.toMap(), model2.toMap()];
      catalogRepo.unreadCount = 1;

      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
      );

      bloc.add(LoadNotificationsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.notifications.length, 2);
      expect(bloc.state.unreadNotificationsCount, 1);
      expect(bloc.state.notifications.first['id'], 'notif_1');
      expect(bloc.state.notifications.first['orderId'], 'QC-260930-0001');

      // Test MarkNotificationReadEvent
      bloc.add(const MarkNotificationReadEvent('notif_1'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.unreadNotificationsCount, 0);
      expect(bloc.state.notifications.first['read'], true);
      expect(bloc.state.notifications.first['isRead'], true);

      await bloc.close();
    });

    test('CustomerPushNotificationReceivedEvent increments badge count and inserts notification', () async {
      final catalogRepo = MockCatalogRepo();
      final orderRepo = MockOrderRepo();
      final localCache = MockLocalCache();

      final bloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: localCache,
      );

      expect(bloc.state.unreadNotificationsCount, 0);
      expect(bloc.state.notifications.isEmpty, true);

      bloc.add(const CustomerPushNotificationReceivedEvent({
        '_id': 'push_notif_99',
        'title': 'Out for Delivery! 🛵',
        'body': 'Your order QC-260930-0009 is out for delivery',
        'type': 'ORDER_UPDATE',
      }));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.unreadNotificationsCount, 1);
      expect(bloc.state.notifications.length, 1);
      expect(bloc.state.notifications.first['title'], 'Out for Delivery! 🛵');
      expect(bloc.state.notifications.first['orderId'], 'QC-260930-0009');
      expect(bloc.state.notifications.first['read'], false);

      // Test MarkAllNotificationsReadEvent
      bloc.add(MarkAllNotificationsReadEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.unreadNotificationsCount, 0);
      expect(bloc.state.notifications.first['read'], true);

      await bloc.close();
    });
  });
}
