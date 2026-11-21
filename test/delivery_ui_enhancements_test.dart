import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/delivery/domain/entities/delivery_notification_entity.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_payment_history_screen.dart';
import 'package:quicklink/features/delivery/presentation/screens/delivery_active_navigation_screen.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';

void main() {
  group('Delivery Domain & Entity Enhancements', () {
    test('DeliveryNotificationEntity correctly computes relative timeAgo', () {
      final now = DateTime.now();

      final justNow = DeliveryNotificationEntity(
        id: '1',
        title: 'Order Assigned',
        body: 'Order #101 has been assigned to you',
        type: 'DELIVERY_ASSIGNED',
        createdAt: now.subtract(const Duration(seconds: 20)),
        isRead: false,
      );
      expect(justNow.timeAgo, 'Just now');

      final fiveMinsAgo = DeliveryNotificationEntity(
        id: '2',
        title: 'Radar Alert',
        body: 'New order available nearby',
        type: 'SYSTEM',
        createdAt: now.subtract(const Duration(minutes: 5)),
        isRead: false,
      );
      expect(fiveMinsAgo.timeAgo, '5m ago');

      final twoHoursAgo = DeliveryNotificationEntity(
        id: '3',
        title: 'Payout Deposited',
        body: '₹550 has been settled to your bank account',
        type: 'PAYMENT_CREDITED',
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: true,
      );
      expect(twoHoursAgo.timeAgo, '2h ago');

      final threeDaysAgo = DeliveryNotificationEntity(
        id: '4',
        title: 'Weekly Summary',
        body: 'You completed 42 trips this week',
        type: 'SYSTEM',
        createdAt: now.subtract(const Duration(days: 3)),
        isRead: true,
      );
      expect(threeDaysAgo.timeAgo, '3d ago');
    });

    test('DeliveryPaymentHistoryScreen supports isEmbedded parameter for tab embedding', () {
      const embeddedScreen = DeliveryPaymentHistoryScreen(isEmbedded: true);
      expect(embeddedScreen.isEmbedded, isTrue);

      const standaloneScreen = DeliveryPaymentHistoryScreen();
      expect(standaloneScreen.isEmbedded, isFalse);
    });

    test('DeliveryActiveNavigationScreen supports isEmbedded and onBackToRadar callbacks', () {
      final order = OrderEntity(
        id: 'order_123',
        orderNumber: 'ORD-999',
        customerId: 'cust_1',
        customerName: 'Aarav Patel',
        customerPhone: '+919876543210',
        deliveryAddress: 'Flat 402, Sunshine Towers, Bangalore',
        storeId: 'store_1',
        storeName: 'Apollo Pharmacy',
        storeAddress: 'Indiranagar 100ft Road',
        items: const [],
        subtotal: 450.0,
        deliveryFee: 55.0,
        platformFee: 5.0,
        grandTotal: 510.0,
        status: OrderStatus.pickedUp,
        deliveryOtp: '1234',
        createdAt: DateTime.now(),
      );

      bool backCalled = false;
      final screen = DeliveryActiveNavigationScreen(
        order: order,
        isEmbedded: true,
        onBackToRadar: () => backCalled = true,
      );

      expect(screen.isEmbedded, isTrue);
      expect(screen.onBackToRadar, isNotNull);
      screen.onBackToRadar!();
      expect(backCalled, isTrue);
    });
  });
}
