import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/delivery/data/models/delivery_api_models.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_models.dart';
import 'package:quicklink/features/delivery/domain/entities/rider_wallet_entities.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:dartz/dartz.dart';

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _map = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _map[key] = value;
    } else {
      _map.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _map[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _map.remove(key);

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _map.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOrderRepo implements IOrderRepository {
  String? lastVerifiedOtp;

  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({
    required String orderId,
    required String enteredOtp,
  }) async {
    lastVerifiedOtp = enteredOtp;
    if (enteredOtp == '884219') {
      return Right(OrderEntity(
        id: orderId,
        orderNumber: orderId,
        customerId: 'cust1',
        customerName: 'Test Customer',
        customerPhone: '9876543210',
        deliveryAddress: 'Test Address',
        storeId: 'store1',
        storeName: 'Test Store',
        storeAddress: 'Store Address',
        items: const [],
        subtotal: 100,
        deliveryFee: 35,
        platformFee: 0,
        grandTotal: 135,
        deliveryOtp: '884219',
        status: OrderStatus.delivered,
        createdAt: DateTime.now(),
      ));
    }
    return const Left(AuthFailure(message: 'Incorrect delivery PIN', statusCode: 400));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDeliveryRepo implements IDeliveryRepository {
  @override
  Future<Either<Failure, Map<String, dynamic>>> updateJobStatus({
    required String jobId,
    required String status,
    String? deliveryOtp,
  }) async {
    if (deliveryOtp == '884219') {
      return const Right({'success': true, 'status': 'DELIVERED'});
    }
    return const Left(ServerFailure(message: 'Invalid OTP code'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Delivery App Security Hardening & Clean Architecture Tests', () {
    late FakeSecureStorage fakeStorage;
    late SharedPreferences prefs;
    late SecureStorageService secureStorageService;
    late MockOrderRepo mockOrderRepo;
    late MockDeliveryRepo mockDeliveryRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeStorage = FakeSecureStorage();
      secureStorageService = SecureStorageService(
        storage: fakeStorage,
        prefs: prefs,
      );
      mockOrderRepo = MockOrderRepo();
      mockDeliveryRepo = MockDeliveryRepo();
    });

    test('DELIVERY-SECURITY-01: Rider KYC data (Aadhaar, DL, Bank) is stored in encrypted SecureStorage, NOT in SharedPreferences', () async {
      const sensitiveKycJson = '{"fullName":"Rajesh Kumar","aadhaarNumber":"123456789012","dlNumber":"KA0120200001234","bankAccount":"987654321098","ifscCode":"HDFC0001234","upiId":"rajesh@okhdfcbank"}';

      await secureStorageService.saveRiderKycData(sensitiveKycJson, phoneSuffix: '9999999999');

      // Verify stored in FlutterSecureStorage
      final secured = await fakeStorage.read(key: 'sec_rider_kyc_data_9999999999');
      expect(secured, equals(sensitiveKycJson));

      // Verify NOT present in unencrypted SharedPreferences
      expect(prefs.getString('delivery_partner_kyc_data'), isNull);
      expect(prefs.getString('delivery_partner_kyc_data_9999999999'), isNull);
    });

    test('DELIVERY-SECURITY-02: Legacy plaintext KYC data in SharedPreferences is automatically migrated to SecureStorage and deleted from disk', () async {
      const legacyKycJson = '{"fullName":"Old Rider","aadhaarNumber":"999988887777","dlNumber":"MH0220190005678"}';
      await prefs.setString('delivery_partner_kyc_data_8888888888', legacyKycJson);

      // getRiderKycData should read, migrate to SecureStorage, and purge from SharedPreferences
      final retrieved = await secureStorageService.getRiderKycData(phoneSuffix: '8888888888');
      expect(retrieved, equals(legacyKycJson));

      // Verify secured
      expect(await fakeStorage.read(key: 'sec_rider_kyc_data_8888888888'), equals(legacyKycJson));

      // Verify unencrypted SharedPreferences is purged
      expect(prefs.getString('delivery_partner_kyc_data_8888888888'), isNull);
      expect(prefs.getString('delivery_partner_kyc_data'), isNull);
    });

    test('DELIVERY-SECURITY-03: DeliveryJobModel.fromJson sanitizes deliveryOtp so rider client never receives customer OTP', () {
      final serverPayload = {
        '_id': 'job_101',
        'status': 'ASSIGNED',
        'orderNumber': 'ORD-9901',
        'deliveryFee': 60.0,
        'grandTotal': 350.0,
        'paymentMethod': 'COD',
        'deliveryOtp': '884219', // Sensitive Customer OTP from server
        'otp': '884219',
        'customer': {
          'name': 'Pooja Reddy',
          'phone': '+919876543210',
          'address': 'Koramangala 4th Block',
        },
        'retailer': {
          'storeName': 'Fresh Supermarket',
          'storeAddress': '100ft Road Indiranagar',
        },
      };

      final jobModel = DeliveryJobModel.fromJson(serverPayload);

      // Verification: deliveryOtp on the rider app entity must be empty
      expect(jobModel.deliveryOtp, equals(''));
    });

    test('DELIVERY-SECURITY-04: DeliveryBloc rejects invalid OTPs, enforces 6-digit numeric regex, and blocks 1234 test bypass', () async {
      final bloc = DeliveryBloc(
        orderRepo: mockOrderRepo,
        deliveryRepo: mockDeliveryRepo,
        secureStorage: secureStorageService,
      );

      // Test 1: Non-numeric OTP
      bloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'job_101',
        otp: 'ABCDEF',
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.errorMessage, contains('Delivery OTP must be a 6-digit number'));

      // Test 2: Short 4-digit OTP or '1234' bypass attempt
      bloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'job_101',
        otp: '1234',
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.errorMessage, contains('Delivery OTP must be a 6-digit number'));

      // Test 3: Valid 6-digit numeric OTP passes validation to repository
      bloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'job_101',
        otp: '884219',
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockOrderRepo.lastVerifiedOtp, equals('884219'));

      await bloc.close();
    });

    test('DELIVERY-SECURITY-05: DeliveryBloc prevents over-draft and under-minimum wallet withdrawals', () async {
      final bloc = DeliveryBloc(
        orderRepo: mockOrderRepo,
        deliveryRepo: mockDeliveryRepo,
        secureStorage: secureStorageService,
      );

      // Set wallet balance to ₹500
      bloc.emit(bloc.state.copyWith(walletBalance: 500.0));

      // Attempt 1: Withdrawal below minimum ₹100
      bloc.add(const RequestWalletWithdrawalEvent(
        amount: 50.0,
        bankAccountId: 'acc_01',
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.errorMessage, contains('Minimum withdrawal amount is ₹100'));

      // Attempt 2: Over-draft withdrawal exceeding ₹500 balance (e.g. ₹1000)
      bloc.add(const RequestWalletWithdrawalEvent(
        amount: 1000.0,
        bankAccountId: 'acc_01',
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.errorMessage, contains('Insufficient wallet balance'));

      // Attempt 3: Withdrawal without verified bank account
      bloc.add(const RequestWalletWithdrawalEvent(
        amount: 200.0,
        bankAccountId: '',
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.errorMessage, contains('Please select a verified bank'));

      await bloc.close();
    });
  });
}
