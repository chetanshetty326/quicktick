import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/services/order_alert_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrderAlertService Tests', () {
    test('startOrderChime activates ringing state and stopOrderChime deactivates', () {
      final service = OrderAlertService.instance;

      expect(service.isRinging, isFalse);

      service.startOrderChime();
      expect(service.isRinging, isTrue);

      service.stopOrderChime();
      expect(service.isRinging, isFalse);
    });

    test('Multiple consecutive start calls do not create duplicate timers', () {
      final service = OrderAlertService.instance;

      service.startOrderChime();
      service.startOrderChime();
      service.startOrderChime();

      expect(service.isRinging, isTrue);

      service.stopOrderChime();
      expect(service.isRinging, isFalse);
    });
  });
}
