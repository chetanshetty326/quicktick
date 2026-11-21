import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';

class CapturingMockOrderRepository implements IOrderRepository {
  double? capturedLat;
  double? capturedLng;
  String? capturedCity;
  String? capturedPostalCode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
    capturedLat = lat;
    capturedLng = lng;
    capturedCity = city;
    capturedPostalCode = postalCode;

    return Right(OrderEntity(
      id: 'ord_test_123',
      orderNumber: 'QM-12345',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      storeId: storeId,
      storeName: storeName,
      storeAddress: storeAddress,
      items: items,
      subtotal: 100,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      grandTotal: 100 + deliveryFee + platformFee,
      status: OrderStatus.placed,
      paymentMethod: paymentMethod,
      createdAt: DateTime.now(),
      deliveryOtp: '1234',
    ));
  }
}

void main() {
  group('Clean Architecture Order Creation - Zone Coordinates Forwarding', () {
    test('1. Forwarding coordinates: When order is placed in Davangere, Davangere coordinates are captured', () async {
      final repo = CapturingMockOrderRepository();

      const davangereLat = 14.457385;
      const davangereLng = 75.914089;

      await repo.createOrder(
        customerId: 'cust_1',
        customerName: 'Test Customer',
        customerPhone: '9999999901',
        deliveryAddress: 'Vidyanagar, Davangere',
        storeId: 'store_davangere_1',
        storeName: 'Davangere Benne Dosa',
        storeAddress: 'Main Road, Davangere',
        items: [
          const OrderItemEntity(
            productId: 'p_dosa',
            nameSnapshot: 'Benne Dosa',
            priceSnapshot: 60,
            quantity: 2,
            unit: '1 piece',
          ),
        ],
        deliveryFee: 15,
        platformFee: 5,
        zoneId: '6ad4db037ae74bb35cc56360', // Davangere zone ID
        lat: davangereLat,
        lng: davangereLng,
        city: 'Davangere',
        postalCode: '577002',
      );

      // Verify Davangere coordinates were captured and not Bangalore
      expect(repo.capturedLat, equals(davangereLat));
      expect(repo.capturedLng, equals(davangereLng));
      expect(repo.capturedCity, equals('Davangere'));
      expect(repo.capturedPostalCode, equals('577002'));

      // Ensure it is definitely not Bangalore fallback
      expect(repo.capturedLat, isNot(equals(12.9716)));
      expect(repo.capturedLng, isNot(equals(77.5946)));
    });

    test('2. Tarikere order: captures Tarikere coordinates accurately', () async {
      final repo = CapturingMockOrderRepository();

      const tarikereLat = 13.7855;
      const tarikereLng = 76.0770;

      await repo.createOrder(
        customerId: 'cust_2',
        customerName: 'Tarikere Customer',
        customerPhone: '9900799353',
        deliveryAddress: 'Station Road, Tarikere',
        storeId: 'store_tarikere_1',
        storeName: 'Chamundi Bakery',
        storeAddress: 'B.H. Road, Tarikere',
        items: [
          const OrderItemEntity(
            productId: 'p_puff',
            nameSnapshot: 'Egg Puff',
            priceSnapshot: 25,
            quantity: 4,
            unit: '1 piece',
          ),
        ],
        deliveryFee: 10,
        platformFee: 5,
        zoneId: '6ac606440d9f919b26d4e987', // Tarikere zone ID
        lat: tarikereLat,
        lng: tarikereLng,
        city: 'Tarikere',
        postalCode: '577228',
      );

      expect(repo.capturedLat, equals(tarikereLat));
      expect(repo.capturedLng, equals(tarikereLng));
      expect(repo.capturedCity, equals('Tarikere'));
    });
  });
}
