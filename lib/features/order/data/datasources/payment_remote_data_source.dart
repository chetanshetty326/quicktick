import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

class RazorpayOrderModel {
  final String orderId;
  final String razorpayOrderId;
  final int amount; // in paise for Razorpay SDK (e.g. 19000 for ₹190)
  final double amountInRupees; // in rupees (e.g. 190.0)
  final String currency;
  final String keyId;

  const RazorpayOrderModel({
    required this.orderId,
    required this.razorpayOrderId,
    required this.amount,
    this.amountInRupees = 0.0,
    required this.currency,
    required this.keyId,
  });

  factory RazorpayOrderModel.fromJson(Map<String, dynamic> json, {String? defaultOrderId}) {
    final data = json['data'] is Map ? json['data'] as Map : json;
    final metadata = data['metadata'] is Map ? data['metadata'] as Map : {};

    // 1. Resolve keyId: metadata.keyId > data.keyId > default
    final rawKeyId = metadata['keyId']?.toString() ??
        data['keyId']?.toString() ??
        ApiEndpoints.defaultRazorpayKeyId;
    final keyId = (rawKeyId.startsWith('rzp_live_') && rawKeyId.length > 23)
        ? rawKeyId.substring(0, 23)
        : (rawKeyId.startsWith('rzp_test_') && rawKeyId.length > 23)
            ? rawKeyId.substring(0, 23)
            : rawKeyId;

    // 2. Resolve razorpayOrderId: metadata.razorpayOrderId > data.paymentId > data.razorpayOrderId > data.id
    final razorpayOrderId = metadata['razorpayOrderId']?.toString() ??
        data['paymentId']?.toString() ??
        data['razorpayOrderId']?.toString() ??
        data['id']?.toString() ??
        '';

    // 3. Resolve orderId: data.orderId > metadata.orderId > defaultOrderId
    final orderId = data['orderId']?.toString() ??
        metadata['orderId']?.toString() ??
        defaultOrderId ??
        '';

    // 4. Resolve Amount:
    // Razorpay standard returns amount in integer paise (e.g. 45850 paise = ₹458.50).
    final rawAmount = data['amount'];
    final int amountInPaise;
    final double amountInRupees;

    if (data['amountInPaise'] is num) {
      amountInPaise = (data['amountInPaise'] as num).toInt();
      amountInRupees = (data['amountInRupees'] as num?)?.toDouble() ?? (amountInPaise / 100.0);
    } else if (rawAmount is num) {
      final double val = rawAmount.toDouble();
      if (rawAmount is int || (val == val.roundToDouble() && val >= 100)) {
        amountInPaise = val.toInt();
        amountInRupees = (data['amountInRupees'] as num?)?.toDouble() ?? (amountInPaise / 100.0);
      } else {
        amountInRupees = val;
        amountInPaise = (val * 100).round();
      }
    } else {
      amountInPaise = 0;
      amountInRupees = 0.0;
    }

    final currency = data['currency']?.toString() ?? 'INR';

    return RazorpayOrderModel(
      orderId: orderId,
      razorpayOrderId: razorpayOrderId,
      amount: amountInPaise,
      amountInRupees: amountInRupees,
      currency: currency,
      keyId: keyId,
    );
  }
}

class PaymentVerificationModel {
  final bool success;
  final String paymentId;
  final String status;
  final String orderId;
  final bool idempotent;
  final String? errorCode;
  final String? errorMessage;

  const PaymentVerificationModel({
    required this.success,
    required this.paymentId,
    required this.status,
    required this.orderId,
    this.idempotent = false,
    this.errorCode,
    this.errorMessage,
  });

  bool get isRetryable => errorCode == 'VERIFY_TX_FAILED';
  bool get isPending =>
      !isRetryable && (status == 'PENDING' || status == 'AUTHORIZED' || status == 'PROCESSING' || status == 'PAYMENT_PENDING');
  bool get isFailed => status == 'FAILED' || isRetryable;
  bool get isCaptured => status == 'COMPLETED' || status == 'CAPTURED';
  bool get isSuccess => isCaptured;

  factory PaymentVerificationModel.fromJson(Map<String, dynamic> json, {String? fallbackOrderId}) {
    final data = json['data'] is Map ? json['data'] as Map : json;
    final errMap = json['error'] is Map
        ? json['error'] as Map
        : (data['error'] is Map ? data['error'] as Map : null);
    final errCode = errMap?['code']?.toString() ?? json['code']?.toString() ?? data['code']?.toString();
    final errMsg = errMap?['message']?.toString() ?? json['message']?.toString() ?? data['message']?.toString();

    final isVerifyTxFailed = errCode == 'VERIFY_TX_FAILED';
    final status = data['status']?.toString().toUpperCase() ?? (isVerifyTxFailed ? 'FAILED' : 'COMPLETED');
    final hasFailed = status == 'FAILED' || data['success'] == false || json['success'] == false || isVerifyTxFailed;
    final isPending = !isVerifyTxFailed && (status == 'PENDING' || status == 'AUTHORIZED' || status == 'PROCESSING');
    final isSuccess = !hasFailed && (status == 'COMPLETED' || status == 'CAPTURED' || isPending || data['success'] == true || json['success'] == true);
    final isIdempotent = data['idempotent'] == true || json['idempotent'] == true || isVerifyTxFailed;

    return PaymentVerificationModel(
      success: isSuccess,
      paymentId: data['paymentId']?.toString() ?? '',
      status: status,
      orderId: data['orderId']?.toString() ?? fallbackOrderId ?? '',
      idempotent: isIdempotent,
      errorCode: errCode,
      errorMessage: errMsg,
    );
  }
}

class PaymentStatusModel {
  final String orderId;
  final String status; // PENDING, COMPLETED, FAILED, REFUNDED, CANCELLED
  final String method; // ONLINE, COD
  final double amount;
  final String razorpayOrderId;
  final String razorpayPaymentId;

  const PaymentStatusModel({
    required this.orderId,
    required this.status,
    required this.method,
    required this.amount,
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
  });

  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isFailed => status.toUpperCase() == 'FAILED';
  bool get isRefunded => status.toUpperCase() == 'REFUNDED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  String get paymentMethod => method;

  factory PaymentStatusModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map : json;
    return PaymentStatusModel(
      orderId: data['orderId']?.toString() ?? '',
      status: data['status']?.toString().toUpperCase() ?? 'PENDING',
      method: data['method']?.toString().toUpperCase() ?? 'ONLINE',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      razorpayOrderId: data['razorpayOrderId']?.toString() ?? '',
      razorpayPaymentId: data['razorpayPaymentId']?.toString() ?? '',
    );
  }
}

abstract class IPaymentRemoteDataSource {
  Future<bool> confirmCodPayment(String orderId);
  Future<RazorpayOrderModel> createRazorpayOrder(String orderId, {double? amount, String currency = 'INR'});
  Future<PaymentVerificationModel> verifyPaymentSignature({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String orderId,
  });
  Future<PaymentStatusModel> getPaymentStatus(String orderId);
  Future<bool> initiateRefund({
    required String razorpayPaymentId,
    required double amount,
    String? orderId,
    String? reason,
  });
}

class PaymentRemoteDataSourceImpl implements IPaymentRemoteDataSource {
  final ApiClient _apiClient;

  PaymentRemoteDataSourceImpl(this._apiClient);

  @override
  Future<bool> confirmCodPayment(String orderId) async {
    final response = await _apiClient.post(
      ApiEndpoints.paymentsCod,
      data: {'orderId': orderId},
    );
    final data = response.data;
    return data is Map && (data['success'] == true || data['data'] != null);
  }

  @override
  Future<RazorpayOrderModel> createRazorpayOrder(String orderId, {double? amount, String currency = 'INR'}) async {
    final payload = <String, dynamic>{
      'orderId': orderId,
    };
    final response = await _apiClient.post(
      ApiEndpoints.paymentsRazorpayCreateOrder,
      data: payload,
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return RazorpayOrderModel.fromJson(data, defaultOrderId: orderId);
    } else if (data is Map) {
      return RazorpayOrderModel.fromJson(Map<String, dynamic>.from(data), defaultOrderId: orderId);
    }

    throw Exception('Invalid Razorpay create-order response');
  }

  @override
  Future<PaymentVerificationModel> verifyPaymentSignature({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String orderId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.paymentsRazorpayVerifySignature,
        data: {
          'orderId': orderId,
          'razorpayOrderId': razorpayOrderId,
          'razorpayPaymentId': razorpayPaymentId,
          'razorpaySignature': razorpaySignature,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return PaymentVerificationModel.fromJson(data, fallbackOrderId: orderId);
      } else if (data is Map) {
        return PaymentVerificationModel.fromJson(Map<String, dynamic>.from(data), fallbackOrderId: orderId);
      }

      throw Exception('Invalid payment signature verification response');
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final resData = e.response?.data;
      String errCode = '';
      String errMsg = '';
      if (resData is Map) {
        final errMap = resData['error'] is Map ? resData['error'] : resData;
        errCode = errMap['code']?.toString() ?? resData['code']?.toString() ?? '';
        errMsg = errMap['message']?.toString() ?? resData['message']?.toString() ?? '';
      }

      // 409 ORDER_NOT_PAYMENT_PENDING: Payment already processed/idempotent
      if (statusCode == 409 || errCode == 'ORDER_NOT_PAYMENT_PENDING') {
        return PaymentVerificationModel(
          success: true,
          paymentId: razorpayPaymentId,
          status: 'COMPLETED',
          orderId: orderId,
          idempotent: true,
        );
      }

      // VERIFY_TX_FAILED: Payment recorded but order update failed. Retry is safe/idempotent per Section 2.7.
      if (errCode == 'VERIFY_TX_FAILED' || errMsg.contains('VERIFY_TX_FAILED') || errMsg.toLowerCase().contains('retry is safe')) {
        return PaymentVerificationModel(
          success: false,
          paymentId: razorpayPaymentId,
          status: 'FAILED',
          orderId: orderId,
          idempotent: true,
          errorCode: 'VERIFY_TX_FAILED',
          errorMessage: errMsg.isNotEmpty
              ? errMsg
              : 'Payment recorded but order update failed. Contact support — retry is safe.',
        );
      }

      // 400 SIGNATURE_INVALID: Cryptographic signature mismatch, do not retry
      if (statusCode == 400 && (errCode == 'SIGNATURE_INVALID' || errMsg.toLowerCase().contains('signature'))) {
        return PaymentVerificationModel(
          success: false,
          paymentId: razorpayPaymentId,
          status: 'FAILED',
          orderId: orderId,
          idempotent: false,
          errorCode: 'SIGNATURE_INVALID',
          errorMessage: errMsg.isNotEmpty ? errMsg : 'Payment signature verification failed.',
        );
      }

      if (errMsg.isNotEmpty) {
        throw Exception(errMsg);
      }
      throw Exception(e.message ?? 'Payment verification failed');
    }
  }

  @override
  Future<PaymentStatusModel> getPaymentStatus(String orderId) async {
    final response = await _apiClient.get(ApiEndpoints.paymentStatus(orderId));
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return PaymentStatusModel.fromJson(data);
    } else if (data is Map) {
      return PaymentStatusModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Invalid payment status response');
  }

  @override
  Future<bool> initiateRefund({
    required String razorpayPaymentId,
    required double amount,
    String? orderId,
    String? reason,
  }) async {
    try {
      // 1. Try spec endpoint: POST /payments/:razorpayPaymentId/refund
      if (razorpayPaymentId.isNotEmpty) {
        final response = await _apiClient.post(
          ApiEndpoints.paymentsRazorpayRefund(razorpayPaymentId),
          data: {'amount': amount},
        );
        final data = response.data;
        if (data is Map && (data['success'] == true || data['data'] != null)) {
          return true;
        }
      }
    } catch (_) {}

    // 2. Fallback to generic refund endpoint
    final response = await _apiClient.post(
      ApiEndpoints.paymentsRefund,
      data: {
        'paymentId': razorpayPaymentId,
        'orderId': ?orderId,
        'amount': amount,
        'reason': ?reason,
      },
    );
    final data = response.data;
    return data is Map && data['success'] == true;
  }
}
