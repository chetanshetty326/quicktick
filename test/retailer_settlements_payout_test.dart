import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_registration_screen.dart';

class _FakeOrderRepo implements IOrderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => const Right([]);
}

class _FakeCatalogRepo implements ICatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();

  @override
  Stream<List<StoreEntity>> get storesStream => const Stream.empty();

  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async => const Right([]);

  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async => const Right([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('Retailer Step 4 Bank and Settlements renders responsively without overflow', (WidgetTester tester) async {
    // 1. Small compact screen width (320x640)
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final orderRepo = _FakeOrderRepo();
    final catalogRepo = _FakeCatalogRepo();
    final retailerBloc = RetailerBloc(
      orderRepo: orderRepo,
      catalogRepo: catalogRepo,
      enablePeriodicPolling: false,
    );
    addTearDown(() => retailerBloc.close());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RetailerBloc>.value(
          value: retailerBloc,
          child: const RetailerRegistrationScreen(initialStep: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Step 4 Bank & Settlements header & security card
    expect(find.text('4. Bank Account & Settlements'), findsOneWidget);
    expect(find.text('Direct Automated Bank Settlements'), findsOneWidget);
    expect(find.textContaining('auto-credited every morning'), findsOneWidget);

    // Verify bank account input & visibility toggle button
    final obscureToggle = find.byIcon(Icons.visibility_off_outlined);
    expect(obscureToggle, findsOneWidget);
    await tester.ensureVisible(obscureToggle);
    await tester.tap(obscureToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Verify IFSC Code and UPI ID fields render cleanly
    expect(find.text('Bank IFSC Code *'), findsOneWidget);
    expect(find.textContaining('Instant Settlement UPI ID'), findsOneWidget);

    // Verify submit button is present
    expect(find.text('SUBMIT FOR VERIFICATION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Retailer Settlements & Payouts tab renders responsively on compact screen and supports instant payout modal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final orderRepo = _FakeOrderRepo();
    final catalogRepo = _FakeCatalogRepo();
    final retailerBloc = RetailerBloc(
      orderRepo: orderRepo,
      catalogRepo: catalogRepo,
      enablePeriodicPolling: false,
    );
    addTearDown(() => retailerBloc.close());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RetailerBloc>.value(
          value: retailerBloc,
          child: const RetailerMainScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Tab 3: Settlements & Payouts
    final payoutsTab = find.text('Settlements & Payouts');
    expect(payoutsTab, findsOneWidget);
    await tester.ensureVisible(payoutsTab);
    await tester.tap(payoutsTab);
    await tester.pumpAndSettle();

    // Verify Hero Payout Card
    expect(find.text("TODAY'S NET MERCHANT PAYOUT"), findsOneWidget);
    expect(find.text('Auto-Settling T+1'), findsOneWidget);
    expect(find.textContaining('Gross Sales:'), findsOneWidget);
    expect(find.textContaining('Platform Fee'), findsOneWidget);

    // Verify Automated T+1 Settlement Schedule
    expect(find.text('Automated Settlement Schedule'), findsOneWidget);
    expect(find.text('Cut-off'), findsOneWidget);
    expect(find.text('Reconcile'), findsOneWidget);
    expect(find.text('Bank Credit'), findsOneWidget);

    // Find & tap Express Instant Payout button
    final instantPayoutBtn = find.textContaining('Request Express Instant Payout');
    expect(instantPayoutBtn, findsOneWidget);
    await tester.ensureVisible(instantPayoutBtn);
    await tester.tap(instantPayoutBtn);
    await tester.pumpAndSettle();

    // Verify Instant Payout Bottom Sheet Modal
    expect(find.text('Express Instant Payout'), findsOneWidget);
    expect(find.text('Available Earnings'), findsOneWidget);
    expect(find.text('IMPS Instant Transfer Fee'), findsOneWidget);
    expect(find.text('Net Credit to Bank/UPI'), findsOneWidget);
    expect(find.text('Confirm & Transfer Now'), findsOneWidget);

    // Confirm payout transfer
    await tester.tap(find.text('Confirm & Transfer Now'));
    await tester.pumpAndSettle();

    // Verify SnackBar feedback
    expect(find.textContaining('Instant Payout of'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
