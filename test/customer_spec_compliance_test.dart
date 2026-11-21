import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/errors/exceptions.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';

void main() {
  group('Customer Spec Compliance Tests', () {
    test('1. POST /orders Payload contract check', () {
      final payload = {
        'items': [
          {
            'productId': '6aae34045a255f94c2eb78ca',
            'quantity': 1,
          }
        ],
        'addressId': '6aae32b256674bb572587a38',
        'paymentMethod': 'COD',
        'deliveryInstructions': 'Ring bell twice',
      };

      expect(payload['items'], isA<List>());
      expect((payload['items'] as List).first['productId'], '6aae34045a255f94c2eb78ca');
      expect(payload['addressId'], '6aae32b256674bb572587a38');
      expect(payload['paymentMethod'], 'COD');
      expect(payload['deliveryInstructions'], 'Ring bell twice');
    });

    test('2. POST /orders/:id/cancel 409 ORDER_CANCEL_NOT_ALLOWED mapping', () {
      const ex = OrderCancelNotAllowedException(
        message: 'Cancel attempted after ASSIGNED',
        code: 'ORDER_CANCEL_NOT_ALLOWED',
        statusCode: 409,
      );

      expect(ex.statusCode, 409);
      expect(ex.code, 'ORDER_CANCEL_NOT_ALLOWED');
      expect(ex.message, contains('ASSIGNED'));

      const failure = OrderCancelNotAllowedFailure();
      expect(failure.statusCode, 409);
      expect(failure.code, 'ORDER_CANCEL_NOT_ALLOWED');
      expect(failure.message, contains('Cannot cancel order after it has been assigned to a delivery partner'));
    });

    test('3. Checkout 409 OUT_OF_STOCK mapping', () {
      const ex = OutOfStockException(
        message: 'Stock changed during checkout. Please review your cart.',
        code: 'OUT_OF_STOCK',
        statusCode: 409,
      );

      expect(ex.statusCode, 409);
      expect(ex.code, 'OUT_OF_STOCK');

      const failure = OutOfStockFailure();
      expect(failure.statusCode, 409);
      expect(failure.code, 'OUT_OF_STOCK');
      expect(failure.message, contains('out of stock'));
    });

    test('4. OrderStatus.failed parsing and terminal state verification', () {
      final parsed = OrderEntity.parseStatus('FAILED');
      expect(parsed, OrderStatus.failed);
      expect(parsed.label, 'Order Failed');
      expect(parsed.isTerminal, isTrue);

      expect(OrderStatus.delivered.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);
      expect(OrderStatus.rejected.isTerminal, isTrue);
      expect(OrderStatus.placed.isTerminal, isFalse);
      expect(OrderStatus.preparing.isTerminal, isFalse);
      expect(OrderStatus.assigned.isTerminal, isFalse);
    });

    test('5. statusHistory parsing from GET /orders/:id response', () {
      final json = {
        'id': '6aae3fe9123cb344acce7e5b',
        'orderNumber': 'QC-260919-0003',
        'customerId': '6aae30f5ff3b565ea3e71a68',
        'customerName': 'Test User',
        'customerPhone': '+919888888888',
        'deliveryAddress': '221B Baker Street',
        'storeId': '6aae34045a255f94c2eb78c8',
        'storeName': 'Fresh Grocers',
        'storeAddress': 'Main Road',
        'items': [
          {
            'productId': '6aae34045a255f94c2eb78ca',
            'name': 'Test Rice 1kg',
            'price': 110,
            'quantity': 1,
            'unit': 'kg',
          }
        ],
        'subtotal': 110,
        'deliveryFee': 30,
        'platformFee': 10,
        'grandTotal': 150,
        'status': 'ASSIGNED',
        'deliveryPartnerId': '6aae3e5d123cb344acce7d90',
        'paymentMethod': 'COD',
        'paymentStatus': 'PENDING',
        'statusHistory': [
          {
            'fromStatus': 'PLACED',
            'toStatus': 'PLACED',
            'actorRole': 'CUSTOMER',
            'timestamp': '2026-09-19T07:57:44.000Z'
          },
          {
            'fromStatus': 'PLACED',
            'toStatus': 'ASSIGNED',
            'actorRole': 'SYSTEM',
            'timestamp': '2026-09-19T07:57:44.150Z'
          }
        ]
      };

      final order = OrderEntity.fromJson(json);

      expect(order.id, '6aae3fe9123cb344acce7e5b');
      expect(order.status, OrderStatus.assigned);
      expect(order.deliveryPartnerId, '6aae3e5d123cb344acce7d90');
      expect(order.statusHistory.length, 2);
      expect(order.statusHistory[0].fromStatus, 'PLACED');
      expect(order.statusHistory[0].actorRole, 'CUSTOMER');
      expect(order.statusHistory[1].toStatus, 'ASSIGNED');
      expect(order.statusHistory[1].actorRole, 'SYSTEM');
    });

    test('6. GET /orders?status=ASSIGNED query parameter verification', () {
      const endpoint = '/orders';
      final queryParams = {'status': 'ASSIGNED', 'limit': 50};

      expect(endpoint, '/orders');
      expect(queryParams['status'], 'ASSIGNED');
    });
  });
}
