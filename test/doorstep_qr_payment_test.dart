import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/delivery/data/models/doorstep_qr_model.dart';
import 'package:quicklink/features/delivery/domain/entities/doorstep_qr_entity.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_models.dart';
import 'package:quicklink/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_event.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_state.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';

class MockOrderRepoForQr implements IOrderRepository {
  final _ctrl = StreamController<List<OrderEntity>>.broadcast();
  @override
  Stream<List<OrderEntity>> get ordersStream => _ctrl.stream;
  void dispose() => _ctrl.close();

  String? lastVerifiedOrderId;
  String? lastEnteredOtp;

  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({
    required String orderId,
    required String enteredOtp,
  }) async {
    lastVerifiedOrderId = orderId;
    lastEnteredOtp = enteredOtp;
    return Right(OrderEntity(
      id: orderId,
      orderNumber: 'ORD-TEST',
      customerId: 'cust_01',
      customerName: 'Test Customer',
      customerPhone: '+919999999999',
      deliveryAddress: 'Test Address',
      storeId: 'store_01',
      storeName: 'Test Store',
      storeAddress: 'Test Store Address',
      items: const [],
      subtotal: 350.0,
      deliveryFee: 40.0,
      platformFee: 0.0,
      grandTotal: 390.0,
      status: OrderStatus.delivered,
      deliveryOtp: enteredOtp,
      createdAt: DateTime.now(),
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDeliveryRepoForQr implements IDeliveryRepository {
  int requestQrCalls = 0;
  int pollStatusCalls = 0;
  String currentStatus = 'PENDING';
  String? lastUpdatedStatus;
  String? lastOtp;

  @override
  Future<Either<Failure, DoorstepQrEntity>> requestDoorstepQr(
    String orderId, {
    int? validitySeconds,
  }) async {
    requestQrCalls++;
    return Right(DoorstepQrEntity(
      orderId: orderId,
      orderNumber: 'ORD-999',
      amount: 390.0,
      qrId: 'qr_test_abc123',
      imageUrl: 'https://api.quicktick.shop/uploads/qr_test.png',
      upiIntent: 'upi://pay?pa=quicktick@razorpay&am=390.0',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      paymentStatus: 'PENDING',
      reused: false,
    ));
  }

  @override
  Future<Either<Failure, QrPaymentStatusEntity>> getQrPaymentStatus(
    String orderId,
  ) async {
    pollStatusCalls++;
    return Right(QrPaymentStatusEntity(
      orderId: orderId,
      orderNumber: 'ORD-999',
      paymentStatus: currentStatus,
      qrExists: true,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      secondsLeft: 290,
      razorpayPaymentId: currentStatus == 'COMPLETED' ? 'pay_RZP_123456' : null,
      paidAt: currentStatus == 'COMPLETED' ? DateTime.now() : null,
    ));
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateJobStatus({
    required String jobId,
    required String status,
    String? deliveryOtp,
  }) async {
    lastUpdatedStatus = status;
    lastOtp = deliveryOtp;
    return Right({'success': true, 'status': status});
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> reportCodDelivered({
    required String assignmentId,
    required String otpCode,
    double? collectedAmount,
    bool paymentCollected = true,
  }) async {
    lastUpdatedStatus = 'DELIVERED';
    lastOtp = otpCode;
    return Right({'success': true, 'status': 'DELIVERED'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Doorstep QR Clean Architecture Models & Entities', () {
    test('DoorstepQrModel parses backend live response payload accurately', () {
      final json = {
        'orderId': '68f1234abcd',
        'orderNumber': 'QC-261017-0099',
        'amount': 450.50,
        'qrId': 'qr_live_9988',
        'imageUrl': 'https://api.quicktick.shop/uploads/qr_sample.png',
        'upiIntent': 'upi://pay?pa=quicktick@icici&am=450.50',
        'expiresAt': '2026-10-17T15:30:00.000Z',
        'paymentStatus': 'PENDING',
        'reused': true,
      };

      final model = DoorstepQrModel.fromJson(json);
      expect(model.orderId, equals('68f1234abcd'));
      expect(model.orderNumber, equals('QC-261017-0099'));
      expect(model.amount, equals(450.50));
      expect(model.qrId, equals('qr_live_9988'));
      expect(model.imageUrl, equals('https://api.quicktick.shop/uploads/qr_sample.png'));
      expect(model.isPending, isTrue);
      expect(model.isCompleted, isFalse);
      expect(model.reused, isTrue);
    });

    test('QrPaymentStatusModel parses completed status and payment ID', () {
      final json = {
        'orderId': '68f1234abcd',
        'orderNumber': 'QC-261017-0099',
        'paymentStatus': 'COMPLETED',
        'qrExists': true,
        'expiresAt': '2026-10-17T15:30:00.000Z',
        'secondsLeft': 120,
        'razorpayPaymentId': 'pay_live_776655',
        'paidAt': '2026-10-17T15:28:10.000Z',
      };

      final model = QrPaymentStatusModel.fromJson(json);
      expect(model.isCompleted, isTrue);
      expect(model.isPending, isFalse);
      expect(model.razorpayPaymentId, equals('pay_live_776655'));
      expect(model.secondsLeft, equals(120));
    });
  });

  group('DeliveryBloc: Doorstep UPI QR & 6-Digit OTP Flow', () {
    late MockOrderRepoForQr orderRepo;
    late MockDeliveryRepoForQr deliveryRepo;
    late DeliveryBloc deliveryBloc;

    setUp(() {
      orderRepo = MockOrderRepoForQr();
      deliveryRepo = MockDeliveryRepoForQr();
      deliveryBloc = DeliveryBloc(
        orderRepo: orderRepo,
        deliveryRepo: deliveryRepo,
      );

      final activeTrip = OrderEntity(
        id: 'order_doorstep_01',
        orderNumber: 'ORD-999',
        customerId: 'cust_01',
        customerName: 'Priya Sharma',
        customerPhone: '+919876543210',
        deliveryAddress: 'Door 10, Indiranagar, Bengaluru',
        storeId: 'store_01',
        storeName: 'Quick Supermarket',
        storeAddress: 'Indiranagar 100ft Road',
        items: const [],
        subtotal: 350.0,
        deliveryFee: 40.0,
        platformFee: 0.0,
        grandTotal: 390.0,
        status: OrderStatus.outForDelivery,
        deliveryOtp: '654321', // 6-digit OTP
        createdAt: DateTime.now(),
      );

      deliveryBloc.emit(deliveryBloc.state.copyWith(
        activeTrips: [activeTrip],
        activeJobStep: DeliveryTripStep.atCustomer,
      ));
    });

    tearDown(() {
      deliveryBloc.close();
    });

    test('RequestDoorstepQrEvent requests QR, populates state, and starts polling', () async {
      deliveryBloc.add(const RequestDoorstepQrEvent(orderId: 'order_doorstep_01'));
      await pumpEventQueue();

      expect(deliveryRepo.requestQrCalls, equals(1));
      expect(deliveryBloc.state.activeDoorstepQr, isNotNull);
      expect(deliveryBloc.state.activeDoorstepQr?.orderId, equals('order_doorstep_01'));
      expect(deliveryBloc.state.activeDoorstepQr?.amount, equals(390.0));
      expect(deliveryBloc.state.isRequestingQr, isFalse);
      expect(deliveryBloc.state.isPollingQr, isTrue);
    });

    test('PollQrPaymentStatusEvent updates status to COMPLETED and halts polling', () async {
      deliveryRepo.currentStatus = 'COMPLETED';
      deliveryBloc.add(const PollQrPaymentStatusEvent('order_doorstep_01'));
      await pumpEventQueue();

      expect(deliveryBloc.state.qrPaymentStatus?.isCompleted, isTrue);
      expect(deliveryBloc.state.qrPaymentStatus?.razorpayPaymentId, equals('pay_RZP_123456'));
      expect(deliveryBloc.state.isPollingQr, isFalse);
    });

    test('StopQrPollingEvent explicitly stops polling timer', () async {
      deliveryBloc.add(const StopQrPollingEvent());
      await pumpEventQueue();

      expect(deliveryBloc.state.isPollingQr, isFalse);
    });

    test('Strict 6-digit OTP: Reject OTP with length != 6', () async {
      deliveryBloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'order_doorstep_01',
        otp: '1234', // 4 digits
      ));
      await pumpEventQueue();

      expect(deliveryBloc.state.errorMessage, equals('Delivery OTP must be 6 digits.'));
      expect(deliveryBloc.state.activeTrips.length, equals(1));
    });

    test('Strict 6-digit OTP: Reject wrong 6-digit OTP', () async {
      deliveryBloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'order_doorstep_01',
        otp: '999999', // 6 digits, but wrong
      ));
      await pumpEventQueue();

      expect(deliveryBloc.state.errorMessage, contains('Incorrect Delivery OTP'));
      expect(deliveryBloc.state.activeTrips.length, equals(1));
    });

    test('Strict 6-digit OTP: Successful delivery completion with valid 6-digit OTP', () async {
      deliveryBloc.add(const VerifyDeliveryOtpEvent(
        orderId: 'order_doorstep_01',
        otp: '654321', // exact 6-digit OTP
        collectedAmount: 390.0,
        paymentCollected: true,
      ));
      await pumpEventQueue();

      expect(deliveryRepo.lastUpdatedStatus, equals('DELIVERED'));
      expect(deliveryRepo.lastOtp, equals('654321'));
      expect(orderRepo.lastVerifiedOrderId, equals('order_doorstep_01'));
      expect(orderRepo.lastEnteredOtp, equals('654321'));
      expect(deliveryBloc.state.activeTrips.isEmpty, isTrue);
      expect(deliveryBloc.state.completedTrips.length, equals(1));
    });
  });
}
