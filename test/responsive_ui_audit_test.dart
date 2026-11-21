import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quicklink/core/di/service_locator.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/core/widgets/legal_policy_screen.dart';
import 'package:quicklink/core/widgets/location_disclosure_dialog.dart';
import 'package:quicklink/core/widgets/delete_account_dialog.dart';
import 'package:quicklink/features/customer/presentation/widgets/initial_location_prompt_sheet.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_active_navigation_screen.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_auth_screen.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import 'dart:async';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/auth/presentation/screens/login_screen.dart';

class FakeSecureStorage implements ISecureStorageService {
  @override
  Future<void> clearAuthData() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOrderRepo implements IOrderRepository {
  final _ctrl = StreamController<List<OrderEntity>>.broadcast();
  @override
  Stream<List<OrderEntity>> get ordersStream => _ctrl.stream;
  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => const Right([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDeliveryRepo implements IDeliveryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<SharedPreferences>()) {
      sl.registerSingleton<SharedPreferences>(prefs);
    }
    if (!sl.isRegistered<ISecureStorageService>()) {
      sl.registerSingleton<ISecureStorageService>(FakeSecureStorage());
    }
  });

  Widget buildTestableWidget(Widget child, {Size size = const Size(360, 640)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(FakeSecureStorage()),
      child: MaterialApp(
        home: child,
      ),
    ),
  );
}

  group('UI Responsiveness Audits across Screen Resolutions', () {
    testWidgets('1. LegalPolicyScreen renders cleanly on 320x568 small phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const LegalPolicyScreen(), size: const Size(320, 568)));
      await tester.pumpAndSettle();

      expect(find.byType(LegalPolicyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. LegalPolicyScreen adapts to 768x1024 tablet layout', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const LegalPolicyScreen(), size: const Size(768, 1024)));
      await tester.pumpAndSettle();

      expect(find.byType(LegalPolicyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. LocationDisclosureDialog renders on narrow 320px screen without clipping', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: LocationDisclosureDialog(
              isDeliveryPartner: true,
              onAccept: () {},
              onDeny: () {},
            ),
          ),
          size: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Access Notice'), findsOneWidget);
      expect(find.text('Agree & Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. DeleteAccountDialog renders on 320px phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: DeleteAccountDialog(isDeliveryPartner: false),
          ),
          size: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Permanently Delete Account?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. InitialLocationPromptSheet renders on 320x568 small phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: InitialLocationPromptSheet(animate: false),
          ),
          size: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Where should we deliver?'), findsOneWidget);
      expect(find.text('Use Current Location (GPS)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. DeliveryActiveNavigationScreen adapts responsively on 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyOrder = OrderEntity(
        id: 'ord_123',
        orderNumber: 'QK-9921',
        customerId: 'cust_1',
        customerName: 'Aarav Patel',
        customerPhone: '+919876543210',
        deliveryAddress: 'Flat 402, Green Glen Layout, Bellandur, Bengaluru',
        storeId: 'store_1',
        storeName: 'BigBasket Dark Store #4',
        storeAddress: 'Outer Ring Rd, Marathahalli, Bengaluru',
        items: [
          const OrderItemEntity(
            productId: 'p1',
            nameSnapshot: 'Organic Milk 1L',
            priceSnapshot: 65,
            quantity: 2,
            unit: '1L',
          ),
        ],
        subtotal: 130,
        deliveryFee: 25,
        platformFee: 5,
        grandTotal: 160,
        status: OrderStatus.assigned,
        deliveryOtp: '123456',
        paymentStatus: 'PAID',
        paymentMethod: 'ONLINE',
        createdAt: DateTime.now(),
      );

      final fakeOrderRepo = FakeOrderRepo();
      final fakeDeliveryRepo = FakeDeliveryRepo();
      final bloc = DeliveryBloc(orderRepo: fakeOrderRepo, deliveryRepo: fakeDeliveryRepo);

      await tester.pumpWidget(
        BlocProvider<DeliveryBloc>.value(
          value: bloc,
          child: buildTestableWidget(
            DeliveryActiveNavigationScreen(order: dummyOrder),
            size: const Size(360, 640),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Trip: #QK-9921'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. DeliveryAuthScreen renders on 320x568 small phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const DeliveryAuthScreen(), size: const Size(320, 568)));
      await tester.pumpAndSettle();

      expect(find.text('Partner Sign In'), findsOneWidget);
      expect(find.text('Send Verification OTP'), findsOneWidget);
      expect(find.text('Partner Agreement'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Accessibility font scaling (1.35x) adapts without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.35),
          ),
          child: const MaterialApp(
            home: LegalPolicyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LegalPolicyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. Customer LoginScreen renders on 320x568 small phone without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const LoginScreen(), size: const Size(320, 568)));
      await tester.pumpAndSettle();

      expect(find.text('Quick Tick'), findsOneWidget);
      expect(find.text('Create New Account'), findsOneWidget);
      expect(find.text('Mobile OTP'), findsNothing);
      expect(find.text('Gmail / Email Address *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10. Customer LoginScreen scales cleanly on 768x1024 tablet layout', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const LoginScreen(), size: const Size(768, 1024)));
      await tester.pumpAndSettle();

      expect(find.text('Quick Tick'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
