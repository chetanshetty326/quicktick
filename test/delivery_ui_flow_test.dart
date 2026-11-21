import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quicklink/core/theme/app_theme.dart';
import 'package:quicklink/core/di/service_locator.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_models.dart';
import 'package:quicklink/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_auth_screen.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_main_screen.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_status_screens.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_active_navigation_screen.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_payment_history_screen.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/delivery/domain/entities/rider_wallet_entities.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import 'dart:async';
import 'dart:io';
import 'package:quicklink/features/delivery/domain/entities/delivery_api_entities.dart';

class MockOrderRepoForUI implements IOrderRepository {
  final _ctrl = StreamController<List<OrderEntity>>.broadcast();
  final List<OrderEntity> orders = [];

  @override
  Stream<List<OrderEntity>> get ordersStream => _ctrl.stream;
  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async => Right(orders);
  @override
  Future<Either<Failure, OrderEntity>> updateOrderStatus({required String orderId, required OrderStatus nextStatus, String? reason}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> updatePaymentStatus({required String orderId, required String paymentStatus}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({required String orderId, required String deliveryPartnerId, required String deliveryPartnerName, required String deliveryPartnerPhone}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({required String orderId, required String enteredOtp}) async => throw UnimplementedError();
  @override
  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason) async => const Right(true);
  @override
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async => const Right(true);
  @override
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId) async => const Right({});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  void dispose() => _ctrl.close();
}

class MockDeliveryRepoForUI implements IDeliveryRepository {
  @override
  Future<Either<Failure, DeliveryPartnerProfileEntity>> getProfile() async =>
      const Right(DeliveryPartnerProfileEntity(
        id: 'del_01',
        userId: 'user_01',
        phone: '+917777777701',
        vehicleType: 'BIKE',
        vehicleNumber: 'KA-50-C-0003',
        vehicleModel: 'Honda Activa 6G',
        licenseNumber: 'KA0000000050',
        availability: 'ONLINE',
        status: 'APPROVED',
        isVerified: true,
      ));

  @override
  Future<Either<Failure, String>> uploadDocument(File file) async =>
      const Right('https://backend/uploads/doc.pdf');

  @override
  Future<Either<Failure, bool>> registerDeviceToken({
    required String deviceToken,
    String platform = 'android',
  }) async => const Right(true);

  @override
  Future<Either<Failure, DeliveryPartnerProfileEntity>> updateProfile(Map<String, dynamic> data) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, String>> setAvailability(String availability) async => Right(availability);

  @override
  Future<Either<Failure, ({double lat, double lng})>> updateLocation({
    required double lat,
    required double lng,
  }) async => const Right((lat: 12.9716, lng: 77.5946));

  @override
  Future<Either<Failure, List<DeliveryJobEntity>>> getJobs({String filter = 'all'}) async => const Right([]);

  @override
  Future<Either<Failure, DeliveryJobEntity>> getJobDetails(String jobId) async => throw UnimplementedError();

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateJobStatus({
    required String jobId,
    required String status,
    String? deliveryOtp,
  }) async => const Right({});

  @override
  Future<Either<Failure, bool>> rejectJob({
    required String jobId,
    required String reason,
  }) async => const Right(true);

  @override
  Future<Either<Failure, DeliveryEarningsEntity>> getEarnings() async =>
      const Right(DeliveryEarningsEntity(
        today: PeriodEarningsEntity(amount: 320.0, deliveries: 5),
        thisWeek: PeriodEarningsEntity(amount: 1850.0, deliveries: 32),
        thisMonth: PeriodEarningsEntity(amount: 7200.0, deliveries: 128),
        lifetime: PeriodEarningsEntity(amount: 15400.0, deliveries: 385),
      ));

  @override
  void clearCache() {}

  @override
  Future<Either<Failure, List<EarningsBreakdownRowEntity>>> getEarningsBreakdown({int limit = 50}) async =>
      const Right([]);

  @override
  Future<Either<Failure, CashCollectedSummaryEntity>> getCashCollected() async =>
      const Right(CashCollectedSummaryEntity(
        totalCashCollected: 0.0,
        totalEarnings: 0.0,
        netOwedToCompany: 0.0,
        netOwedByCompany: 0.0,
      ));

  @override
  Future<Either<Failure, double>> getWalletBalance() async => const Right(350.0);

  @override
  Future<Either<Failure, List<DeliveryTransactionEntity>>> getWalletTransactions() async => const Right([]);

  @override
  Future<Either<Failure, List<RiderBankAccountEntity>>> getBankAccounts() async => const Right([]);

  @override
  Future<Either<Failure, List<RiderWithdrawalEntity>>> getWithdrawals() async => const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSecureStorageServiceForUI implements ISecureStorageService {
  String? _token;
  String? _role;
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken, Duration? expiryDuration}) async => _token = accessToken;
  @override
  Future<String?> getAccessToken() async => _token;
  @override
  Future<String?> getRefreshToken() async => _token;
  @override
  Future<void> clearAuthData() async => _token = null;
  @override
  Future<void> saveUserRole(String role) async => _role = role;
  @override
  Future<String?> getUserRole() async => _role;
  @override
  Future<bool> isSessionValid() async => _token != null;
  @override
  Future<void> saveUserData({required String userId, required String role, String? name, String? phone, String? email, Duration? expiryDuration}) async {}
  @override
  Future<Map<String, String?>> getUserData() async => {'userId': 'u1', 'role': 'deliveryPartner', 'name': 'Arun'};
  @override
  Future<DateTime?> getSessionExpiry() async => DateTime.now().add(const Duration(days: 7));
  @override
  Future<Duration?> getSessionRemainingTime() async => const Duration(days: 7);
  @override
  Future<String?> getUserId() async => 'u1';
  @override
  Future<void> saveUserId(String userId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOrderRepoForUI mockOrderRepo;
  late MockDeliveryRepoForUI mockDeliveryRepo;
  late MockSecureStorageServiceForUI mockStorage;
  late DeliveryBloc deliveryBloc;
  late AuthBloc authBloc;

  setUp(() {
    mockOrderRepo = MockOrderRepoForUI();
    mockDeliveryRepo = MockDeliveryRepoForUI();
    mockStorage = MockSecureStorageServiceForUI();
    deliveryBloc = DeliveryBloc(orderRepo: mockOrderRepo, deliveryRepo: mockDeliveryRepo);
    authBloc = AuthBloc(mockStorage);
  });

  tearDown(() {
    deliveryBloc.close();
    authBloc.close();
    mockOrderRepo.dispose();
  });

  Widget buildTestableWidget(Widget child) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DeliveryBloc>.value(value: deliveryBloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  testWidgets('UI Check: DeliveryAuthScreen renders login form and handles actual phone OTP input', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const DeliveryAuthScreen()));
    await tester.pumpAndSettle();

    // Verify Branding and Input Form
    expect(find.text('QuickReach'), findsOneWidget);
    expect(find.text('Rider Mobile Number'), findsOneWidget);
    expect(find.text('Send Verification OTP'), findsOneWidget);

    // Type phone number into input field
    await tester.enterText(find.byType(TextField).first, '7777777701');
    await tester.pump();

    // Tap Send OTP
    await tester.tap(find.text('Send Verification OTP'));
    await tester.pump();

    // Simulate OtpSentState arrival from AuthBloc
    authBloc.emit(const OtpSentState(phone: '7777777701', message: 'OTP sent', expiresIn: 300, otp: '123456'));
    await tester.pump();

    // Verify OTP field revealed
    expect(find.text('Enter Security OTP'), findsOneWidget);
    expect(find.text('Verify OTP & Start Delivering'), findsOneWidget);
  });

  testWidgets('UI Check: DeliveryPendingApprovalScreen displays approval status and buttons', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const DeliveryPendingApprovalScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    // Check status labels and live action buttons
    expect(find.text('CHECK STATUS FROM SERVER (GET /delivery/me)'), findsOneWidget);
    expect(find.text('APPLICATION DETAILS'), findsOneWidget);
  });

  testWidgets('UI Check: DeliveryMainScreen renders duty status, radar, and navigation items', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    deliveryBloc.emit(deliveryBloc.state.copyWith(
      riderKYC: deliveryBloc.state.riderKYC.copyWith(kycStatus: KYCStatus.verified),
    ));

    await tester.pumpWidget(buildTestableWidget(const DeliveryMainScreen()));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // Check bottom navigation tabs
    expect(find.text('Radar'), findsOneWidget);
    expect(find.text('Active Trip'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('ID Profile'), findsOneWidget);
  });

  testWidgets('UI Check: DeliveryActiveNavigationScreen displays milestone actions and store info', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testOrder = OrderEntity(
      id: 'ord_ui_01',
      orderNumber: 'UI-552',
      customerId: 'c_01',
      customerName: 'Meera Rao',
      customerPhone: '9845012345',
      deliveryAddress: 'Flat 101, Palm Meadows, Whitefield',
      storeId: 's_01',
      storeName: 'Fresh Mart Grocery',
      storeAddress: '100ft Road, Indiranagar',
      items: const [
        OrderItemEntity(
          productId: 'p_1',
          nameSnapshot: 'Organic Milk 1L',
          priceSnapshot: 70.0,
          unit: 'pkt',
          quantity: 2,
        ),
      ],
      subtotal: 140.0,
      deliveryFee: 35.0,
      platformFee: 5.0,
      grandTotal: 180.0,
      status: OrderStatus.assigned,
      deliveryOtp: '5522',
      paymentMethod: 'COD',
      paymentStatus: 'PENDING',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestableWidget(DeliveryActiveNavigationScreen(order: testOrder)));
    await tester.pump(const Duration(milliseconds: 200));

    // Check Store Name, order number and step action button
    expect(find.textContaining('Fresh Mart Grocery'), findsAtLeastNWidgets(1));
    expect(find.text('Trip: #UI-552'), findsOneWidget);
    expect(find.text('I Have Arrived at Store 🏪'), findsOneWidget);
  });

  testWidgets('UI Check: DeliveryPaymentHistoryScreen renders trip history and earnings switcher', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const DeliveryPaymentHistoryScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    // Check View Switcher tabs
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('Cash In Hand'), findsOneWidget);
    expect(find.text('Trips & Wallet'), findsOneWidget);
  });

  testWidgets('UI Check: DeliveryAuthScreen strictly enforces 10-digit mobile number restriction', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const DeliveryAuthScreen()));
    await tester.pumpAndSettle();

    // 1. Enter invalid/short number (8 digits)
    await tester.enterText(find.byType(TextField).first, '98765432');
    await tester.pump();
    expect(find.text('8/10'), findsOneWidget);

    // Tap Send OTP -> Should show SnackBar warning
    await tester.tap(find.text('Send Verification OTP'));
    await tester.pump();
    expect(find.text('Please enter a valid 10-digit mobile number'), findsOneWidget);

    // 2. Enter 12 digits -> Should restrict strictly to 10 digits
    await tester.enterText(find.byType(TextField).first, '987654321099');
    await tester.pump();
    final TextField phoneField = tester.widget(find.byType(TextField).first);
    expect(phoneField.controller?.text.length, 10);
    expect(phoneField.controller?.text, '9876543210');
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('UI Check: DeliveryActiveNavigationScreen integrates live interactive map, markers, and navigation controls', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testOrder = OrderEntity(
      id: 'ord_ui_map',
      orderNumber: 'MAP-101',
      customerId: 'c_01',
      customerName: 'Aarav Gupta',
      customerPhone: '9845099999',
      deliveryAddress: 'Flat 402, Green Glen Layout, Bellandur',
      storeId: 's_01',
      storeName: 'Star Bazaar Indiranagar',
      storeAddress: '100ft Road, Indiranagar',
      items: const [
        OrderItemEntity(
          productId: 'p_1',
          nameSnapshot: 'Organic Eggs 6pcs',
          priceSnapshot: 65.0,
          unit: 'box',
          quantity: 1,
        ),
      ],
      subtotal: 65.0,
      deliveryFee: 40.0,
      platformFee: 5.0,
      grandTotal: 110.0,
      status: OrderStatus.assigned,
      deliveryOtp: '7721',
      paymentMethod: 'ONLINE',
      paymentStatus: 'COMPLETED',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestableWidget(DeliveryActiveNavigationScreen(order: testOrder)));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify map and control elements
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.map), findsOneWidget);
    expect(find.byIcon(Icons.phone), findsOneWidget);
    expect(find.byIcon(Icons.two_wheeler), findsOneWidget);
    expect(find.byIcon(Icons.storefront), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });

  testWidgets('UI Check: DeliveryMainScreen gatekeeper redirects unapproved partner to DeliveryPendingApprovalScreen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Provide an unapproved (PENDING) profile
    const pendingProfile = DeliveryPartnerProfileEntity(
      id: 'del_pending_01',
      userId: 'u_pen_01',
      phone: '+917777777701',
      vehicleType: 'BIKE',
      vehicleNumber: 'KA-01-AB-1234',
      vehicleModel: 'Honda Activa',
      licenseNumber: 'KA0120220001234',
      availability: 'OFFLINE',
      status: 'PENDING',
      isVerified: false,
    );

    deliveryBloc.emit(deliveryBloc.state.copyWith(apiProfile: pendingProfile));

    await tester.pumpWidget(buildTestableWidget(const DeliveryMainScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    // Dashboard tabs should NOT be visible; Pending approval screen should be rendered!
    expect(find.byType(DeliveryPendingApprovalScreen), findsOneWidget);
    expect(find.text('Application Under Review'), findsOneWidget);
  });

  testWidgets('UI Check: DeliveryAuthScreen supports Sign Up mode with Name input for new partners', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const DeliveryAuthScreen(initialIsSignUp: true)));
    await tester.pumpAndSettle();

    // Verify Sign Up mode elements
    expect(find.textContaining('Full Legal Name'), findsOneWidget);
    expect(find.text('Send Registration OTP'), findsOneWidget);
    expect(find.text('New Partner • Sign Up'), findsOneWidget);

    // Switch to Sign In
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Send Verification OTP'), findsOneWidget);
  });
}
