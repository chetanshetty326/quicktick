import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/delivery/data/models/delivery_api_models.dart';
import 'package:quicklink/features/delivery/data/datasources/delivery_remote_data_source.dart';
import 'package:quicklink/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_api_entities.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_models.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/customer/data/models/hero_banner_model.dart';

// Mock Delivery Remote Data Source
class MockDeliveryRemoteDataSource implements IDeliveryRemoteDataSource {
  DeliveryPartnerProfileModel? mockProfile;
  DeliveryEarningsModel? mockEarnings;
  List<DeliveryJobModel> mockJobs = [];
  String currentAvailability = 'OFFLINE';
  String? lastUpdatedStatus;
  String? lastRejectedReason;
  double? lastLat;
  double? lastLng;

  @override
  Future<DeliveryPartnerProfileModel> getProfile() async {
    if (mockProfile != null) return mockProfile!;
    return const DeliveryPartnerProfileModel(
      id: 'del_api_01',
      userId: 'user_del_01',
      phone: '+917777777701',
      vehicleType: 'BIKE',
      vehicleNumber: 'KA-50-C-0003',
      vehicleModel: 'Honda Activa 6G',
      licenseNumber: 'KA0000000050',
      availability: 'ONLINE',
      status: 'APPROVED',
      isVerified: true,
      verificationStatus: 'APPROVED',
      serviceRadius: 5,
      rating: 4.8,
      totalDeliveries: 120,
      successRate: 99.2,
    );
  }

  @override
  Future<List<HeroBannerModel>> getHeroBanners({String app = 'DELIVERY'}) async => [];

  @override
  Future<String> uploadDocument(File file) async {
    return 'https://quickclick-backend-136h.onrender.com/uploads/doc_${file.path.split("/").last}';
  }

  @override
  Future<DeliveryPartnerProfileModel> registerPartner({
    required String vehicleType,
    required String vehicleNumber,
    required String vehicleModel,
    required String licenseNumber,
    String? name,
    String? mobile,
    String? email,
    String houseAddress = '',
    String selfieUrl = '',
    required List<DeliveryDocumentModel> documents,
    double? latitude,
    double? longitude,
    String? zoneId,
  }) async {
    final reg = DeliveryPartnerProfileModel(
      id: 'del_reg_01',
      userId: 'user_01',
      phone: '+917777777701',
      vehicleType: vehicleType,
      vehicleNumber: vehicleNumber,
      vehicleModel: vehicleModel,
      licenseNumber: licenseNumber,
      availability: 'OFFLINE',
      status: 'PENDING',
      isVerified: false,
      verificationStatus: 'PENDING',
      documents: documents,
    );
    mockProfile = reg;
    return reg;
  }

  @override
  Future<DeliveryPartnerProfileModel> updateProfile(Map<String, dynamic> data) async {
    return mockProfile!;
  }

  @override
  Future<String> setAvailability(String availability) async {
    currentAvailability = availability;
    return availability;
  }

  @override
  Future<({double lat, double lng})> updateLocation(double lat, double lng) async {
    lastLat = lat;
    lastLng = lng;
    return (lat: lat, lng: lng);
  }

  @override
  Future<List<DeliveryJobModel>> getJobs({String filter = 'all'}) async {
    return mockJobs;
  }

  @override
  Future<DeliveryJobModel> getJobDetails(String jobId) async {
    return mockJobs.firstWhere((j) => j.id == jobId);
  }

  @override
  Future<Map<String, dynamic>> updateJobStatus({
    required String jobId,
    required String status,
    String? deliveryOtp,
  }) async {
    lastUpdatedStatus = status;
    return {
      'assignment': {'_id': jobId, 'status': status},
      'orderStatus': status,
    };
  }

  @override
  Future<bool> rejectJob({required String jobId, required String reason}) async {
    lastRejectedReason = reason;
    return true;
  }

  @override
  Future<DeliveryEarningsModel> getEarnings() async {
    if (mockEarnings != null) return mockEarnings!;
    return const DeliveryEarningsModel(
      today: PeriodEarningsModel(amount: 320.0, deliveries: 5),
      thisWeek: PeriodEarningsModel(amount: 1850.0, deliveries: 32),
      thisMonth: PeriodEarningsModel(amount: 7200.0, deliveries: 128),
      lifetime: PeriodEarningsModel(amount: 15400.0, deliveries: 385),
    );
  }

  @override
  Future<bool> registerDeviceToken({
    required String deviceToken,
    String platform = 'android',
  }) async => true;

  @override
  Future<List<EarningsBreakdownRowModel>> getEarningsBreakdown({int limit = 50}) async => [];

  @override
  Future<CashCollectedSummaryModel> getCashCollected() async => const CashCollectedSummaryModel(
        totalCashCollected: 0.0,
        totalEarnings: 0.0,
        netOwedToCompany: 0.0,
        netOwedByCompany: 0.0,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Minimal Mock Order Repository
class MockOrderRepoForApiTest implements IOrderRepository {
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
  Future<Either<Failure, OrderEntity>> updateOrderStatus({
    required String orderId,
    required OrderStatus nextStatus,
    String? reason,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = orders[idx].copyWith(status: nextStatus);
      orders[idx] = updated;
      _ctrl.add(List.from(orders));
      return Right(updated);
    }
    return const Left(CacheFailure(message: 'Order not found'));
  }

  @override
  Future<Either<Failure, OrderEntity>> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({
    required String orderId,
    required String deliveryPartnerId,
    required String deliveryPartnerName,
    required String deliveryPartnerPhone,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = orders[idx].copyWith(
        deliveryPartnerId: deliveryPartnerId,
        status: OrderStatus.assigned,
      );
      orders[idx] = updated;
      _ctrl.add(List.from(orders));
      return Right(updated);
    }
    return const Left(CacheFailure(message: 'Order not found'));
  }

  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({
    required String orderId,
    required String enteredOtp,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final updated = orders[idx].copyWith(status: OrderStatus.delivered);
      orders[idx] = updated;
      _ctrl.add(List.from(orders));
      return Right(updated);
    }
    return const Left(CacheFailure(message: 'Order not found'));
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Delivery API Clean Architecture & BLoC Integration Suite', () {
    late MockDeliveryRemoteDataSource remoteDataSource;
    late DeliveryRepositoryImpl deliveryRepo;
    late MockOrderRepoForApiTest orderRepo;
    late DeliveryBloc bloc;

    setUp(() {
      remoteDataSource = MockDeliveryRemoteDataSource();
      deliveryRepo = DeliveryRepositoryImpl(remoteDataSource);
      orderRepo = MockOrderRepoForApiTest();
      bloc = DeliveryBloc(
        orderRepo: orderRepo,
        deliveryRepo: deliveryRepo,
      );
    });

    tearDown(() {
      bloc.close();
      orderRepo.dispose();
    });

    test('Data Layer: JSON Models correctly parse API specification schema', () {
      final profileJson = {
        '_id': '6aaad6647b1095845c1f1f77',
        'userId': '6aaad63c7b1095845c1f1f6e',
        'phone': '+917777777750',
        'vehicleType': 'BIKE',
        'vehicleNumber': 'KA-50-C-0003',
        'vehicleModel': 'Honda Activa 6G',
        'licenseNumber': 'KA0000000050',
        'availability': 'OFFLINE',
        'status': 'PENDING',
        'isVerified': false,
        'verificationStatus': 'PENDING',
        'serviceRadius': 5,
        'rating': 0,
        'totalDeliveries': 0,
        'successRate': 100,
        'documents': [
          {
            'type': 'AADHAAR',
            'url': 'https://quickclick-backend-136h.onrender.com/uploads/a1b2.pdf',
            'number': 'XXXX-5050'
          },
          {
            'type': 'LICENSE',
            'url': 'https://quickclick-backend-136h.onrender.com/uploads/c3d4.pdf',
            'number': 'KA0000000050'
          }
        ]
      };

      final profile = DeliveryPartnerProfileModel.fromJson(profileJson);
      expect(profile.id, equals('6aaad6647b1095845c1f1f77'));
      expect(profile.vehicleType, equals('BIKE'));
      expect(profile.documents.length, equals(2));
      expect(profile.documents.first.type, equals(DeliveryDocumentType.aadhaar));
      expect(profile.isPending, isTrue);

      final earningsJson = {
        'today': {'amount': 320, 'deliveries': 5},
        'thisWeek': {'amount': 1850, 'deliveries': 32},
        'thisMonth': {'amount': 7200, 'deliveries': 128},
        'lifetime': {'amount': 15400, 'deliveries': 385}
      };

      final earnings = DeliveryEarningsModel.fromJson(earningsJson);
      expect(earnings.today.amount, equals(320.0));
      expect(earnings.today.deliveries, equals(5));
      expect(earnings.thisMonth.amount, equals(7200.0));
    });

    test('Repository: registerPartner constructs payload and updates in-memory cache', () async {
      final res = await deliveryRepo.registerPartner(
        vehicleType: 'SCOOTER',
        vehicleNumber: 'KA-01-AB-1234',
        vehicleModel: 'Ather 450X',
        licenseNumber: 'KA0120220009999',
        documents: const [
          DeliveryDocumentEntity(
            type: DeliveryDocumentType.aadhaar,
            url: 'https://backend/uploads/aadhaar.pdf',
            number: '548912347890',
          ),
          DeliveryDocumentEntity(
            type: DeliveryDocumentType.license,
            url: 'https://backend/uploads/license.pdf',
            number: 'KA0120220009999',
          ),
          DeliveryDocumentEntity(
            type: DeliveryDocumentType.rc,
            url: 'https://backend/uploads/rc.pdf',
          ),
        ],
      );

      expect(res.isRight(), isTrue);
      final profile = res.getOrElse(() => throw Exception());
      expect(profile.vehicleType, equals('SCOOTER'));
      expect(profile.isPending, isTrue);

      // Verify cached fallback
      final cachedRes = await deliveryRepo.getProfile();
      expect(cachedRes.isRight(), isTrue);
      expect(cachedRes.getOrElse(() => throw Exception()).id, equals('del_reg_01'));
    });

    test('Repository: Availability, Location Ping, Job status, and Earnings', () async {
      // 1. Availability
      final availRes = await deliveryRepo.setAvailability('ONLINE');
      expect(availRes.isRight(), isTrue);
      expect(remoteDataSource.currentAvailability, equals('ONLINE'));

      // 2. Location
      final locRes = await deliveryRepo.updateLocation(lat: 12.9716, lng: 77.5946);
      expect(locRes.isRight(), isTrue);
      expect(remoteDataSource.lastLat, equals(12.9716));
      expect(remoteDataSource.lastLng, equals(77.5946));

      // 3. Job status update (PATCH /delivery/jobs/:id/status)
      final statusRes = await deliveryRepo.updateJobStatus(
        jobId: 'job_101',
        status: 'REACHED_STORE',
      );
      expect(statusRes.isRight(), isTrue);
      expect(remoteDataSource.lastUpdatedStatus, equals('REACHED_STORE'));

      // 4. Job rejection (POST /delivery/jobs/:id/reject)
      final rejectRes = await deliveryRepo.rejectJob(
        jobId: 'job_101',
        reason: 'Too far',
      );
      expect(rejectRes.isRight(), isTrue);
      expect(remoteDataSource.lastRejectedReason, equals('Too far'));

      // 5. Earnings (GET /delivery/me/earnings)
      final earnRes = await deliveryRepo.getEarnings();
      expect(earnRes.isRight(), isTrue);
      final earnings = earnRes.getOrElse(() => throw Exception());
      expect(earnings.today.amount, equals(320.0));
      expect(earnings.lifetime.amount, equals(15400.0));
    });

    test('BLoC Integration: LoadDeliveryDataEvent populates profile and earnings', () async {
      bloc.add(const LoadDeliveryDataEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.apiProfile, isNotNull);
      expect(bloc.state.apiProfile?.phone, equals('+917777777701'));
      expect(bloc.state.apiEarnings, isNotNull);
      expect(bloc.state.apiEarnings?.today.amount, equals(320.0));
      expect(bloc.state.todayEarnings, equals(320.0));
    });

    test('BLoC Integration: ToggleDutyEvent syncs availability to backend', () async {
      bloc.add(const ApproveRiderKYCEvent());
      await Future.delayed(const Duration(milliseconds: 40));

      bloc.add(const ToggleDutyEvent(true));
      await Future.delayed(const Duration(milliseconds: 40));

      expect(bloc.state.isOnline, isTrue);
      expect(remoteDataSource.currentAvailability, equals('ONLINE'));

      bloc.add(const ToggleDutyEvent(false, reason: 'Shift Ended'));
      await Future.delayed(const Duration(milliseconds: 40));

      expect(bloc.state.isOnline, isFalse);
      expect(remoteDataSource.currentAvailability, equals('OFFLINE'));
    });

    test('BLoC Integration: Location ping event forwards GPS coordinates', () async {
      bloc.add(const UpdateLocationPingEvent(lat: 12.9716, lng: 77.5946));
      await Future.delayed(const Duration(milliseconds: 40));

      expect(remoteDataSource.lastLat, equals(12.9716));
      expect(remoteDataSource.lastLng, equals(77.5946));
    });

    test('Live Backend Payload: ASSIGNED job with nested order & map address parses & displays in availableJobs', () async {
      // 1. Simulate exact backend payload for Order 0014
      final rawBackendJobMap = {
        '_id': 'job_assign_0014',
        'status': 'ASSIGNED',
        'assignmentStatus': 'ASSIGNED',
        'deliveryPartnerId': 'user_gagan_id_123',
        'order': {
          '_id': 'order_0014',
          'orderNumber': '0014',
          'status': 'CONFIRMED',
          'total': 650.0,
          'deliveryFee': 40.0,
          'deliveryAddress': {
            'line1': 'Flat 204, Green Heights',
            'city': 'Bengaluru',
            'pincode': '560038'
          },
          'store': {
            '_id': 'store_01',
            'shopName': 'Daily Supermarket',
            'phone': '+919876543210',
            'address': {'line1': '100 Feet Rd', 'city': 'Indiranagar'}
          },
          'customer': {
            '_id': 'cust_01',
            'name': 'Priya Sharma',
            'mobile': '+919811223344'
          }
        }
      };

      // Ensure model parses nested structure properly
      final mergedMap = Map<String, dynamic>.from(rawBackendJobMap['order'] as Map);
      mergedMap['status'] = 'ASSIGNED';
      mergedMap['deliveryPartnerId'] = rawBackendJobMap['deliveryPartnerId'];
      final parsedJob = DeliveryJobModel.fromJson(mergedMap);

      expect(parsedJob.id, equals('order_0014'));
      expect(parsedJob.orderNumber, equals('0014'));
      expect(parsedJob.status, equals('ASSIGNED'));
      expect(parsedJob.deliveryAddress, contains('Flat 204, Green Heights'));
      expect(parsedJob.storeAddress, contains('100 Feet Rd'));

      // 2. Put into remoteDataSource and trigger FetchDeliveryJobsEvent
      remoteDataSource.mockJobs = [parsedJob];
      bloc.emit(bloc.state.copyWith(
        isOnline: true,
        riderKYC: bloc.state.riderKYC.copyWith(
          kycStatus: KYCStatus.verified,
          riderId: 'rider_profile_id_456', // Different from user_gagan_id_123 to verify ID mismatch fix!
        ),
      ));

      bloc.add(const FetchDeliveryJobsEvent(filter: 'all'));
      await Future.delayed(const Duration(milliseconds: 50));

      // 3. Verify order 0014 appears in availableJobs on Radar and triggers incoming alert
      expect(bloc.state.apiJobs.length, equals(1));
      expect(bloc.state.availableJobs.length, equals(1));
      expect(bloc.state.availableJobs.first.id, equals('order_0014'));
      expect(bloc.state.availableJobs.first.orderNumber, equals('0014'));
      expect(bloc.state.incomingJobAlert, isNotNull);
      expect(bloc.state.incomingJobAlert?.orderNumber, equals('0014'));
    });
  });
}
