import 'package:equatable/equatable.dart';

class RetailerBankAccountEntity extends Equatable {
  final String holderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final bool verified;

  const RetailerBankAccountEntity({
    this.holderName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.bankName = '',
    this.verified = false,
  });

  String get maskedAccountNumber {
    if (accountNumber.length > 4) {
      return '•••• ${accountNumber.substring(accountNumber.length - 4)}';
    }
    return accountNumber;
  }

  bool get isConfigured => accountNumber.isNotEmpty && ifscCode.isNotEmpty;

  @override
  List<Object?> get props => [
        holderName,
        accountNumber,
        ifscCode,
        bankName,
        verified,
      ];
}

class RetailerEarningsPeriodEntity extends Equatable {
  final double netPayout;
  final double subtotal;
  final double platformFee;
  final int ordersCount;

  const RetailerEarningsPeriodEntity({
    this.netPayout = 0.0,
    this.subtotal = 0.0,
    this.platformFee = 0.0,
    this.ordersCount = 0,
  });

  @override
  List<Object?> get props => [netPayout, subtotal, platformFee, ordersCount];
}

class RetailerEarningsSummaryEntity extends Equatable {
  final RetailerEarningsPeriodEntity today;
  final RetailerEarningsPeriodEntity thisWeek;
  final RetailerEarningsPeriodEntity thisMonth;
  final RetailerEarningsPeriodEntity lifetime;

  const RetailerEarningsSummaryEntity({
    this.today = const RetailerEarningsPeriodEntity(),
    this.thisWeek = const RetailerEarningsPeriodEntity(),
    this.thisMonth = const RetailerEarningsPeriodEntity(),
    this.lifetime = const RetailerEarningsPeriodEntity(),
  });

  @override
  List<Object?> get props => [today, thisWeek, thisMonth, lifetime];
}

class RetailerEarningEntity extends Equatable {
  final String id;
  final String orderId;
  final String orderNumber;
  final double subtotal;
  final double platformFee;
  final double netPayout;
  final String status;
  final DateTime createdAt;

  const RetailerEarningEntity({
    required this.id,
    required this.orderId,
    this.orderNumber = '',
    required this.subtotal,
    required this.platformFee,
    required this.netPayout,
    this.status = 'AVAILABLE',
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        orderId,
        orderNumber,
        subtotal,
        platformFee,
        netPayout,
        status,
        createdAt,
      ];
}

class RetailerSettlementEntity extends Equatable {
  final String id;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final double amount;
  final String status; // PENDING, APPROVED, PAID, REJECTED, FAILED
  final String paymentReference;
  final String notes;
  final DateTime createdAt;

  const RetailerSettlementEntity({
    required this.id,
    this.periodStart,
    this.periodEnd,
    required this.amount,
    required this.status,
    this.paymentReference = '',
    this.notes = '',
    required this.createdAt,
  });

  bool get isPaid => status.toUpperCase() == 'PAID';
  bool get isPending => status.toUpperCase() == 'PENDING';

  @override
  List<Object?> get props => [
        id,
        periodStart,
        periodEnd,
        amount,
        status,
        paymentReference,
        notes,
        createdAt,
      ];
}
