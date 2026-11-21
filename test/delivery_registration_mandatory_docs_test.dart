import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quicklink/core/theme/app_theme.dart';
import 'package:quicklink/core/di/service_locator.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_models.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_api_entities.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_registration_screen.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import 'dart:async';
import 'dart:io';

class MockOrderRepo implements IOrderRepository {
  final _ctrl = StreamController<List<OrderEntity>>.broadcast();
  @override
  Stream<List<OrderEntity>> get ordersStream => _ctrl.stream;
  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => const Right([]);
  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async => const Right([]);
  @override
  Future<Either<Failure, OrderEntity>> createOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String storeId,
    required String storeName,
    required String storeAddress,
    required List<OrderItemEntity> items,
    required double deliveryFee,
    required double platformFee,
    String paymentMethod = 'COD',
    String? zoneId,
    String? deliveryAddressId,
    String? couponCode,
    double? couponDiscount,
  }) async => throw UnimplementedError();
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

class MockDeliveryRepo implements IDeliveryRepository {
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
        status: 'PENDING',
        isVerified: false,
      ));

  @override
  Future<Either<Failure, String>> uploadDocument(File file) async =>
      const Right('https://backend/uploads/doc.pdf');

  @override
  Future<Either<Failure, DeliveryPartnerProfileEntity>> registerPartner({
    String? name,
    String? mobile,
    String? email,
    required String vehicleType,
    required String vehicleNumber,
    required String vehicleModel,
    required String licenseNumber,
    String houseAddress = '',
    String selfieUrl = '',
    double? latitude,
    double? longitude,
    String? zoneId,
    required List<DeliveryDocumentEntity> documents,
  }) async => const Right(DeliveryPartnerProfileEntity(
    id: 'del_new',
    userId: 'user_new',
    phone: '+917777777701',
    vehicleType: 'BIKE',
    vehicleNumber: 'KA-50-C-0003',
    vehicleModel: 'Motorcycle',
    licenseNumber: 'KA0000000050',
    availability: 'OFFLINE',
    status: 'PENDING',
    isVerified: false,
  ));

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
    String? reason,
    String? deliveryOtp,
  }) async => const Right({'success': true});

  @override
  Future<Either<Failure, bool>> rejectJob({required String jobId, String? reason}) async => const Right(true);

  @override
  Future<Either<Failure, DeliveryEarningsEntity>> getEarnings() async =>
      const Right(DeliveryEarningsEntity(
        today: PeriodEarningsEntity(amount: 0.0, deliveries: 0),
        thisWeek: PeriodEarningsEntity(amount: 0.0, deliveries: 0),
        thisMonth: PeriodEarningsEntity(amount: 0.0, deliveries: 0),
        lifetime: PeriodEarningsEntity(amount: 0.0, deliveries: 0),
      ));

  @override
  Future<Either<Failure, List<DeliveryDocumentEntity>>> getDocuments() async => const Right([]);

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStorage implements ISecureStorageService {
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken, Duration expiryDuration = const Duration(days: 7)}) async {}
  @override
  Future<String?> getAccessToken() async => 'token_mock';
  @override
  Future<String?> getRefreshToken() async => 'refresh_mock';
  @override
  Future<void> clearAuthData() async {}
  @override
  Future<void> saveUserRole(String role) async {}
  @override
  Future<String?> getUserRole() async => 'deliveryPartner';
  @override
  Future<bool> isSessionValid() async => true;
  @override
  Future<void> saveUserData({required String userId, required String role, String? name, String? phone, String? email, Duration? expiryDuration}) async {}
  @override
  Future<Map<String, String?>> getUserData() async => {'userId': 'u1', 'role': 'deliveryPartner'};
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

  late MockOrderRepo mockOrderRepo;
  late MockDeliveryRepo mockDeliveryRepo;
  late MockStorage mockStorage;
  late DeliveryBloc deliveryBloc;
  late AuthBloc authBloc;

  setUp(() {
    if (sl.isRegistered<IDeliveryRepository>()) sl.unregister<IDeliveryRepository>();
    if (sl.isRegistered<IOrderRepository>()) sl.unregister<IOrderRepository>();
    if (sl.isRegistered<ISecureStorageService>()) sl.unregister<ISecureStorageService>();

    mockOrderRepo = MockOrderRepo();
    mockDeliveryRepo = MockDeliveryRepo();
    mockStorage = MockStorage();

    sl.registerSingleton<IDeliveryRepository>(mockDeliveryRepo);
    sl.registerSingleton<IOrderRepository>(mockOrderRepo);
    sl.registerSingleton<ISecureStorageService>(mockStorage);

    deliveryBloc = DeliveryBloc(orderRepo: mockOrderRepo, deliveryRepo: mockDeliveryRepo);
    authBloc = AuthBloc(mockStorage);
  });

  tearDown(() {
    deliveryBloc.close();
    authBloc.close();
    mockOrderRepo.dispose();
  });

  Widget createTestWidget() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DeliveryBloc>.value(value: deliveryBloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DeliveryRegistrationScreen(autoDetectZone: false),
      ),
    );
  }

  testWidgets('1. Step 0 validation strictly blocks empty fields with SnackBar error', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify on Step 0
    expect(find.text('1. Personal & Residential Home Address'), findsOneWidget);

    // Tap Continue without entering anything
    final continueBtn = find.text('Continue');
    expect(continueBtn, findsOneWidget);
    await tester.tap(continueBtn);
    await tester.pump();

    // Should display SnackBar error for Full Legal Name
    expect(find.text('Full Legal Name is required'), findsOneWidget);
    // Should still be on Step 0
    expect(find.text('1. Personal & Residential Home Address'), findsOneWidget);
  });

  testWidgets('2. Filling Step 0 correctly advances to Step 1 Aadhaar verification with MANDATORY * badges', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Fill in required Step 0 fields
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Rajesh Kumar');
    await tester.enterText(textFields.at(1), '9876543210');
    await tester.enterText(textFields.at(4), 'Flat 402, Green Towers');
    await tester.enterText(textFields.at(5), 'MG Road');
    await tester.enterText(textFields.at(7), 'Bengaluru');
    await tester.enterText(textFields.at(8), 'Karnataka');
    await tester.enterText(textFields.at(9), '560001');

    final continueBtn = find.text('Continue');
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // Successfully navigated to Step 1
    expect(find.text('2. Aadhaar Identity Verification'), findsOneWidget);
    // Verifies MANDATORY * badges are displayed for Aadhaar Front and Back upload cards
    expect(find.text('MANDATORY *'), findsNWidgets(2));
    expect(find.text('Aadhaar Front'), findsOneWidget);
    expect(find.text('Aadhaar Back'), findsOneWidget);
  });

  testWidgets('3. Step 1 strictly enforces 12-digit Aadhaar and mandatory photos before advancing', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Advance to Step 1
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Rajesh Kumar');
    await tester.enterText(textFields.at(1), '9876543210');
    await tester.enterText(textFields.at(4), 'Flat 402');
    await tester.enterText(textFields.at(5), 'MG Road');
    await tester.enterText(textFields.at(7), 'Bengaluru');
    await tester.enterText(textFields.at(8), 'Karnataka');
    await tester.enterText(textFields.at(9), '560001');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // On Step 1: try to continue with invalid Aadhaar
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Aadhaar Number must be exactly 12 digits'), findsOneWidget);

    // Enter 12-digit Aadhaar number
    final aadhaarField = find.byType(TextField).first;
    await tester.enterText(aadhaarField, '123456789012');

    // Tap continue without photos
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('MANDATORY: Please attach Aadhaar Card Front photo'), findsOneWidget);
    // Still on Step 1
    expect(find.text('2. Aadhaar Identity Verification'), findsOneWidget);
  });

  testWidgets('4. In update mode, existing address and KYC details are prefilled properly', (tester) async {
    const existingKyc = RiderKYCEntity(
      riderId: 'del_01',
      fullName: 'Ramesh Patel',
      phone: '9876500001',
      emergencyPhone: '9876500002',
      emergencyRelation: 'Father',
      houseNo: 'Villa 12',
      street: 'Palm Meadows',
      landmark: 'Near Water Tank',
      city: 'Hyderabad',
      state: 'Telangana',
      pincode: '500081',
      aadhaarNumber: '112233445566',
      dlNumber: 'TS0920220011223',
      dlExpiryDate: '2030-05-15',
      vehicleType: 'Scooter (Gearless)',
      vehicleNumber: 'TS-09-AB-1234',
      bankAccount: '12345678901234',
      ifscCode: 'HDFC0004321',
      upiId: 'ramesh@upi',
      faceProfilePhotoUrl: 'https://example.com/selfie.jpg',
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<DeliveryBloc>.value(value: deliveryBloc),
          BlocProvider<AuthBloc>.value(value: authBloc),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DeliveryRegistrationScreen(
            autoDetectZone: false,
            initialName: 'Ramesh Patel',
            initialPhone: '9876500001',
            initialKYC: existingKyc,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Step 0 pre-filled data
    expect(find.text('Ramesh Patel'), findsOneWidget);
    expect(find.text('9876500001'), findsOneWidget);
    expect(find.text('Villa 12'), findsOneWidget);
    expect(find.text('Palm Meadows'), findsOneWidget);
    expect(find.text('Near Water Tank'), findsOneWidget);
    expect(find.text('Hyderabad'), findsOneWidget);
    expect(find.text('Telangana'), findsOneWidget);
    expect(find.text('500081'), findsOneWidget);
    expect(find.text('Father'), findsOneWidget);

    // Advance to Step 1
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify Step 1 Aadhaar pre-filled
    expect(find.text('112233445566'), findsOneWidget);
  });
}
