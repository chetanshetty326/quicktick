import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/network/api_endpoints.dart';
import 'package:quicklink/features/customer/data/models/cart_pricing_model.dart';
import 'package:quicklink/features/customer/data/models/coupon_model.dart';
import 'package:quicklink/features/customer/domain/entities/cart_pricing_entity.dart';
import 'package:quicklink/features/order/data/datasources/payment_remote_data_source.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';

void main() {
  group('Step 1: Backend Source of Truth for Pricing (GET /cart)', () {
    test('CartPricingModel parses all pricing fields and taxBreakdown correctly', () {
      final jsonResponse = {
        'success': true,
        'data': {
          'items': [],
          'subtotal': 450,
          'deliveryFee': 0,
          'platformFee': 5,
          'discount': 50,
          'tip': 20,
          'tax': 33.5,
          'taxBreakdown': {
            'cgst': 16.75,
            'sgst': 16.75,
            'igst': 0,
            'total': 33.5,
          },
          'total': 458.5,
          'freeDeliveryThreshold': 199.0,
          'minOrderAmount': 99.0,
        }
      };

      final model = CartPricingModel.fromJson(jsonResponse);

      expect(model.subtotal, 450.0);
      expect(model.deliveryFee, 0.0);
      expect(model.isFreeDelivery, isTrue);
      expect(model.platformFee, 5.0);
      expect(model.discount, 50.0);
      expect(model.tip, 20.0);
      expect(model.tax, 33.5);
      expect(model.taxBreakdown.cgst, 16.75);
      expect(model.taxBreakdown.sgst, 16.75);
      expect(model.taxBreakdown.igst, 0.0);
      expect(model.taxBreakdown.total, 33.5);
      expect(model.taxBreakdown.hasBreakdown, isTrue);
      expect(model.total, 458.5);
      expect(model.freeDeliveryThreshold, 199.0);
      expect(model.minOrderAmount, 99.0);
    });

    test('CartPricingModel parses fallback values when optional fields are omitted', () {
      final jsonResponse = {
        'subtotal': 100,
        'deliveryFee': 15,
        'platformFee': 5,
        'total': 120,
      };

      final model = CartPricingModel.fromJson(jsonResponse);

      expect(model.subtotal, 100.0);
      expect(model.deliveryFee, 15.0);
      expect(model.isFreeDelivery, isFalse);
      expect(model.platformFee, 5.0);
      expect(model.discount, 0.0);
      expect(model.tip, 0.0);
      expect(model.tax, 0.0);
      expect(model.taxBreakdown.hasBreakdown, isFalse);
      expect(model.total, 120.0);
    });
  });

  group('Step 2 & 3: Available Coupons and Validation Reason Codes', () {
    test('CouponValidationModel maps reason codes to clear customer messages', () {
      final reasons = {
        'MIN_ORDER_NOT_MET': 'Add more items to use this coupon',
        'EXPIRED': 'This coupon has expired',
        'INVALID_CODE': 'Invalid coupon code',
        'NOT_APPLICABLE_TO_RETAILER': 'Coupon does not apply to this shop',
        'USAGE_LIMIT_REACHED': 'Coupon is no longer available',
        'ALREADY_USED': 'You have already used this coupon',
      };

      for (final entry in reasons.entries) {
        final json = {
          'data': {
            'valid': false,
            'reason': entry.key,
            'code': 'SAVE50',
          }
        };

        final validation = CouponValidationModel.fromJson(json);

        expect(validation.isValid, isFalse, reason: 'Failed for ${entry.key}');
        expect(validation.errorCode, entry.key);
        expect(validation.errorMessage, entry.value);
      }
    });

    test('CouponValidationModel correctly parses successful validation', () {
      final json = {
        'data': {
          'valid': true,
          'code': 'QUICK50',
          'discount': 50,
          'freeDelivery': true,
        }
      };

      final validation = CouponValidationModel.fromJson(json);

      expect(validation.isValid, isTrue);
      expect(validation.code, 'QUICK50');
      expect(validation.discount, 50.0);
      expect(validation.freeDelivery, isTrue);
    });
  });

  group('Step 4: Order Creation Itemized Pricing Fields', () {
    test('OrderEntity constructor and serialization retain all pricing fields', () {
      final order = OrderEntity(
        id: 'ord_123',
        orderNumber: 'QM-12345',
        customerId: 'cust_1',
        customerName: 'Chetan',
        customerPhone: '+919999999999',
        deliveryAddress: 'Main St',
        storeId: 'store_1',
        storeName: 'Test Store',
        storeAddress: 'Market Rd',
        items: const [],
        subtotal: 450.0,
        deliveryFee: 0.0,
        platformFee: 5.0,
        discount: 50.0,
        tip: 20.0,
        tax: 33.5,
        taxBreakdown: const TaxBreakdownEntity(cgst: 16.75, sgst: 16.75, igst: 0.0, total: 33.5),
        couponCode: 'SAVE50',
        grandTotal: 458.5,
        status: OrderStatus.placed,
        deliveryOtp: '1234',
        paymentStatus: 'PENDING',
        createdAt: DateTime(2026, 10, 26),
      );

      final json = order.toJson();
      final reconstituted = OrderEntity.fromJson(json);

      expect(reconstituted.subtotal, 450.0);
      expect(reconstituted.deliveryFee, 0.0);
      expect(reconstituted.platformFee, 5.0);
      expect(reconstituted.discount, 50.0);
      expect(reconstituted.tip, 20.0);
      expect(reconstituted.tax, 33.5);
      expect(reconstituted.taxBreakdown.cgst, 16.75);
      expect(reconstituted.taxBreakdown.sgst, 16.75);
      expect(reconstituted.couponCode, 'SAVE50');
      expect(reconstituted.grandTotal, 458.5);
    });
  });

  group('Step 5: Razorpay Payment Amount in Paise (No * 100 Multiplier)', () {
    test('RazorpayOrderModel parses backend amount directly in paise', () {
      // Backend returns amount in paise (e.g. 45850 paise = ₹458.50)
      final backendResponse = {
        'data': {
          'orderId': 'ord_123',
          'razorpayOrderId': 'order_rzp_456',
          'amount': 45850,
          'currency': 'INR',
          'keyId': 'rzp_test_123',
        }
      };

      final rzpOrder = RazorpayOrderModel.fromJson(backendResponse);

      // Amount should directly be 45850 paise, NOT multiplied by 100 to 4585000
      expect(rzpOrder.amount, 45850);
      expect(rzpOrder.amountInRupees, 458.50);
      expect(rzpOrder.razorpayOrderId, 'order_rzp_456');
    });
  });

  group('Step 6: Razorpay Payment Verification & Pending Handling', () {
    test('PaymentVerificationModel recognizes PAYMENT_PENDING as pending (not failed)', () {
      final json = {
        'data': {
          'orderId': 'ord_123',
          'paymentId': 'pay_789',
          'status': 'PAYMENT_PENDING',
        }
      };

      final verification = PaymentVerificationModel.fromJson(json);

      expect(verification.isPending, isTrue);
      expect(verification.isFailed, isFalse);
      expect(verification.isSuccess, isFalse);
    });

    test('PaymentVerificationModel recognizes CAPTURED as confirmed success', () {
      final json = {
        'data': {
          'orderId': 'ord_123',
          'paymentId': 'pay_789',
          'status': 'CAPTURED',
        }
      };

      final verification = PaymentVerificationModel.fromJson(json);

      expect(verification.isSuccess, isTrue);
      expect(verification.isPending, isFalse);
      expect(verification.isFailed, isFalse);
    });
  });

  group('Step 7: Order Invoice Endpoint', () {
    test('ApiEndpoints.orderInvoice produces correct route', () {
      expect(ApiEndpoints.orderInvoice('60d5ecb8b5c9c62b3c8f1234'), '/orders/60d5ecb8b5c9c62b3c8f1234/invoice');
    });
  });
}
