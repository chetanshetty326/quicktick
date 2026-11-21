import '../../domain/entities/doorstep_qr_entity.dart';

class DoorstepQrModel extends DoorstepQrEntity {
  const DoorstepQrModel({
    required super.orderId,
    required super.orderNumber,
    required super.amount,
    required super.qrId,
    required super.imageUrl,
    required super.upiIntent,
    super.expiresAt,
    required super.paymentStatus,
    super.reused = false,
  });

  factory DoorstepQrModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json['data'] is Map) {
      data = Map<String, dynamic>.from(json['data'] as Map);
    }

    DateTime? parsedExpiry;
    final expStr = data['expiresAt']?.toString();
    if (expStr != null && expStr.isNotEmpty) {
      parsedExpiry = DateTime.tryParse(expStr);
    }

    return DoorstepQrModel(
      orderId: (data['orderId'] ?? data['_id'] ?? data['id'] ?? '').toString(),
      orderNumber: (data['orderNumber'] ?? '').toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      qrId: (data['qrId'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      upiIntent: (data['upiIntent'] ?? '').toString(),
      expiresAt: parsedExpiry,
      paymentStatus: (data['paymentStatus'] ?? 'PENDING').toString(),
      reused: data['reused'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'amount': amount,
      'qrId': qrId,
      'imageUrl': imageUrl,
      'upiIntent': upiIntent,
      'expiresAt': expiresAt?.toIso8601String(),
      'paymentStatus': paymentStatus,
      'reused': reused,
    };
  }
}

class QrPaymentStatusModel extends QrPaymentStatusEntity {
  const QrPaymentStatusModel({
    required super.orderId,
    required super.orderNumber,
    required super.paymentStatus,
    super.qrExists = true,
    super.expiresAt,
    super.secondsLeft = 0,
    super.razorpayPaymentId,
    super.paidAt,
  });

  factory QrPaymentStatusModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> data = json;
    if (json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json['data'] is Map) {
      data = Map<String, dynamic>.from(json['data'] as Map);
    }

    DateTime? parsedExpiry;
    final expStr = data['expiresAt']?.toString();
    if (expStr != null && expStr.isNotEmpty) {
      parsedExpiry = DateTime.tryParse(expStr);
    }

    DateTime? parsedPaidAt;
    final paidStr = data['paidAt']?.toString();
    if (paidStr != null && paidStr.isNotEmpty) {
      parsedPaidAt = DateTime.tryParse(paidStr);
    }

    return QrPaymentStatusModel(
      orderId: (data['orderId'] ?? data['_id'] ?? data['id'] ?? '').toString(),
      orderNumber: (data['orderNumber'] ?? '').toString(),
      paymentStatus: (data['paymentStatus'] ?? 'PENDING').toString(),
      qrExists: data['qrExists'] != false,
      expiresAt: parsedExpiry,
      secondsLeft: (data['secondsLeft'] as num?)?.toInt() ?? 0,
      razorpayPaymentId: data['razorpayPaymentId']?.toString(),
      paidAt: parsedPaidAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'paymentStatus': paymentStatus,
      'qrExists': qrExists,
      'expiresAt': expiresAt?.toIso8601String(),
      'secondsLeft': secondsLeft,
      'razorpayPaymentId': razorpayPaymentId,
      'paidAt': paidAt?.toIso8601String(),
    };
  }
}
