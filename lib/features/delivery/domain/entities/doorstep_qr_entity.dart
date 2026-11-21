import 'package:equatable/equatable.dart';

class DoorstepQrEntity extends Equatable {
  final String orderId;
  final String orderNumber;
  final double amount;
  final String qrId;
  final String imageUrl;
  final String upiIntent;
  final DateTime? expiresAt;
  final String paymentStatus;
  final bool reused;

  const DoorstepQrEntity({
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.qrId,
    required this.imageUrl,
    required this.upiIntent,
    this.expiresAt,
    required this.paymentStatus,
    this.reused = false,
  });

  bool get isCompleted => paymentStatus.toUpperCase() == 'COMPLETED';
  bool get isPending => paymentStatus.toUpperCase() == 'PENDING';

  int get remainingSeconds {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  @override
  List<Object?> get props => [
        orderId,
        orderNumber,
        amount,
        qrId,
        imageUrl,
        upiIntent,
        expiresAt,
        paymentStatus,
        reused,
      ];
}

class QrPaymentStatusEntity extends Equatable {
  final String orderId;
  final String orderNumber;
  final String paymentStatus;
  final bool qrExists;
  final DateTime? expiresAt;
  final int secondsLeft;
  final String? razorpayPaymentId;
  final DateTime? paidAt;

  const QrPaymentStatusEntity({
    required this.orderId,
    required this.orderNumber,
    required this.paymentStatus,
    this.qrExists = true,
    this.expiresAt,
    this.secondsLeft = 0,
    this.razorpayPaymentId,
    this.paidAt,
  });

  bool get isCompleted => paymentStatus.toUpperCase() == 'COMPLETED';
  bool get isPending => paymentStatus.toUpperCase() == 'PENDING';
  bool get isExpired =>
      secondsLeft <= 0 &&
      (expiresAt != null ? DateTime.now().isAfter(expiresAt!) : false);

  @override
  List<Object?> get props => [
        orderId,
        orderNumber,
        paymentStatus,
        qrExists,
        expiresAt,
        secondsLeft,
        razorpayPaymentId,
        paidAt,
      ];
}
