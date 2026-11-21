import '../../domain/entities/retailer_finance_entities.dart';

class RetailerBankAccountModel extends RetailerBankAccountEntity {
  const RetailerBankAccountModel({
    super.holderName,
    super.accountNumber,
    super.ifscCode,
    super.bankName,
    super.verified,
  });

  factory RetailerBankAccountModel.fromJson(Map<String, dynamic> json) {
    return RetailerBankAccountModel(
      holderName: json['holderName']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      ifscCode: json['ifscCode']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      verified: json['verified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'holderName': holderName,
        'accountNumber': accountNumber,
        'ifscCode': ifscCode,
        'bankName': bankName,
      };
}

class RetailerEarningsPeriodModel extends RetailerEarningsPeriodEntity {
  const RetailerEarningsPeriodModel({
    super.netPayout,
    super.subtotal,
    super.platformFee,
    super.ordersCount,
  });

  factory RetailerEarningsPeriodModel.fromJson(Map<String, dynamic> json) {
    final sub = (json['subtotal'] as num?)?.toDouble() ??
        (json['gross'] as num?)?.toDouble() ??
        (json['total'] as num?)?.toDouble() ??
        0.0;
    final fee = (json['platformFee'] as num?)?.toDouble() ??
        (json['fee'] as num?)?.toDouble() ??
        0.0;
    final net = (json['netPayout'] as num?)?.toDouble() ??
        (json['amount'] as num?)?.toDouble() ??
        (sub - fee);

    return RetailerEarningsPeriodModel(
      netPayout: net,
      subtotal: sub,
      platformFee: fee,
      ordersCount: (json['ordersCount'] as num?)?.toInt() ??
          (json['count'] as num?)?.toInt() ??
          0,
    );
  }
}

class RetailerEarningsSummaryModel extends RetailerEarningsSummaryEntity {
  const RetailerEarningsSummaryModel({
    super.today,
    super.thisWeek,
    super.thisMonth,
    super.lifetime,
  });

  factory RetailerEarningsSummaryModel.fromJson(Map<String, dynamic> json) {
    return RetailerEarningsSummaryModel(
      today: json['today'] is Map
          ? RetailerEarningsPeriodModel.fromJson(Map<String, dynamic>.from(json['today']))
          : const RetailerEarningsPeriodEntity(),
      thisWeek: json['thisWeek'] is Map
          ? RetailerEarningsPeriodModel.fromJson(Map<String, dynamic>.from(json['thisWeek']))
          : const RetailerEarningsPeriodEntity(),
      thisMonth: json['thisMonth'] is Map
          ? RetailerEarningsPeriodModel.fromJson(Map<String, dynamic>.from(json['thisMonth']))
          : const RetailerEarningsPeriodEntity(),
      lifetime: json['lifetime'] is Map
          ? RetailerEarningsPeriodModel.fromJson(Map<String, dynamic>.from(json['lifetime']))
          : const RetailerEarningsPeriodEntity(),
    );
  }
}

class RetailerEarningModel extends RetailerEarningEntity {
  const RetailerEarningModel({
    required super.id,
    required super.orderId,
    super.orderNumber,
    required super.subtotal,
    required super.platformFee,
    required super.netPayout,
    super.status,
    required super.createdAt,
  });

  factory RetailerEarningModel.fromJson(Map<String, dynamic> json) {
    final sub = (json['subtotal'] as num?)?.toDouble() ?? 0.0;
    final fee = (json['platformFee'] as num?)?.toDouble() ?? 0.0;
    final net = (json['netPayout'] as num?)?.toDouble() ?? (sub - fee);

    return RetailerEarningModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      orderId: (json['orderId'] is Map
              ? (json['orderId']['_id'] ?? json['orderId']['id'])
              : json['orderId'])
          ?.toString() ??
          '',
      orderNumber: (json['orderNumber'] ??
              (json['orderId'] is Map ? json['orderId']['orderNumber'] : null))
          ?.toString() ??
          '',
      subtotal: sub,
      platformFee: fee,
      netPayout: net,
      status: json['status']?.toString().toUpperCase() ?? 'AVAILABLE',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

class RetailerSettlementModel extends RetailerSettlementEntity {
  const RetailerSettlementModel({
    required super.id,
    super.periodStart,
    super.periodEnd,
    required super.amount,
    required super.status,
    super.paymentReference,
    super.notes,
    required super.createdAt,
  });

  factory RetailerSettlementModel.fromJson(Map<String, dynamic> json) {
    return RetailerSettlementModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      periodStart: json['periodStart'] != null ? DateTime.tryParse(json['periodStart'].toString()) : null,
      periodEnd: json['periodEnd'] != null ? DateTime.tryParse(json['periodEnd'].toString()) : null,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      paymentReference: json['paymentReference']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
