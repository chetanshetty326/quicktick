import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:quicklink/core/network/api_client.dart';
import 'package:quicklink/core/di/service_locator.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/hero_banner_entity.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_entities.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_finance_entities.dart';
import 'package:quicklink/features/retailer/domain/repositories/retailer_repository.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_auth_screen.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_main_screen.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_status_screens.dart';
import 'package:quicklink/features/retailer/presentation/widgets/retailer_order_stats_card.dart';
import 'package:quicklink/features/retailer/presentation/widgets/retailer_reject_dialog.dart';
import 'package:quicklink/features/retailer/presentation/widgets/subscription_renewal_sheet.dart';
import 'package:quicklink/features/retailer/presentation/widgets/retailer_order_details_sheet.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_registration_screen.dart';

class FakeSecureStorage implements ISecureStorageService {
  @override
  Future<void> clearAuthData() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRetailerRepository implements IRetailerRepository {
  final _ordersCtrl = StreamController<List<OrderEntity>>.broadcast();
  final _productsCtrl = StreamController<List<ProductEntity>>.broadcast();

  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersCtrl.stream;

  @override
  Stream<List<ProductEntity>> get productsStream => _productsCtrl.stream;

  @override
  Future<Either<Failure, RetailerStoreProfileEntity>> getStoreProfile() async {
    return const Right(RetailerStoreProfileEntity(
      id: 'store_001',
      storeName: 'Quick Mart Indiranagar',
      ownerName: 'Ramesh Gupta',
      email: 'ramesh@quickmart.in',
      phone: '9876543210',
      fssaiNumber: '12345678901234',
      gstin: '29ABCDE1234F1Z5',
      address: '100ft Rd, Indiranagar, Bengaluru',
      isOpen: true,
      isVerified: true,
      rating: 4.8,
    ));
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getLiveOrders() async => const Right([]);
  @override
  Future<Either<Failure, List<ProductEntity>>> getCatalogItems() async => const Right([]);
  @override
  Future<Either<Failure, RetailerDashboardStatsEntity>> getDashboardStats() async {
    return const Right(RetailerDashboardStatsEntity(
      todayEarnings: 1250,
      totalOrders: 5,
      pendingOrders: 2,
      completedOrders: 3,
      commissionDeducted: 62.5,
      netPayout: 1187.5,
    ));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getNotifications() async => const Right([]);

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async => const Right(0);

  @override
  Future<Either<Failure, RetailerEarningsSummaryEntity>> getEarningsSummary() async {
    return const Right(RetailerEarningsSummaryEntity());
  }

  @override
  Future<Either<Failure, List<RetailerSettlementEntity>>> getSettlements({int limit = 50, int skip = 0}) async => const Right([]);

  @override
  Future<Either<Failure, List<HeroBannerEntity>>> getHeroBanners({String? app, bool forceRefresh = false}) async => const Right([]);

  @override
  Future<Either<Failure, RetailerSubscriptionEntity>> getSubscription() async {
    return Right(RetailerSubscriptionEntity(
      id: 'sub_001',
      planName: 'Pro Merchant Growth Plan',
      price: 999.0,
      commissionPercent: 5.0,
      startsAt: DateTime.now().subtract(const Duration(days: 27)),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
      status: 'ACTIVE',
      isTrial: true,
      daysRemaining: 3,
      canAcceptOrders: true,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOrderRepository implements IOrderRepository {
  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCatalogRepository implements ICatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeRetailerRepository fakeRetailerRepo;
  late FakeOrderRepository fakeOrderRepo;
  late FakeCatalogRepository fakeCatalogRepo;
  late RetailerBloc retailerBloc;
  late AuthBloc authBloc;

  final sampleOrder = OrderEntity(
    id: 'ord_test_01',
    orderNumber: 'QK-8899',
    customerId: 'cust_1',
    customerName: 'Aarav Sharma',
    customerPhone: '9876543210',
    deliveryAddress: '100 Feet Road, Indiranagar',
    storeId: 'store_001',
    storeName: 'Quick Mart',
    storeAddress: 'Indiranagar',
    items: const [
      OrderItemEntity(productId: 'p1', nameSnapshot: 'Milk', priceSnapshot: 30, quantity: 2, unit: '500ml'),
    ],
    subtotal: 60,
    deliveryFee: 15,
    platformFee: 5,
    grandTotal: 80,
    status: OrderStatus.placed,
    deliveryOtp: '123456',
    createdAt: DateTime.now(),
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<SharedPreferences>()) {
      sl.registerSingleton<SharedPreferences>(prefs);
    }
    if (!sl.isRegistered<ISecureStorageService>()) {
      sl.registerSingleton<ISecureStorageService>(FakeSecureStorage());
    }
    if (!sl.isRegistered<ApiClient>()) {
      sl.registerSingleton<ApiClient>(ApiClient(secureStorage: FakeSecureStorage(), dio: Dio()));
    }
  });

  setUp(() {
    fakeRetailerRepo = FakeRetailerRepository();
    fakeOrderRepo = FakeOrderRepository();
    fakeCatalogRepo = FakeCatalogRepository();
    retailerBloc = RetailerBloc(
      orderRepo: fakeOrderRepo,
      catalogRepo: fakeCatalogRepo,
      retailerRepo: fakeRetailerRepo,
    );
    authBloc = AuthBloc(FakeSecureStorage());
  });

  tearDown(() {
    retailerBloc.close();
    authBloc.close();
  });

  Widget buildTestableWidget(Widget child, {Size size = const Size(360, 640), double textScale = 1.0}) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<RetailerBloc>.value(value: retailerBloc),
          BlocProvider<AuthBloc>.value(value: authBloc),
        ],
        child: MaterialApp(
          home: child,
        ),
      ),
    );
  }

  group('Retailer App UI Responsiveness Audits', () {
    testWidgets('1. RetailerAuthScreen renders on 320x568 small phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? caughtErrorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtErrorDetails = details.toString();
        originalOnError?.call(details);
      };

      await tester.pumpWidget(buildTestableWidget(const RetailerAuthScreen(), size: const Size(320, 568)));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      if (caughtErrorDetails != null) {
        // ignore: avoid_print
        print('EXACT WIDGET ERROR:\n$caughtErrorDetails');
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Quick Mart Partner'), findsOneWidget);
    });

    testWidgets('2. RetailerAuthScreen scales cleanly on 768x1024 tablet layout', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const RetailerAuthScreen(), size: const Size(768, 1024)));
      await tester.pumpAndSettle();

      expect(find.text('Quick Mart Partner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. RetailerOrderStatsCard renders on 320px narrow width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(body: SingleChildScrollView(child: RetailerOrderStatsCard())),
          size: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RetailerOrderStatsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. RetailerOrderStatsCard renders on 360x640 standard device', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(body: SingleChildScrollView(child: RetailerOrderStatsCard())),
          size: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RetailerOrderStatsCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. RetailerMainScreen renders on 320x568 small phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const RetailerMainScreen(), size: const Size(320, 568)));
      await tester.pump();

      expect(find.byType(RetailerMainScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. RetailerMainScreen renders on 360x640 standard phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const RetailerMainScreen(), size: const Size(360, 640)));
      await tester.pump();

      expect(find.byType(RetailerMainScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. RetailerMainScreen renders on 768x1024 tablet layout without overflow', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const RetailerMainScreen(), size: const Size(768, 1024)));
      await tester.pump();

      expect(find.byType(RetailerMainScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Accessibility font scaling (1.3x) on RetailerAuthScreen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(
        const RetailerAuthScreen(),
        size: const Size(360, 640),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Quick Mart Partner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. RetailerRejectDialog renders cleanly on 320px narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          RetailerRejectDialog(
            order: sampleOrder,
          ),
          size: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reject Order'), findsOneWidget);
      expect(find.text('Order #QK-8899'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10. SubscriptionRenewalSheet renders cleanly on 320x568 small screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(body: SubscriptionRenewalSheet()),
          size: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionRenewalSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('11. RetailerStatusScreens render cleanly on 320x568', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          const RetailerAwaitingApprovalScreen(shopName: 'Super Grocery'),
          size: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AWAITING APPROVAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('12. RetailerOrderDetailsSheet renders cleanly on 320x568 small screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          RetailerOrderDetailsSheet(order: sampleOrder),
          size: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RetailerOrderDetailsSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('13. RetailerRegistrationScreen renders cleanly on 320x568 small screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          const RetailerRegistrationScreen(),
          size: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RetailerRegistrationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
