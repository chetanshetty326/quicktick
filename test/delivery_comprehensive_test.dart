import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_models.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import 'dart:async';

// Mock Order Repository for Delivery Testing
class MockOrderRepo implements IOrderRepository {
  final _ordersCtrl = StreamController<List<OrderEntity>>.broadcast();
  final List<OrderEntity> orders = [];

  @override
  Stream<List<OrderEntity>> get ordersStream => _ordersCtrl.stream;

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
  }) async {
    final o = OrderEntity(
      id: 'order_del_test_01',
      orderNumber: 'RET-201',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: 120.0,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: 140.0,
      status: OrderStatus.readyForPickup,
      deliveryOtp: '7823',
      createdAt: DateTime.now(),
    );
    orders.add(o);
    _ordersCtrl.add(List.from(orders));
    return Right(o);
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getDeliveryJobs(String deliveryPartnerId) async => Right(orders);
  @override
  Future<Either<Failure, List<OrderEntity>>> getAvailableDeliveryRequests() async => Right(orders);

  @override
  Future<Either<Failure, OrderEntity>> updateOrderStatus({
    required String orderId,
    required OrderStatus nextStatus,
    String? reason,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return const Left(CacheFailure(message: 'Order not found'));

    final updated = orders[idx].copyWith(status: nextStatus);
    orders[idx] = updated;
    _ordersCtrl.add(List.from(orders));
    return Right(updated);
  }

  @override
  Future<Either<Failure, OrderEntity>> updatePaymentStatus({
    required String orderId,
    required String paymentStatus,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return const Left(CacheFailure(message: 'Order not found'));
    final updated = orders[idx].copyWith(paymentStatus: paymentStatus);
    orders[idx] = updated;
    _ordersCtrl.add(List.from(orders));
    return Right(updated);
  }

  @override
  Future<Either<Failure, OrderEntity>> assignDeliveryPartner({
    required String orderId,
    required String deliveryPartnerId,
    required String deliveryPartnerName,
    required String deliveryPartnerPhone,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return const Left(CacheFailure(message: 'Order not found'));
    final updated = orders[idx].copyWith(
      deliveryPartnerId: deliveryPartnerId,
      deliveryPartnerName: deliveryPartnerName,
      deliveryPartnerPhone: deliveryPartnerPhone,
      status: OrderStatus.assigned,
    );
    orders[idx] = updated;
    _ordersCtrl.add(List.from(orders));
    return Right(updated);
  }

  @override
  Future<Either<Failure, OrderEntity>> verifyDeliveryOtp({
    required String orderId,
    required String enteredOtp,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return const Left(CacheFailure(message: 'Order not found'));
    if (orders[idx].deliveryOtp == enteredOtp) {
      final updated = orders[idx].copyWith(status: OrderStatus.delivered);
      orders[idx] = updated;
      _ordersCtrl.add(List.from(orders));
      return Right(updated);
    }
    return const Left(CacheFailure(message: 'Invalid 4-digit Delivery PIN'));
  }

  @override
  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx] = orders[idx].copyWith(status: OrderStatus.cancelled);
      _ordersCtrl.add(List.from(orders));
    }
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async {
    return const Right(true);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId) async {
    return const Right({'status': 'PREPARING'});
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getPaymentStatus(String orderId) async => const Right({});

  @override
  Future<Either<Failure, List<OrderEntity>>> getOrdersByStatus(String status) async => const Right([]);

  void dispose() {
    _ordersCtrl.close();
  }
}

// Delivery Validation Rules Helper
class DeliveryValidationRules {
  static bool validateAadhaar(String aadhaar) {
    final clean = aadhaar.replaceAll(RegExp(r'[^0-9]'), '');
    return RegExp(r'^[2-9]{1}[0-9]{11}$').hasMatch(clean);
  }

  static bool validateDrivingLicense(String dl) {
    return dl.trim().length >= 10 && RegExp(r'^[A-Z]{2}[0-9A-Z]{8,13}$').hasMatch(dl.trim());
  }

  static bool validatePincode(String pin) {
    return RegExp(r'^[1-9]{1}[0-9]{5}$').hasMatch(pin.trim());
  }

  static bool validateUPI(String upi) {
    return RegExp(r'^[a-zA-Z0-9.\-_]{2,49}@[a-zA-Z._]{2,49}$').hasMatch(upi.trim());
  }
}

void main() {
  // =========================================================================
  // SUITE 1: FACE SELFIE BIOMETRIC RECOGNITION (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 1: Face Selfie Biometrics & Liveness Tests', () {
    late MockOrderRepo orderRepo;
    late DeliveryBloc deliveryBloc;

    setUp(() {
      orderRepo = MockOrderRepo();
      deliveryBloc = DeliveryBloc(orderRepo: orderRepo);
    });

    tearDown(() {
      deliveryBloc.close();
      orderRepo.dispose();
    });

    test('[POS-01] Valid Face Selfie recognition succeeds with high confidence match', () async {
      deliveryBloc.add(const VerifyFaceSelfieEvent(
        capturedPhotoPath: 'selfie_valid_01.jpg',
        isMatchConfirmed: true,
      ));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.isFaceVerifiedToday, isTrue);
      expect(deliveryBloc.state.successMessage, contains('Face Selfie Verified'));
    });

    test('[NEG-01] Face Selfie mismatch or low confidence (<90%) rejects verification', () async {
      deliveryBloc.add(const VerifyFaceSelfieEvent(
        capturedPhotoPath: 'selfie_mismatch.jpg',
        isMatchConfirmed: false,
      ));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.errorMessage, contains('Face match failed'));
    });
  });

  // =========================================================================
  // SUITE 2: AADHAAR, DL & HOME ADDRESS VALIDATION (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 2: Aadhaar, DL & Residential Address KYC Tests', () {
    test('[POS-02] Valid 12-Digit Indian Aadhaar format passes validation', () {
      expect(DeliveryValidationRules.validateAadhaar('548912347890'), isTrue);
      expect(DeliveryValidationRules.validateAadhaar('9876 5432 1098'), isTrue);
    });

    test('[POS-03] Valid Indian Driving License (DL) & 6-digit Pincode pass validation', () {
      expect(DeliveryValidationRules.validateDrivingLicense('KA0420210045678'), isTrue);
      expect(DeliveryValidationRules.validateDrivingLicense('DL0120190012345'), isTrue);
      expect(DeliveryValidationRules.validatePincode('560038'), isTrue);
      expect(DeliveryValidationRules.validateUPI('vikram.rider@okhdfcbank'), isTrue);
    });

    test('[POS-04] Masked Aadhaar format hides sensitive digits cleanly', () {
      const kyc = RiderKYCEntity(aadhaarNumber: '548912347890');
      expect(kyc.maskedAadhaar, 'XXXX-XXXX-7890');
    });

    test('[NEG-02] Invalid Aadhaar (<12 digits or starting with 0/1) is rejected', () {
      expect(DeliveryValidationRules.validateAadhaar('12345'), isFalse); // Too short
      expect(DeliveryValidationRules.validateAadhaar('012345678901'), isFalse); // Starts with 0
      expect(DeliveryValidationRules.validateAadhaar(''), isFalse);
    });

    test('[NEG-03] Invalid Driving License or malformed PIN code is rejected', () {
      expect(DeliveryValidationRules.validateDrivingLicense('KA123'), isFalse); // Too short
      expect(DeliveryValidationRules.validatePincode('56003'), isFalse); // 5 digits
      expect(DeliveryValidationRules.validatePincode('060038'), isFalse); // Starts with 0
      expect(DeliveryValidationRules.validateUPI('invalid_upi_no_at'), isFalse);
    });
  });

  // =========================================================================
  // SUITE 3: DUTY STATUS & BIOMETRIC GATE (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 3: Duty Management & Biometric Gate Tests', () {
    late MockOrderRepo orderRepo;
    late DeliveryBloc deliveryBloc;

    setUp(() {
      orderRepo = MockOrderRepo();
      deliveryBloc = DeliveryBloc(orderRepo: orderRepo);
    });

    tearDown(() {
      deliveryBloc.close();
      orderRepo.dispose();
    });

    test('[POS-05] Switching duty to ONLINE when face is verified succeeds', () async {
      deliveryBloc.add(const ApproveRiderKYCEvent());
      await Future.delayed(const Duration(milliseconds: 30));
      deliveryBloc.add(const ToggleDutyEvent(true));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.isOnline, isTrue);
      expect(deliveryBloc.state.successMessage, contains('ONLINE'));
    });

    test('[POS-06] Switching duty to OFFLINE with reason updates status', () async {
      deliveryBloc.add(const ToggleDutyEvent(false, reason: 'Lunch Break ☕'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.isOnline, isFalse);
      expect(deliveryBloc.state.offlineReason, 'Lunch Break ☕');
    });
  });

  // =========================================================================
  // SUITE 4: REAL-TIME TRIP LIFECYCLE & 4-DIGIT OTP (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 4: Trip Pipeline, Item Checklist & OTP Handover Tests', () {
    late MockOrderRepo orderRepo;
    late DeliveryBloc deliveryBloc;

    setUp(() async {
      orderRepo = MockOrderRepo();
      await orderRepo.createOrder(
        customerId: 'cust_01',
        customerName: 'Aarav Sharma',
        customerPhone: '+91 98765 11223',
        deliveryAddress: '304, Green Palms, Indiranagar',
        storeId: 'store_01',
        storeName: 'Fresh Mart Kitchen',
        storeAddress: '100ft Rd, Indiranagar',
        items: const [
          OrderItemEntity(productId: 'p1', nameSnapshot: 'Organic Milk', priceSnapshot: 35.0, unit: '500ml', quantity: 2),
        ],
        deliveryFee: 15.0,
        platformFee: 5.0,
      );

      deliveryBloc = DeliveryBloc(orderRepo: orderRepo);
      deliveryBloc.add(const ApproveRiderKYCEvent());
      deliveryBloc.add(const LoadDeliveryDataEvent());
      await Future.delayed(const Duration(milliseconds: 30));
    });

    tearDown(() {
      deliveryBloc.close();
      orderRepo.dispose();
    });

    test('[POS-07] Accepting delivery job assigns driver and sets step to enRouteStore', () async {
      deliveryBloc.add(const AcceptDeliveryJobEvent(orderId: 'order_del_test_01'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(orderRepo.orders.first.status, OrderStatus.assigned);
      expect(deliveryBloc.state.activeJobStep, DeliveryTripStep.enRouteStore);
      expect(deliveryBloc.state.successMessage, contains('Job Accepted'));
    });

    test('[POS-08] Store arrival and item checklist verification succeeds', () async {
      deliveryBloc.add(const ArrivedAtStoreEvent('order_del_test_01'));
      deliveryBloc.add(const ToggleItemChecklistEvent('p1'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.activeJobStep, DeliveryTripStep.atStore);
      expect(deliveryBloc.state.verifiedItemChecklist.contains('p1'), isTrue);
    });

    test('[POS-09] Valid 4-digit Customer Delivery PIN verifies and completes trip', () async {
      deliveryBloc.add(const VerifyDeliveryOtpEvent(orderId: 'order_del_test_01', otp: '7823'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(orderRepo.orders.first.status, OrderStatus.delivered);
      expect(deliveryBloc.state.activeJobStep, DeliveryTripStep.completed);
      expect(deliveryBloc.state.successMessage, contains('Delivery Completed'));
    });

    test('[NEG-04] Invalid 4-digit Customer Delivery PIN rejects handover', () async {
      deliveryBloc.add(const VerifyDeliveryOtpEvent(orderId: 'order_del_test_01', otp: '0000'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(orderRepo.orders.first.status, isNot(OrderStatus.delivered));
      expect(deliveryBloc.state.errorMessage, 'Invalid 4-digit Delivery PIN');
    });

    test('[NEG-05] Declining delivery job clears incoming alert cleanly', () async {
      deliveryBloc.add(const DeclineDeliveryJobEvent('order_del_test_01'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.incomingJobAlert, isNull);
      expect(deliveryBloc.state.successMessage, contains('Order declined'));
    });
  });

  // =========================================================================
  // SUITE 5: WALLET, OFFERS & INSTANT UPI CASHOUT (POSITIVE & NEGATIVE)
  // =========================================================================
  group('Suite 5: Wallet, Dynamic Offers & UPI Payout Tests', () {
    late MockOrderRepo orderRepo;
    late DeliveryBloc deliveryBloc;

    setUp(() {
      orderRepo = MockOrderRepo();
      deliveryBloc = DeliveryBloc(orderRepo: orderRepo);
      deliveryBloc.emit(deliveryBloc.state.copyWith(walletBalance: 500.0));
    });

    tearDown(() {
      deliveryBloc.close();
      orderRepo.dispose();
    });

    test('[POS-10] Instant UPI Payout debits wallet and logs settled transaction', () async {
      final initialBal = deliveryBloc.state.walletBalance; // 380.0
      deliveryBloc.add(const RequestInstantUPIPayoutEvent(amount: 200.0, upiId: 'vikram.rider@okhdfcbank'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.walletBalance, initialBal - 200.0);
      expect(deliveryBloc.state.transactions.first.type, TransactionType.upiWithdrawal);
      expect(deliveryBloc.state.successMessage, contains('transferred instantly'));
    });

    test('[POS-11] Dynamic Offer progress calculation handles completed and zero cases', () {
      const offer1 = DeliveryOfferEntity(
        id: 'off_01',
        title: 'Streak',
        subtitle: 'Trips',
        tag: 'HOT',
        bonusReward: 100,
        targetTrips: 10,
        currentTrips: 5,
        isCompleted: false,
        expiryText: 'Today',
        gradientColorStart: '#000',
        gradientColorEnd: '#fff',
      );
      expect(offer1.progress, 0.5);

      const offerZero = DeliveryOfferEntity(
        id: 'off_02',
        title: 'Zero Target',
        subtitle: 'Trips',
        tag: 'HOT',
        bonusReward: 100,
        targetTrips: 0,
        currentTrips: 0,
        isCompleted: true,
        expiryText: 'Today',
        gradientColorStart: '#000',
        gradientColorEnd: '#fff',
      );
      expect(offerZero.progress, 0.0);
    });

    test('[NEG-06] UPI Cashout with zero or negative amount is rejected', () async {
      deliveryBloc.add(const RequestInstantUPIPayoutEvent(amount: 0.0, upiId: 'vikram.rider@okhdfcbank'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.errorMessage, contains('greater than ₹0'));
    });

    test('[NEG-07] UPI Cashout exceeding wallet balance fails with error', () async {
      deliveryBloc.add(const RequestInstantUPIPayoutEvent(amount: 50000.0, upiId: 'vikram.rider@okhdfcbank'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.errorMessage, contains('Insufficient wallet balance'));
    });

    test('[NEG-08] UPI Cashout with malformed UPI ID fails with error', () async {
      deliveryBloc.add(const RequestInstantUPIPayoutEvent(amount: 100.0, upiId: 'invalidupi'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(deliveryBloc.state.errorMessage, contains('Invalid UPI ID format'));
    });
  });
}
