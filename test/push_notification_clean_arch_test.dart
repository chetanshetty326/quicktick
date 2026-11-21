import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/core/services/push_notification_service.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_entities.dart';
import 'package:quicklink/features/retailer/domain/repositories/retailer_repository.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_registration_status_entity.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';

// --- MOCK CATALOG REPO ---
class MockCatalogRepoForPush implements ICatalogRepository {
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  final _storesCtrl = StreamController<List<StoreEntity>>.broadcast();
  String? registeredFcmToken;
  String? registeredPlatform;
  String? registeredDeviceId;

  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;
  @override
  Stream<List<StoreEntity>> get storesStream => _storesCtrl.stream;

  @override
  Future<Either<Failure, bool>> registerDeviceToken({
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) async {
    registeredFcmToken = fcmToken;
    registeredPlatform = platform;
    registeredDeviceId = deviceId;
    return const Right(true);
  }


  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void dispose() {
    _productsCtrl.close();
    _storesCtrl.close();
  }
}

// --- MOCK ORDER REPO ---
class MockOrderRepoForPush implements IOrderRepository {
  final _ordersCtrl = StreamController<List<OrderEntity>>.broadcast();
  List<OrderEntity> orders = [];

  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersCtrl.stream;

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => Right(orders);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void dispose() {
    _ordersCtrl.close();
  }
}

// --- MOCK RETAILER REPO ---
class MockRetailerRepoForPush implements IRetailerRepository {
  final _ordersCtrl = StreamController<List<OrderEntity>>.broadcast();
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();
  String? registeredFcmToken;
  String? registeredPlatform;
  String? registeredDeviceId;
  List<OrderEntity> liveOrders = [];

  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersCtrl.stream;
  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;

  @override
  Future<Either<Failure, bool>> registerDeviceToken({
    required String fcmToken,
    required String platform,
    required String deviceId,
  }) async {
    registeredFcmToken = fcmToken;
    registeredPlatform = platform;
    registeredDeviceId = deviceId;
    return const Right(true);
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getLiveOrders() async => Right(liveOrders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getOrderHistory() async => const Right([]);
  @override
  Future<Either<Failure, OrderEntity>> acceptOrder(String orderId) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> markPreparing(String orderId) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> markReady(String orderId) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> rejectOrder(String orderId, String reason) async => throw UnimplementedError();
  @override
  Future<Either<Failure, List<ProductEntity>>> getCatalogItems() async => const Right([]);
  @override
  Future<Either<Failure, ProductEntity>> addProduct(ProductEntity product) async => Right(product);
  @override
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product) async => Right(product);
  @override
  Future<Either<Failure, bool>> deleteProduct(String productId) async => const Right(true);
  @override
  Future<Either<Failure, bool>> toggleProductStock(String productId, bool isAvailable, {int? currentStock}) async => const Right(true);
  @override
  Future<Either<Failure, RetailerDashboardStatsEntity>> getDashboardStats() async => throw UnimplementedError();
  @override
  Future<Either<Failure, RetailerStoreProfileEntity>> getStoreProfile() async => throw UnimplementedError();
  @override
  Future<Either<Failure, RetailerStoreProfileEntity>> registerStore(Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<Either<Failure, RetailerStoreProfileEntity>> updateStoreProfile(Map<String, dynamic> data) async => throw UnimplementedError();
  @override
  Future<Either<Failure, bool>> toggleStoreStatus(bool isOpen) async => const Right(true);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async => const Right([]);

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async => const Right(0);

  @override
  Future<Either<Failure, bool>> markAllNotificationsRead() async => const Right(true);

  @override
  Future<Either<Failure, bool>> markNotificationRead(String id) async => const Right(true);

  @override
  Future<Either<Failure, ({bool available, String message})>> checkStoreName(String name) async =>
      const Right((available: true, message: 'Store name is available'));

  @override
  Future<Either<Failure, RetailerCheckRegisteredEntity>> checkRetailerRegistration() async =>
      const Right(RetailerCheckRegisteredEntity(registered: true, status: 'APPROVED'));

  @override
  Future<Either<Failure, RetailerRejectionEntity>> getRejectionReason() async =>
      const Right(RetailerRejectionEntity(status: 'REJECTED', remarks: '', rejectedDocuments: []));

  @override
  Future<Either<Failure, FileUploadEntity>> uploadDocument(String filePath, {String? folder}) async =>
      const Right(FileUploadEntity(url: 'https://cdn.example.com/doc.pdf', publicId: 'doc1', format: 'pdf', bytes: 1024));

  @override
  Future<Either<Failure, RetailerSubscriptionEntity>> getSubscription() async =>
      const Right(RetailerSubscriptionEntity.freeTier);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void dispose() {
    _ordersCtrl.close();
    _productsCtrl.close();
  }
}

class MockLocalCacheServiceForPush implements ILocalCacheService {
  @override
  Future<void> init() async {}
  @override
  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {}
  @override
  List<Map<String, dynamic>> getCartItems() => [];
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
  @override
  String getAppLanguage() => 'en';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Push Notifications Clean Architecture & API Flow Tests', () {
    late MockCatalogRepoForPush catalogRepo;
    late MockOrderRepoForPush orderRepo;
    late MockRetailerRepoForPush retailerRepo;
    late CustomerBloc customerBloc;
    late RetailerBloc retailerBloc;

    setUp(() {
      catalogRepo = MockCatalogRepoForPush();
      orderRepo = MockOrderRepoForPush();
      retailerRepo = MockRetailerRepoForPush();
      customerBloc = CustomerBloc(
        catalogRepo: catalogRepo,
        orderRepo: orderRepo,
        localCache: MockLocalCacheServiceForPush(),
      );
      retailerBloc = RetailerBloc(
        orderRepo: orderRepo,
        catalogRepo: catalogRepo,
        retailerRepo: retailerRepo,
      );
    });

    tearDown(() {
      customerBloc.close();
      retailerBloc.close();
      catalogRepo.dispose();
      orderRepo.dispose();
      retailerRepo.dispose();
    });

    // 1. Customer Token Registration
    test('[POS-01] Customer FCM Token registration delegates to Repository with device metadata', () async {
      customerBloc.add(const RegisterCustomerPushTokenEvent(
        fcmToken: 'fcm_cust_sample_token_99',
        platform: 'android',
        deviceId: 'pixel_7_pro',
      ));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(catalogRepo.registeredFcmToken, 'fcm_cust_sample_token_99');
      expect(catalogRepo.registeredPlatform, 'android');
      expect(catalogRepo.registeredDeviceId, 'pixel_7_pro');
    });

    // 2. Customer Push Notification Arrival & Order Auto-Refresh
    test('[POS-02] CustomerPushNotificationReceivedEvent adds notification to list and refreshes orders', () async {
      final mockOrder = OrderEntity(
        id: 'ord_push_101',
        orderNumber: 'QT-101',
        customerId: 'cust_01',
        customerName: 'Customer',
        customerPhone: '9876543210',
        deliveryAddress: 'Indiranagar',
        storeId: 'store_01',
        storeName: 'Fresh Mart',
        storeAddress: '12th Main',
        items: const [],
        subtotal: 150.0,
        deliveryFee: 15.0,
        platformFee: 5.0,
        grandTotal: 170.0,
        status: OrderStatus.outForDelivery,
        deliveryOtp: '7890',
        createdAt: DateTime.now(),
      );
      orderRepo.orders = [mockOrder];

      customerBloc.add(const CustomerPushNotificationReceivedEvent({
        'id': 'notif_901',
        'title': 'Out for Delivery! 🛵',
        'body': 'Your order #QT-101 is on the way with rider Ramesh.',
        'type': 'ORDER_STATUS_UPDATE',
        'orderId': 'ord_push_101',
      }));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(customerBloc.state.notifications.isNotEmpty, isTrue);
      expect(customerBloc.state.notifications.first['title'], 'Out for Delivery! 🛵');
      expect(customerBloc.state.latestPushNotification?['orderId'], 'ord_push_101');
      expect(customerBloc.state.myOrders.length, 1);
      expect(customerBloc.state.myOrders.first.id, 'ord_push_101');
    });

    // 3. Retailer Token Registration
    test('[POS-03] Retailer FCM Token registration delegates to RetailerRepository with device metadata', () async {
      retailerBloc.add(const RegisterRetailerPushTokenEvent(
        fcmToken: 'fcm_ret_sample_token_88',
        platform: 'web',
        deviceId: 'chrome_browser_session',
      ));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(retailerRepo.registeredFcmToken, 'fcm_ret_sample_token_88');
      expect(retailerRepo.registeredPlatform, 'web');
      expect(retailerRepo.registeredDeviceId, 'chrome_browser_session');
    });

    // 4. Retailer Push Notification Arrival & Live Orders Auto-Sync
    test('[POS-04] RetailerPushNotificationReceivedEvent updates state and auto-syncs live orders', () async {
      final newLiveOrder = OrderEntity(
        id: 'ord_incoming_202',
        orderNumber: 'RET-202',
        customerId: 'cust_02',
        customerName: 'Aarav',
        customerPhone: '9876543210',
        deliveryAddress: 'Koramangala',
        storeId: 'store_01',
        storeName: 'Quick Store',
        storeAddress: 'Main St',
        items: const [],
        subtotal: 320.0,
        deliveryFee: 15.0,
        platformFee: 5.0,
        grandTotal: 340.0,
        status: OrderStatus.placed,
        deliveryOtp: '4321',
        createdAt: DateTime.now(),
      );
      retailerRepo.liveOrders = [newLiveOrder];

      retailerBloc.add(const RetailerPushNotificationReceivedEvent({
        'id': 'notif_ret_01',
        'title': 'New Order Received! ⚡',
        'body': 'Order #RET-202 for ₹340 placed by Aarav.',
        'type': 'NEW_ORDER',
        'orderId': 'ord_incoming_202',
      }));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(retailerBloc.state.latestPushNotification?['orderId'], 'ord_incoming_202');
      expect(retailerBloc.state.successMessage, contains('New Notification'));
      expect(retailerBloc.state.orders.length, 1);
      expect(retailerBloc.state.orders.first.id, 'ord_incoming_202');
    });

    // 5. Payload Model Serialization & Resilience
    test('[POS-05] PushNotificationPayload safely parses standard and custom notification JSON', () {
      final json = {
        'id': 'msg_123',
        'title': 'Special Discount 50% OFF',
        'body': 'Use code QUICK50 for instant discount',
        'type': 'PROMO',
        'data': {
          'deepLink': '/offers/quick50',
          'orderId': 'promo_01',
        },
      };

      final payload = PushNotificationPayload.fromJson(json);
      expect(payload.id, 'msg_123');
      expect(payload.title, 'Special Discount 50% OFF');
      expect(payload.type, 'PROMO');
      expect(payload.deepLink, '/offers/quick50');
      expect(payload.orderId, 'promo_01');
    });

    // 6. Retailer FCM stream + cold-start replay
    test('[POS-06] RetailerBloc consumes cold-start push and foreground FCM stream', () async {
      final ctrl = StreamController<PushNotificationPayload>.broadcast();
      final pending = PushNotificationPayload(
        id: 'ret_cold_1',
        title: 'New Store Order!',
        body: 'Order #RET-501 received.',
        type: 'NEW_ORDER',
        orderId: 'ord_501',
        receivedAt: DateTime.now(),
        fromTap: true,
      );
      final mockPush = _TestPushService(ctrl, pending: pending);
      final localBloc = RetailerBloc(
        orderRepo: orderRepo,
        catalogRepo: catalogRepo,
        retailerRepo: retailerRepo,
        pushNotificationService: mockPush,
        enablePeriodicPolling: false,
      );

      await Future.delayed(const Duration(milliseconds: 60));
      expect(localBloc.state.latestPushNotification?['fromTap'], isTrue);
      expect(localBloc.state.notifications.length, 1);
      expect(localBloc.state.unreadNotificationsCount, 0);

      ctrl.add(PushNotificationPayload(
        id: 'ret_fg_2',
        title: 'Order Ready Reminder',
        body: 'Customer waiting for pickup',
        type: 'ORDER_UPDATE',
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 60));

      expect(localBloc.state.notifications.length, 2);
      expect(localBloc.state.unreadNotificationsCount, 1);

      await localBloc.close();
      await ctrl.close();
    });

    // 7. Delivery FCM stream + cold-start replay + duplicate suppression
    test('[POS-07] DeliveryBloc consumes cold-start push, listens to FCM stream, and deduplicates', () async {
      final ctrl = StreamController<PushNotificationPayload>.broadcast();
      final pending = PushNotificationPayload(
        id: 'deliv_cold_1',
        title: 'New Delivery Job',
        body: 'Pickup from FreshMart',
        type: 'DELIVERY_ASSIGNED',
        orderId: 'job_101',
        receivedAt: DateTime.now(),
        fromTap: true,
      );
      final mockPush = _TestPushService(ctrl, pending: pending);
      final localBloc = DeliveryBloc(
        orderRepo: orderRepo,
        pushNotificationService: mockPush,
      );

      await Future.delayed(const Duration(milliseconds: 60));
      expect(localBloc.state.latestPushNotification?['fromTap'], isTrue);
      expect(localBloc.state.notifications.length, 1);
      expect(localBloc.state.unreadNotificationsCount, 0);

      ctrl.add(PushNotificationPayload(
        id: 'deliv_fg_2',
        title: 'Urgent Job Available',
        body: 'Earn ₹65 for 2.1 km',
        type: 'DELIVERY_ASSIGNED',
        orderId: 'job_202',
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 60));
      expect(localBloc.state.notifications.length, 2);
      expect(localBloc.state.unreadNotificationsCount, 1);

      // Duplicate foreground/socket alert within 10s must be suppressed
      ctrl.add(PushNotificationPayload(
        id: 'deliv_fg_dup',
        title: 'Urgent Job Available',
        body: 'Earn ₹65 for 2.1 km',
        type: 'DELIVERY_ASSIGNED',
        orderId: 'job_202',
        receivedAt: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 60));
      expect(localBloc.state.notifications.length, 2);
      expect(localBloc.state.unreadNotificationsCount, 1);

      await localBloc.close();
      await ctrl.close();
    });
  });
}

class _TestPushService implements IPushNotificationService {
  final StreamController<PushNotificationPayload> _ctrl;
  PushNotificationPayload? _pending;

  _TestPushService(this._ctrl, {PushNotificationPayload? pending}) : _pending = pending;

  @override
  Stream<PushNotificationPayload> get onNotificationReceived => _ctrl.stream;

  @override
  PushNotificationPayload? consumePendingNotification() {
    final p = _pending;
    _pending = null;
    return p;
  }

  @override
  Future<void> initialize({UserRole? role}) async {}

  @override
  Future<String?> getDeviceToken() async => 'fcm_live_test';

  @override
  Future<bool> registerDeviceWithBackend({required String fcmToken, required UserRole role, String? deviceId}) async => true;

  @override
  Future<bool> unregisterDeviceWithBackend({required UserRole role}) async => true;

  @override
  void showInAppBanner(BuildContext context, PushNotificationPayload payload, {VoidCallback? onTap}) {}

  @override
  void simulateIncomingPush(PushNotificationPayload payload) => _ctrl.add(payload);

  @override
  Future<void> showOngoingDeliveryNotification({required String title, required String body, String? subText}) async {}

  @override
  Future<void> cancelOngoingDeliveryNotification() async {}

  @override
  void dispose() {}
}
