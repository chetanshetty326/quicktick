import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/data/models/check_mobile_response_model.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_models.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_api_entities.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_notification_entity.dart';
import 'package:quicklink/features/delivery/domain/entities/doorstep_qr_entity.dart';
import 'package:quicklink/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_event.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_state.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'dart:async';
import 'dart:io';

// ---------------------------------------------------------
// MOCKS FOR FULL FLOW TESTING
// ---------------------------------------------------------

class MockAuthRemoteDataSource implements IAuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<CheckMobileResponseModel> checkMobile(String phone) async {
    return const CheckMobileResponseModel(
      success: true,
      exists: true,
      role: 'delivery_partner',
    );
  }

  @override
  Future<SendOtpResponseModel> sendOtp(String phone, {String? email, String? name}) async {
    return const SendOtpResponseModel(
      success: true,
      message: 'OTP sent successfully',
      expiresIn: 300,
      otp: '522528',
      devOtp: '522528',
    );
  }

  @override
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? challengeId,
  }) async {
    if (otp == '522528' || otp == '897831') {
      return AuthResponseModel(
        user: UserEntity(
          id: 'rider_live_01',
          name: 'Vikram Singh',
          phone: phone.isNotEmpty ? phone : '+919876543210',
          role: UserRole.deliveryPartner,
          isApproved: true,
          status: 'ACTIVE',
        ),
        accessToken: 'mock_jwt_access_token',
        refreshToken: 'mock_jwt_refresh_token',
      );
    }
    throw const ServerFailure(message: 'Invalid OTP entered', statusCode: 400);
  }

  @override
  Future<AuthResponseModel> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    return const AuthResponseModel(
      user: UserEntity(
        id: 'rider_live_01',
        name: 'Vikram Singh',
        phone: '+919876543210',
        role: UserRole.deliveryPartner,
        isApproved: true,
        status: 'ACTIVE',
      ),
      accessToken: 'mock_jwt_access_token',
      refreshToken: 'mock_jwt_refresh_token',
    );
  }

  @override
  Future<Map<String, String>> refreshToken(String refreshToken) async => {
    'accessToken': 'new_mock_access_token',
    'refreshToken': 'new_mock_refresh_token',
  };

  @override
  Future<bool> logout({String? deviceId, String? fcmToken}) async => true;

  @override
  Future<UserEntity> getMe() async => const UserEntity(
    id: 'rider_live_01',
    name: 'Vikram Singh',
    phone: '+919876543210',
    role: UserRole.deliveryPartner,
  );

  @override
  Future<UserEntity> updateProfile({required String name, String? email, String? phone, String? avatarUrl}) async =>
      const UserEntity(
        id: 'rider_live_01',
        name: 'Vikram Singh',
        phone: '+919876543210',
        role: UserRole.deliveryPartner,
      );
}

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
    double? lat,
    double? lng,
    String? city,
    String? postalCode,
    double tip = 0.0,
  }) async => throw UnimplementedError();

  String? lastUpdatedOrderId;
  OrderStatus? lastUpdatedStatus;
  @override
  Future<Either<Failure, OrderEntity>> updateOrderStatus({required String orderId, required OrderStatus nextStatus, String? reason}) async {
    lastUpdatedOrderId = orderId;
    lastUpdatedStatus = nextStatus;
    return Right(_buildDummyOrder(orderId).copyWith(status: nextStatus));
  }

  @override
  Future<Either<Failure, OrderEntity>> updatePaymentStatus({required String orderId, required String paymentStatus}) async =>
      Right(_buildDummyOrder(orderId));

  String? lastAssignedOrderId;
  String? lastAssignedRiderId;
  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({
    required String orderId,
    required String deliveryPartnerId,
    required String deliveryPartnerName,
    required String deliveryPartnerPhone,
  }) async {
    lastAssignedOrderId = orderId;
    lastAssignedRiderId = deliveryPartnerId;
    return Right(_buildDummyOrder(orderId).copyWith(
      status: OrderStatus.assigned,
      deliveryPartnerId: deliveryPartnerId,
    ));
  }

  String? lastVerifiedOrderId;
  String? lastEnteredOtp;
  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({required String orderId, required String enteredOtp}) async {
    lastVerifiedOrderId = orderId;
    lastEnteredOtp = enteredOtp;
    return Right(_buildDummyOrder(orderId).copyWith(status: OrderStatus.delivered));
  }

  @override
  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason) async => const Right(true);
  @override
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async => const Right(true);
  @override
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId) async => const Right({});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  void dispose() => _ctrl.close();

  OrderEntity _buildDummyOrder(String id) => OrderEntity(
    id: id,
    orderNumber: 'ORD-$id',
    customerId: 'cust_01',
    customerName: 'Aarav Patel',
    customerPhone: '+919876543210',
    deliveryAddress: 'Flat 101, Sunshine Apts, Bengaluru',
    storeId: 'store_01',
    storeName: 'Quick Supermarket',
    storeAddress: '12th Main Road, Bengaluru',
    items: const [],
    subtotal: 350.0,
    deliveryFee: 45.0,
    platformFee: 5.0,
    grandTotal: 400.0,
    status: OrderStatus.assigned,
    deliveryOtp: '4589',
    paymentMethod: 'COD',
    createdAt: DateTime.now(),
  );
}

class MockDeliveryRepo implements IDeliveryRepository {
  DeliveryPartnerProfileEntity currentProfile = const DeliveryPartnerProfileEntity(
    id: 'rider_01',
    userId: 'user_01',
    phone: '+919876543210',
    vehicleType: 'BIKE',
    vehicleNumber: 'KA-01-AB-1234',
    vehicleModel: 'Honda Activa 6G',
    licenseNumber: 'KA0120220001234',
    availability: 'ONLINE',
    status: 'APPROVED',
    isVerified: true,
    zoneId: '6abe8daf523e496cfdd80053',
    zoneName: 'Bengaluru Zone',
  );

  bool failNextJobAcceptWithTaken = false;
  String? lastUpdatedJobId;
  String? lastUpdatedStatus;
  String? lastOtp;
  String? lastAvailability;

  @override
  Future<Either<Failure, DeliveryPartnerProfileEntity>> getProfile() async => Right(currentProfile);

  @override
  Future<Either<Failure, String>> uploadDocument(File file) async =>
      const Right('https://api.quicktick.shop/uploads/doc.pdf');

  @override
  Future<Either<Failure, DeliveryPartnerProfileEntity>> registerPartner({
    required String vehicleType,
    required String vehicleNumber,
    required String vehicleModel,
    required String licenseNumber,
    String? name,
    String? mobile,
    String? email,
    String houseAddress = '',
    String selfieUrl = '',
    double? latitude,
    double? longitude,
    String? zoneId,
    required List<DeliveryDocumentEntity> documents,
  }) async {
    currentProfile = currentProfile.copyWith(
      vehicleType: vehicleType,
      vehicleNumber: vehicleNumber,
      vehicleModel: vehicleModel,
      licenseNumber: licenseNumber,
      latitude: latitude,
      longitude: longitude,
      zoneId: zoneId,
      status: 'PENDING',
      isVerified: false,
    );
    return Right(currentProfile);
  }

  @override
  Future<Either<Failure, bool>> registerDeviceToken({required String deviceToken, String platform = 'android'}) async =>
      const Right(true);

  @override
  Future<Either<Failure, DeliveryPartnerProfileEntity>> updateProfile(Map<String, dynamic> data) async =>
      Right(currentProfile);

  @override
  Future<Either<Failure, String>> setAvailability(String availability) async {
    lastAvailability = availability;
    currentProfile = currentProfile.copyWith(availability: availability);
    return Right(availability);
  }

  @override
  Future<Either<Failure, ({double lat, double lng})>> updateLocation({required double lat, required double lng}) async {
    currentProfile = currentProfile.copyWith(latitude: lat, longitude: lng);
    return Right((lat: lat, lng: lng));
  }

  @override
  void clearCache() {}

  List<DeliveryJobEntity>? customJobs;

  @override
  Future<Either<Failure, List<DeliveryJobEntity>>> getJobs({String filter = 'all'}) async {
    return Right(customJobs ?? [
      DeliveryJobEntity(
        id: 'job_101',
        orderNumber: 'ORD-101',
        status: 'OFFERED',
        total: 450.0,
        deliveryFee: 50.0,
        paymentMethod: 'COD',
        customer: const DeliveryJobCustomerEntity(id: 'c1', name: 'Aarav Patel', mobile: '+919876543210'),
        retailer: const DeliveryJobRetailerEntity(id: 'r1', shopName: 'Quick Supermarket', phone: '+918022223333'),
        storeAddress: '12th Main Road, Indiranagar',
        deliveryAddress: 'Flat 402, Sunshine Towers',
        zoneId: '6abe8daf523e496cfdd80053',
        deliveryOtp: '4589',
        createdAt: DateTime.now(),
      ),
    ]);
  }

  @override
  Future<Either<Failure, DeliveryJobEntity>> getJobDetails(String jobId) async {
    return Right(
      DeliveryJobEntity(
        id: jobId,
        orderNumber: 'ORD-$jobId',
        status: 'ASSIGNED',
        total: 450.0,
        deliveryFee: 50.0,
        paymentMethod: 'COD',
        customer: const DeliveryJobCustomerEntity(id: 'c1', name: 'Aarav Patel', mobile: '+919876543210'),
        retailer: const DeliveryJobRetailerEntity(id: 'r1', shopName: 'Quick Supermarket', phone: '+918022223333'),
        storeAddress: '12th Main Road, Indiranagar',
        deliveryAddress: 'Flat 402, Sunshine Towers',
        zoneId: '6abe8daf523e496cfdd80053',
        deliveryOtp: '4589',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateJobStatus({
    required String jobId,
    required String status,
    String? deliveryOtp,
  }) async {
    if (failNextJobAcceptWithTaken && (status == 'ASSIGNED' || status == 'ACCEPTED')) {
      return const Left(JobTakenFailure(message: "Offer expired. You'll get the next one."));
    }
    lastUpdatedJobId = jobId;
    lastUpdatedStatus = status;
    lastOtp = deliveryOtp;
    return Right({'jobId': jobId, 'status': status});
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> reportCodDelivered({
    required String assignmentId,
    required String otpCode,
    required double collectedAmount,
    bool paymentCollected = true,
  }) async {
    lastUpdatedJobId = assignmentId;
    lastUpdatedStatus = 'DELIVERED';
    lastOtp = otpCode;
    return Right({
      'assignmentId': assignmentId,
      'status': 'DELIVERED',
      'paymentCollected': paymentCollected,
      'collectedAmount': collectedAmount,
    });
  }

  @override
  Future<Either<Failure, bool>> rejectJob({required String jobId, required String reason}) async => const Right(true);

  @override
  Future<Either<Failure, DeliveryEarningsEntity>> getEarnings() async => Right(
    DeliveryEarningsEntity(
      today: const PeriodEarningsEntity(amount: 450.0, deliveries: 6),
      thisWeek: const PeriodEarningsEntity(amount: 2850.0, deliveries: 38),
      thisMonth: const PeriodEarningsEntity(amount: 11200.0, deliveries: 154),
      lifetime: const PeriodEarningsEntity(amount: 35000.0, deliveries: 480),
    ),
  );

  @override
  Future<Either<Failure, List<EarningsBreakdownRowEntity>>> getEarningsBreakdown({int limit = 50}) async => Right([
    EarningsBreakdownRowEntity(
      id: 'tx_01',
      orderId: 'ord_101',
      orderNumber: 'ORD-101',
      total: 70.0,
      paymentMethod: 'COD',
      orderStatus: 'DELIVERED',
      basePay: 35.0,
      distancePay: 15.0,
      surgeBonus: 10.0,
      tipFromCustomer: 10.0,
      penalty: 0.0,
      totalEarning: 70.0,
      cashCollected: 450.0,
      netPayout: 70.0,
      distanceKm: 2.5,
      status: 'SETTLED',
      createdAt: DateTime.now(),
    ),
  ]);

  @override
  Future<Either<Failure, CashCollectedSummaryEntity>> getCashCollected() async => const Right(
    CashCollectedSummaryEntity(
      totalCashCollected: 750.0,
      totalEarnings: 450.0,
      netOwedToCompany: 300.0,
      netOwedByCompany: 0.0,
    ),
  );

  @override
  Future<Either<Failure, List<DeliveryNotificationEntity>>> getNotifications({int page = 1, int limit = 20}) async =>
      Right([
        DeliveryNotificationEntity(
          id: 'notif_1',
          title: 'Order Assigned',
          body: 'Order #ORD-101 assigned to you',
          type: 'ORDER_ASSIGNED',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ]);

  @override
  Future<Either<Failure, int>> getUnreadNotificationCount() async => const Right(1);

  @override
  Future<Either<Failure, bool>> markNotificationAsRead(String id) async => const Right(true);

  @override
  Future<Either<Failure, bool>> markAllNotificationsAsRead() async => const Right(true);

  @override
  Future<Either<Failure, DoorstepQrEntity>> requestDoorstepQr(String orderId, {int? validitySeconds}) async =>
      Right(DoorstepQrEntity(
        orderId: orderId,
        orderNumber: 'QC-261017-0042',
        amount: 250,
        qrId: 'qr_test',
        imageUrl: 'https://rzp.io/i/test.png',
        upiIntent: 'upi://pay?pa=quicktick@razorpay',
        paymentStatus: 'PENDING',
      ));

  @override
  Future<Either<Failure, QrPaymentStatusEntity>> getQrPaymentStatus(String orderId) async =>
      const Right(QrPaymentStatusEntity(
        orderId: 'test',
        orderNumber: 'QC-261017-0042',
        paymentStatus: 'COMPLETED',
        razorpayPaymentId: 'pay_test',
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------
// TEST SUITE: DELIVERY APP END-TO-END FLOW VERIFICATION
// ---------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRemoteDataSource authRemoteDataSource;
  late MockOrderRepo mockOrderRepo;
  late MockDeliveryRepo mockDeliveryRepo;
  late DeliveryBloc deliveryBloc;

  setUp(() {
    authRemoteDataSource = MockAuthRemoteDataSource();
    mockOrderRepo = MockOrderRepo();
    mockDeliveryRepo = MockDeliveryRepo();

    deliveryBloc = DeliveryBloc(
      orderRepo: mockOrderRepo,
      deliveryRepo: mockDeliveryRepo,
    );
  });

  tearDown(() {
    deliveryBloc.close();
    mockOrderRepo.dispose();
  });

  group('1. Delivery Partner Authentication Flow', () {
    test('CheckMobile identifies DELIVERY_PARTNER role properly', () async {
      final res = await authRemoteDataSource.checkMobile('+919876543210');
      expect(res.success, isTrue);
      expect(res.exists, isTrue);
      expect(res.role, equals('delivery_partner'));
    });

    test('SendOtp dispatches and returns development OTP for seamless flow', () async {
      final res = await authRemoteDataSource.sendOtp('+919876543210', name: 'Vikram Singh');
      expect(res.success, isTrue);
      expect(res.otp, equals('522528'));
    });

    test('VerifyOtp authenticates and issues Delivery Partner UserEntity', () async {
      final authRes = await authRemoteDataSource.verifyOtp(
        phone: '+919876543210',
        otp: '522528',
        role: 'delivery_partner',
      );
      expect(authRes.user.role, equals(UserRole.deliveryPartner));
      expect(authRes.accessToken, isNotEmpty);
      expect(authRes.user.isApproved, isTrue);
    });

    test('VerifyOtp with incorrect OTP throws Failure gracefully', () async {
      expect(
        () => authRemoteDataSource.verifyOtp(
          phone: '+919876543210',
          otp: '000000',
          role: 'delivery_partner',
        ),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('2. Delivery Partner Profile & Registration Data Flow', () {
    test('FetchDeliveryProfileEvent populates state with profile from repository', () async {
      deliveryBloc.add(const FetchDeliveryProfileEvent());
      await pumpEventQueue();

      expect(deliveryBloc.state.apiProfile?.phone, equals('+919876543210'));
      expect(deliveryBloc.state.apiProfile?.vehicleNumber, equals('KA-01-AB-1234'));
      expect(deliveryBloc.state.apiProfile?.zoneId, equals('6abe8daf523e496cfdd80053'));
      expect(deliveryBloc.state.riderKYC.kycStatus, equals(KYCStatus.verified));
    });

    test('registerPartner handles vehicle details and documents without crashing', () async {
      final docList = [
        const DeliveryDocumentEntity(
          type: DeliveryDocumentType.aadhaar,
          url: 'https://api.quicktick.shop/uploads/aadhaar.pdf',
          number: '123456789012',
        ),
        const DeliveryDocumentEntity(
          type: DeliveryDocumentType.license,
          url: 'https://api.quicktick.shop/uploads/license.pdf',
          number: 'KA0120220001234',
        ),
        const DeliveryDocumentEntity(
          type: DeliveryDocumentType.rc,
          url: 'https://api.quicktick.shop/uploads/rc.pdf',
          number: 'KA01AB1234',
        ),
      ];

      final regRes = await mockDeliveryRepo.registerPartner(
        vehicleType: 'BIKE',
        vehicleNumber: 'KA-01-AB-1234',
        vehicleModel: 'Honda Activa 6G',
        licenseNumber: 'KA0120220001234',
        houseAddress: '12th Main Road, Indiranagar',
        latitude: 12.9716,
        longitude: 77.5946,
        zoneId: '6abe8daf523e496cfdd80053',
        documents: docList,
      );

      regRes.fold((l) => fail('Registration failed: ${l.message}'), (p) {
        expect(p.vehicleNumber, equals('KA-01-AB-1234'));
        expect(p.status, equals('PENDING'));
        expect(p.isVerified, isFalse);
      });
    });
  });

  group('3. Duty Toggle & Online Status Enforcement Flow', () {
    test('Unverified rider cannot toggle duty ONLINE (FR-DEL-002 check)', () async {
      // Set KYC status to underReview and initially offline
      deliveryBloc.emit(deliveryBloc.state.copyWith(
        isOnline: false,
        riderKYC: deliveryBloc.state.riderKYC.copyWith(kycStatus: KYCStatus.underReview),
        isFaceVerifiedToday: true,
      ));

      deliveryBloc.add(const ToggleDutyEvent(true));
      await pumpEventQueue();

      expect(deliveryBloc.state.isOnline, isFalse);
      expect(deliveryBloc.state.errorMessage, contains('Admin approval required'));
    });

    test('Verified rider without Face verification cannot go ONLINE', () async {
      deliveryBloc.emit(deliveryBloc.state.copyWith(
        isOnline: false,
        riderKYC: deliveryBloc.state.riderKYC.copyWith(kycStatus: KYCStatus.verified),
        isFaceVerifiedToday: false,
      ));

      deliveryBloc.add(const ToggleDutyEvent(true));
      await pumpEventQueue();

      expect(deliveryBloc.state.isOnline, isFalse);
      expect(deliveryBloc.state.errorMessage, contains('Face Selfie'));
    });

    test('Verified rider with Face confirmation successfully goes ONLINE and informs repository', () async {
      deliveryBloc.emit(deliveryBloc.state.copyWith(
        riderKYC: deliveryBloc.state.riderKYC.copyWith(kycStatus: KYCStatus.verified),
        isFaceVerifiedToday: true,
      ));

      deliveryBloc.add(const ToggleDutyEvent(true));
      await pumpEventQueue();

      expect(deliveryBloc.state.isOnline, isTrue);
      expect(mockDeliveryRepo.lastAvailability, equals('ONLINE'));
    });
  });

  group('4. Job Acceptance & Single Active Job Rule (FR-DEL-005)', () {
    test('FetchDeliveryJobsEvent retrieves available offered jobs', () async {
      deliveryBloc.add(const FetchDeliveryJobsEvent(filter: 'all'));
      await pumpEventQueue();

      expect(deliveryBloc.state.apiJobs.length, equals(1));
      expect(deliveryBloc.state.apiJobs.first.id, equals('job_101'));
    });

    test('FetchDeliveryJobsEvent places ASSIGNED order (e.g. Order 0014) into availableJobs so Radar renders it', () async {
      mockDeliveryRepo.customJobs = [
        DeliveryJobEntity(
          id: 'order_0014',
          orderNumber: '0014',
          status: 'ASSIGNED',
          total: 520.0,
          deliveryFee: 40.0,
          paymentMethod: 'UPI',
          customer: const DeliveryJobCustomerEntity(id: 'c1', name: 'Ravi Kumar', mobile: '+919988776655'),
          retailer: const DeliveryJobRetailerEntity(id: 'r1', shopName: 'Fresh Mart', phone: '+918011223344'),
          storeAddress: 'Indiranagar 100ft Rd',
          deliveryAddress: 'Koramangala 4th Block',
          zoneId: '6abe8daf523e496cfdd80053',
          deliveryPartnerId: 'user_gagan_id_99',
          deliveryOtp: '1234',
          createdAt: DateTime.now(),
        ),
      ];

      deliveryBloc.add(const FetchDeliveryJobsEvent(filter: 'all'));
      await pumpEventQueue();

      expect(deliveryBloc.state.apiJobs.length, equals(1));
      expect(deliveryBloc.state.apiJobs.first.id, equals('order_0014'));
      expect(deliveryBloc.state.availableJobs.length, equals(1));
      expect(deliveryBloc.state.availableJobs.first.id, equals('order_0014'));
      expect(deliveryBloc.state.incomingJobAlert, isNotNull);
      expect(deliveryBloc.state.incomingJobAlert?.id, equals('order_0014'));
    });

    test('AcceptDeliveryJobEvent accepts offer and assigns order to partner', () async {
      deliveryBloc.emit(deliveryBloc.state.copyWith(
        riderKYC: deliveryBloc.state.riderKYC.copyWith(
          kycStatus: KYCStatus.verified,
          riderId: 'rider_01',
          fullName: 'Vikram Singh',
        ),
        availableJobs: [
          OrderEntity(
            id: 'job_101',
            orderNumber: 'ORD-101',
            customerId: 'c1',
            customerName: 'Aarav Patel',
            customerPhone: '+919876543210',
            deliveryAddress: 'Flat 402, Sunshine Towers',
            storeId: 'r1',
            storeName: 'Quick Supermarket',
            storeAddress: '12th Main Road',
            items: const [],
            subtotal: 400.0,
            deliveryFee: 50.0,
            platformFee: 0.0,
            grandTotal: 450.0,
            status: OrderStatus.readyForPickup,
            deliveryOtp: '4589',
            createdAt: DateTime.now(),
          ),
        ],
      ));

      deliveryBloc.add(const AcceptDeliveryJobEvent(orderId: 'job_101'));
      await pumpEventQueue();

      expect(mockDeliveryRepo.lastUpdatedJobId, equals('job_101'));
      expect(mockDeliveryRepo.lastUpdatedStatus, anyOf(equals('ASSIGNED'), equals('ACCEPTED')));
      expect(deliveryBloc.state.activeTrips.length, equals(1));
      expect(deliveryBloc.state.activeJobStep, equals(DeliveryTripStep.enRouteStore));
    });

    test('Single Active Job rule blocks accepting a second order concurrently', () async {
      // Set state to have an active trip already
      deliveryBloc.emit(deliveryBloc.state.copyWith(
        riderKYC: deliveryBloc.state.riderKYC.copyWith(kycStatus: KYCStatus.verified),
        activeTrips: [
          OrderEntity(
            id: 'active_01',
            orderNumber: 'ORD-01',
            customerId: 'c1',
            customerName: 'Customer',
            customerPhone: '9999999999',
            deliveryAddress: 'Addr',
            storeId: 's1',
            storeName: 'Store',
            storeAddress: 'Store Addr',
            items: const [],
            subtotal: 100,
            deliveryFee: 30,
            platformFee: 0,
            grandTotal: 130,
            status: OrderStatus.assigned,
            deliveryOtp: '1111',
            createdAt: DateTime.now(),
          ),
        ],
      ));

      deliveryBloc.add(const AcceptDeliveryJobEvent(orderId: 'job_102'));
      await pumpEventQueue();

      expect(deliveryBloc.state.errorMessage, contains('Single Active Job rule'));
    });

    test('409 JOB_TAKEN gracefully removes job and alerts rider', () async {
      mockDeliveryRepo.failNextJobAcceptWithTaken = true;

      deliveryBloc.emit(deliveryBloc.state.copyWith(
        riderKYC: deliveryBloc.state.riderKYC.copyWith(kycStatus: KYCStatus.verified),
        availableJobs: [
          OrderEntity(
            id: 'job_taken_99',
            orderNumber: 'ORD-99',
            customerId: 'c1',
            customerName: 'Customer',
            customerPhone: '9999999999',
            deliveryAddress: 'Addr',
            storeId: 's1',
            storeName: 'Store',
            storeAddress: 'Store Addr',
            items: const [],
            subtotal: 100,
            deliveryFee: 30,
            platformFee: 0,
            grandTotal: 130,
            status: OrderStatus.readyForPickup,
            deliveryOtp: '1111',
            createdAt: DateTime.now(),
          ),
        ],
      ));

      deliveryBloc.add(const AcceptDeliveryJobEvent(orderId: 'job_taken_99'));
      await pumpEventQueue();

      expect(deliveryBloc.state.availableJobs.any((j) => j.id == 'job_taken_99'), isFalse);
      expect(deliveryBloc.state.errorMessage, contains("Offer expired"));
    });
  });

  group('5. Order Delivery Lifecycle & Status Propagation', () {
    setUp(() {
      final activeOrder = OrderEntity(
        id: 'job_lifecycle_101',
        orderNumber: 'ORD-101',
        customerId: 'cust_01',
        customerName: 'Aarav Patel',
        customerPhone: '+919876543210',
        deliveryAddress: 'Flat 402, Sunshine Towers, Bengaluru',
        storeId: 'store_01',
        storeName: 'Quick Supermarket',
        storeAddress: '12th Main Road, Bengaluru',
        items: const [],
        subtotal: 400.0,
        deliveryFee: 50.0,
        platformFee: 0.0,
        grandTotal: 450.0,
        status: OrderStatus.assigned,
        deliveryOtp: '458921',
        createdAt: DateTime.now(),
      );

      deliveryBloc.emit(deliveryBloc.state.copyWith(
        riderKYC: deliveryBloc.state.riderKYC.copyWith(kycStatus: KYCStatus.verified),
        activeTrips: [activeOrder],
        activeJobStep: DeliveryTripStep.enRouteStore,
      ));
    });

    test('ArrivedAtStore updates step to atStore', () async {
      deliveryBloc.add(const ArrivedAtStoreEvent('job_lifecycle_101'));
      await pumpEventQueue();

      expect(mockDeliveryRepo.lastUpdatedStatus, equals('REACHED_STORE'));
      expect(deliveryBloc.state.activeJobStep, equals(DeliveryTripStep.atStore));
    });

    test('MarkPickedUp transitions status to pickedUp', () async {
      deliveryBloc.add(const MarkPickedUpEvent('job_lifecycle_101'));
      await pumpEventQueue();

      expect(mockDeliveryRepo.lastUpdatedStatus, equals('PICKED_UP'));
      expect(mockOrderRepo.lastUpdatedStatus, equals(OrderStatus.pickedUp));
      expect(deliveryBloc.state.activeJobStep, equals(DeliveryTripStep.orderPickedUp));
    });

    test('MarkOutForDelivery transitions status to outForDelivery', () async {
      deliveryBloc.add(const MarkOutForDeliveryEvent('job_lifecycle_101'));
      await pumpEventQueue();

      expect(mockDeliveryRepo.lastUpdatedStatus, equals('OUT_FOR_DELIVERY'));
      expect(mockOrderRepo.lastUpdatedStatus, equals(OrderStatus.outForDelivery));
      expect(deliveryBloc.state.activeJobStep, equals(DeliveryTripStep.enRouteCustomer));
    });

    test('ArrivedAtCustomer notifies backend rider is at door', () async {
      deliveryBloc.add(const ArrivedAtCustomerEvent('job_lifecycle_101'));
      await pumpEventQueue();

      expect(mockDeliveryRepo.lastUpdatedStatus, equals('ARRIVED_CUSTOMER'));
      expect(deliveryBloc.state.activeJobStep, equals(DeliveryTripStep.atCustomer));
    });

    test('VerifyDeliveryOtp with wrong OTP length is rejected with error message', () async {
      deliveryBloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'job_lifecycle_101',
        otp: '123',
      ));
      await pumpEventQueue();

      expect(deliveryBloc.state.errorMessage, contains('Delivery OTP must be 6 digits'));
      expect(deliveryBloc.state.activeTrips.length, equals(1));
    });

    test('VerifyDeliveryOtp with wrong OTP is rejected with error message', () async {
      deliveryBloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'job_lifecycle_101',
        otp: '000000',
      ));
      await pumpEventQueue();

      expect(deliveryBloc.state.errorMessage, contains('Incorrect Delivery OTP'));
      expect(deliveryBloc.state.activeTrips.length, equals(1));
    });

    test('VerifyDeliveryOtp with correct OTP completes delivery & settles COD', () async {
      deliveryBloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'job_lifecycle_101',
        otp: '458921',
        collectedAmount: 450.0,
        paymentCollected: true,
      ));
      await pumpEventQueue();

      expect(mockDeliveryRepo.lastUpdatedStatus, equals('DELIVERED'));
      expect(mockDeliveryRepo.lastOtp, equals('458921'));
      expect(mockOrderRepo.lastVerifiedOrderId, equals('job_lifecycle_101'));
      expect(deliveryBloc.state.activeTrips.isEmpty, isTrue);
      expect(deliveryBloc.state.completedTrips.length, equals(1));
    });
  });

  group('6. Earnings, Cash Collection & Notifications Data Flow', () {
    test('FetchDeliveryEarningsEvent updates apiEarnings in state', () async {
      deliveryBloc.add(const FetchDeliveryEarningsEvent());
      await pumpEventQueue();

      expect(deliveryBloc.state.apiEarnings?.today.deliveries, equals(6));
      expect(deliveryBloc.state.apiEarnings?.today.amount, equals(450.0));
    });

    test('FetchEarningsBreakdownEvent loads detailed transaction rows', () async {
      deliveryBloc.add(const FetchEarningsBreakdownEvent(limit: 50));
      await pumpEventQueue();

      expect(deliveryBloc.state.earningsBreakdown.length, equals(1));
      expect(deliveryBloc.state.earningsBreakdown.first.total, equals(70.0));
      expect(deliveryBloc.state.earningsBreakdown.first.status, equals('SETTLED'));
    });

    test('FetchCashCollectedEvent calculates pending deposits and limits', () async {
      deliveryBloc.add(const FetchCashCollectedEvent());
      await pumpEventQueue();

      expect(deliveryBloc.state.cashCollectedSummary?.totalCashCollected, equals(750.0));
      expect(deliveryBloc.state.cashCollectedSummary?.netOwedToCompany, equals(300.0));
    });

    test('LoadDeliveryNotificationsEvent populates unread count and list', () async {
      deliveryBloc.add(const LoadDeliveryNotificationsEvent());
      await pumpEventQueue();

      expect(deliveryBloc.state.notifications.length, equals(1));
      expect(deliveryBloc.state.unreadNotificationsCount, equals(1));
    });

    test('MarkDeliveryNotificationReadEvent decrements unread counter', () async {
      deliveryBloc.emit(deliveryBloc.state.copyWith(
        notifications: [
          DeliveryNotificationEntity(
            id: 'notif_1',
            title: 'Order Assigned',
            body: 'Body',
            type: 'TYPE',
            createdAt: DateTime.now(),
            isRead: false,
          ),
        ],
        unreadNotificationsCount: 1,
      ));

      deliveryBloc.add(const MarkDeliveryNotificationReadEvent('notif_1'));
      await pumpEventQueue();

      expect(deliveryBloc.state.unreadNotificationsCount, equals(0));
      expect(deliveryBloc.state.notifications.first.isRead, isTrue);
    });
  });
}
