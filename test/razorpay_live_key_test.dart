import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/network/api_endpoints.dart';
import 'package:quicklink/features/order/data/datasources/payment_remote_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Razorpay Live Key & Sanitization Verification', () {
    test('ApiEndpoints defines RAZORPAY_KEY_ID from environment', () {
      expect(ApiEndpoints.razorpayLiveKeyId, isA<String>());
      expect(ApiEndpoints.defaultRazorpayKeyId, equals(ApiEndpoints.razorpayLiveKeyId));
    });

    test('RazorpayOrderModel parses order data correctly', () {
      final model = RazorpayOrderModel.fromJson({
        'data': {
          'id': 'order_live_1234567890',
          'amount': 25000,
          'keyId': 'rzp_live_testdummykey12345',
        }
      });

      expect(model.keyId, equals('rzp_live_testdummykey12345'));
      expect(model.amount, equals(25000));
    });

    test('RazorpayOrderModel sanitizes keyId if passed as concatenated key and secret', () {
      final model = RazorpayOrderModel.fromJson({
        'data': {
          'id': 'order_live_1234567890',
          'amount': 25000,
          'keyId': 'rzp_live_testdummykey12345extraSecretDataHere',
        }
      });

      expect(model.keyId, equals('rzp_live_testdummykey12345'));
    });

    test('Sanitization logic extracts exact 23-char Key ID from concatenated strings', () {
      const fullInput = 'rzp_live_testdummykey12345extraSecretDataHere';
      final cleanKey = (fullInput.startsWith('rzp_live_') && fullInput.length > 23)
          ? fullInput.substring(0, 23)
          : fullInput;

      expect(cleanKey, equals('rzp_live_testdummykey12345'));
      expect(cleanKey.length, equals(23));
    });
  });
}
