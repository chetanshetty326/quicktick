import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_models.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_bloc.dart';
import 'package:quicklink/features/delivery/presentation/bloc/delivery_event.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:dartz/dartz.dart';
import 'dart:async';

// Mock Order Repository for Delivery SRS Compliance Testing
class MockSRSOrderRepo implements IOrderRepository {
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
  }) async {
    final o = OrderEntity(
      id: 'ord_srs_${orders.length + 1}',
      orderNumber: 'SRS-${orders.length + 101}',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: 250.0,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: 290.0,
      status: OrderStatus.readyForPickup,
      deliveryOtp: '1234',
      paymentMethod: paymentMethod,
      paymentStatus: 'PENDING',
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
      final updated = orders[idx].copyWith(
        status: OrderStatus.delivered,
        paymentStatus: 'COMPLETED',
      );
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
  Future<Either<Failure, bool>> reviewOrder(String orderId, int storeRating, int deliveryRating, String comment) async => const Right(true);

  @override
  Future<Either<Failure, Map<String, dynamic>>> trackOrder(String orderId) async => const Right({'status': 'PREPARING'});

  @override
  Future<Either<Failure, Map<String, dynamic>>> getPaymentStatus(String orderId) async => const Right({});

  @override
  Future<Either<Failure, List<OrderEntity>>> getOrdersByStatus(String status) async => const Right([]);

  void dispose() {
    _ordersCtrl.close();
  }
}

void main() {
  group('Delivery App SRS Compliance (FR-DEL-001 through FR-DEL-013)', () {
    late MockSRSOrderRepo orderRepo;
    late DeliveryBloc bloc;

    setUp(() {
      orderRepo = MockSRSOrderRepo();
      bloc = DeliveryBloc(orderRepo: orderRepo);
    });

    tearDown(() {
      bloc.close();
      orderRepo.dispose();
    });

    test('FR-DEL-001 & FR-DEL-002: Registration submits KYC as underReview, blocks duty until admin approval', () async {
      // Register KYC
      bloc.add(const SubmitRiderKYCEvent(
        RiderKYCEntity(
          fullName: 'Rahul Sharma',
          phone: '9876543210',
          aadhaarNumber: '234567890123',
          dlNumber: 'KA0120220001234',
          vehicleType: 'Electric Bike',
          vehicleNumber: 'KA01EQ1234',
          pincode: '560001',
          kycStatus: KYCStatus.underReview,
        ),
      ));
      await Future.delayed(const Duration(milliseconds: 40));

      expect(bloc.state.riderKYC.kycStatus, equals(KYCStatus.underReview));

      // Attempt to toggle duty ON while under review - should be blocked
      bloc.add(const ToggleDutyEvent(true));
      await Future.delayed(const Duration(milliseconds: 40));

      expect(bloc.state.isOnline, isFalse);
      expect(bloc.state.errorMessage, contains('Admin approval required'));

      // Admin approves the rider KYC
      bloc.add(const ApproveRiderKYCEvent());
      await Future.delayed(const Duration(milliseconds: 40));

      expect(bloc.state.riderKYC.kycStatus, equals(KYCStatus.verified));
      expect(bloc.state.successMessage, contains('Partner Account Approved'));
    });

    test('FR-DEL-003: Approved delivery partner can toggle Online and Offline duty status', () async {
      // Ensure partner is approved
      bloc.add(const ApproveRiderKYCEvent());
      await Future.delayed(const Duration(milliseconds: 40));

      // Toggle Online
      bloc.add(const ToggleDutyEvent(true));
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.isOnline, isTrue);

      // Toggle Offline
      bloc.add(const ToggleDutyEvent(false));
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.isOnline, isFalse);
    });

    test('FR-DEL-004 & FR-DEL-005: Delivery job stream notification, accept assignment, decline with reason, single active job rule', () async {
      // Approve and go online
      bloc.add(const ApproveRiderKYCEvent());
      bloc.add(const ToggleDutyEvent(true));
      await Future.delayed(const Duration(milliseconds: 40));

      // Create two ready orders in repo
      final res1 = await orderRepo.createOrder(
        customerId: 'c_101',
        customerName: 'Ananya Roy',
        customerPhone: '9988776655',
        deliveryAddress: 'Flat 402, Green Glen, Bellandur, Bangalore',
        storeId: 'store_1',
        storeName: 'QuickMart Fresh',
        storeAddress: '12 Main Rd, Bellandur',
        items: const [
          OrderItemEntity(
            productId: 'p_1',
            nameSnapshot: 'Fresh Milk 500ml',
            priceSnapshot: 35.0,
            unit: 'packet',
            quantity: 2,
          ),
        ],
        deliveryFee: 30.0,
        platformFee: 5.0,
      );
      final order1 = res1.getOrElse(() => throw Exception());

      final res2 = await orderRepo.createOrder(
        customerId: 'c_102',
        customerName: 'Vijay Kumar',
        customerPhone: '9123456780',
        deliveryAddress: '34 5th Cross, HSR Layout, Bangalore',
        storeId: 'store_2',
        storeName: 'Green Grocery',
        storeAddress: 'Sector 2, HSR',
        items: const [
          OrderItemEntity(
            productId: 'p_2',
            nameSnapshot: 'Brown Bread',
            priceSnapshot: 50.0,
            unit: 'loaf',
            quantity: 1,
          ),
        ],
        deliveryFee: 25.0,
        platformFee: 5.0,
      );
      final order2 = res2.getOrElse(() => throw Exception());

      // FR-DEL-004: Jobs stream in
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.availableJobs.isNotEmpty, isTrue);

      // FR-DEL-005: Decline job with reason
      bloc.add(DeclineDeliveryJobEvent(order2.id, reason: 'Distance too far'));
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.availableJobs.any((j) => j.id == order2.id), isFalse);

      // FR-DEL-005: Accept first job
      bloc.add(AcceptDeliveryJobEvent(orderId: order1.id));
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.activeTrips.isNotEmpty, isTrue);
      expect(bloc.state.activeTrips.first.id, equals(order1.id));
      expect(bloc.state.activeJobStep, equals(DeliveryTripStep.enRouteStore));

      // Single active job enforcement: Attempting to accept another job while busy is blocked
      bloc.add(AcceptDeliveryJobEvent(orderId: order2.id));
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.errorMessage, contains('Single Active Job rule'));
      expect(bloc.state.activeTrips.first.id, equals(order1.id));
    });

    test('FR-DEL-006, 007, 008, 009, 010: Milestone lifecycle from Store pickup to Customer dropoff', () async {
      bloc.add(const ApproveRiderKYCEvent());
      bloc.add(const ToggleDutyEvent(true));
      await Future.delayed(const Duration(milliseconds: 40));

      final res = await orderRepo.createOrder(
        customerId: 'c_201',
        customerName: 'Suresh Menon',
        customerPhone: '9845012345',
        deliveryAddress: 'Tower B, 1204, Prestige Ozone, Whitefield',
        storeId: 'store_wf',
        storeName: 'SuperDaily Whitefield',
        storeAddress: 'Outer Ring Rd, Mahadevapura',
        items: const [
          OrderItemEntity(
            productId: 'p_apple',
            nameSnapshot: 'Kashmiri Apples 1kg',
            priceSnapshot: 180.0,
            unit: 'kg',
            quantity: 1,
          ),
        ],
        deliveryFee: 40.0,
        platformFee: 5.0,
      );
      final order = res.getOrElse(() => throw Exception());

      bloc.add(AcceptDeliveryJobEvent(orderId: order.id));
      await Future.delayed(const Duration(milliseconds: 40));

      // FR-DEL-006: View store pickup info
      expect(bloc.state.activeTrips.first.storeName, equals('SuperDaily Whitefield'));
      expect(bloc.state.activeTrips.first.storeAddress, contains('Outer Ring Rd'));

      // FR-DEL-007: Mark REACHED_STORE
      bloc.add(ArrivedAtStoreEvent(order.id));
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.activeJobStep, equals(DeliveryTripStep.atStore));

      // FR-DEL-008: Mark PICKED_UP
      bloc.add(MarkPickedUpEvent(order.id));
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.activeJobStep, equals(DeliveryTripStep.orderPickedUp));
      expect(orderRepo.orders.first.status, equals(OrderStatus.pickedUp));

      // FR-DEL-009 & FR-DEL-010: OUT_FOR_DELIVERY & View customer delivery location
      bloc.add(MarkOutForDeliveryEvent(order.id));
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.activeJobStep, equals(DeliveryTripStep.enRouteCustomer));
      expect(orderRepo.orders.first.status, equals(OrderStatus.outForDelivery));
      expect(bloc.state.activeTrips.first.customerName, equals('Suresh Menon'));
      expect(bloc.state.activeTrips.first.deliveryAddress, contains('Prestige Ozone'));
    });

    test('FR-DEL-011, 012, 013: Complete delivery via OTP, Cash on Delivery collection, delivery history & earnings', () async {
      bloc.add(const ApproveRiderKYCEvent());
      bloc.add(const ToggleDutyEvent(true));
      await Future.delayed(const Duration(milliseconds: 40));

      final initialWallet = bloc.state.walletBalance;

      final res = await orderRepo.createOrder(
        customerId: 'c_301',
        customerName: 'Deepa Hegde',
        customerPhone: '9740123456',
        deliveryAddress: 'No 15, Koramangala 4th Block',
        storeId: 'store_km',
        storeName: 'Organic Kitchen',
        storeAddress: '80ft Road, Koramangala',
        items: const [
          OrderItemEntity(
            productId: 'p_honey',
            nameSnapshot: 'Raw Wild Honey 500g',
            priceSnapshot: 250.0,
            unit: 'jar',
            quantity: 1,
          ),
        ],
        deliveryFee: 45.0,
        platformFee: 5.0,
        paymentMethod: 'COD',
      );
      final order = res.getOrElse(() => throw Exception());

      bloc.add(AcceptDeliveryJobEvent(orderId: order.id));
      await Future.delayed(const Duration(milliseconds: 40));

      // Arrive at customer location
      bloc.add(ArrivedAtCustomerEvent(order.id));
      await Future.delayed(const Duration(milliseconds: 40));
      expect(bloc.state.activeJobStep, equals(DeliveryTripStep.atCustomer));

      // FR-DEL-011: Complete delivery using customer OTP
      bloc.add(VerifyDeliveryOtpEvent(orderId: order.id, otp: '1234'));
      await Future.delayed(const Duration(milliseconds: 40));

      // Verify delivery marked delivered and COD payment completed
      expect(orderRepo.orders.first.status, equals(OrderStatus.delivered));
      expect(orderRepo.orders.first.paymentStatus, equals('COMPLETED'));
      expect(bloc.state.activeTrips.isEmpty, isTrue);

      // FR-DEL-012: View delivery history
      expect(bloc.state.completedTrips.length, equals(1));
      expect(bloc.state.completedTrips.first.id, equals(order.id));

      // FR-DEL-013: View basic earnings for completed deliveries
      expect(bloc.state.walletBalance, greaterThan(initialWallet));
      expect(bloc.state.todayEarnings, greaterThan(0.0));
      expect(bloc.state.todayCompletedCount, equals(1));
    });
  });
}
