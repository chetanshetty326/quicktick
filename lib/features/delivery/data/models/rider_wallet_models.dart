import '../../domain/entities/rider_wallet_entities.dart';

class RiderBankAccountModel extends RiderBankAccountEntity {
  const RiderBankAccountModel({
    required super.id,
    required super.type,
    super.accountHolderName,
    super.accountNumber,
    super.ifscCode,
    super.bankName,
    super.upiVpa,
    super.isDefault,
    super.verified,
    super.isActive,
    super.createdAt,
  });

  factory RiderBankAccountModel.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type']?.toString().toUpperCase()) ?? 'BANK';
    final type = typeStr == 'UPI' ? BankAccountType.upi : BankAccountType.bank;

    return RiderBankAccountModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      type: type,
      accountHolderName: json['accountHolderName']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      ifscCode: json['ifscCode']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      upiVpa: json['upiVpa']?.toString() ?? '',
      isDefault: json['isDefault'] == true,
      verified: json['verified'] == true,
      isActive: json['isActive'] != false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    if (type == BankAccountType.upi) {
      return {
        'type': 'UPI',
        'upiVpa': upiVpa,
        'isDefault': isDefault,
      };
    }
    return {
      'type': 'BANK',
      'accountHolderName': accountHolderName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'bankName': bankName,
      'isDefault': isDefault,
    };
  }
}

class RiderWithdrawalModel extends RiderWithdrawalEntity {
  const RiderWithdrawalModel({
    required super.id,
    required super.amount,
    required super.bankAccountId,
    required super.status,
    super.notes,
    super.paymentReference,
    super.reason,
    required super.createdAt,
    super.bankAccount,
  });

  factory RiderWithdrawalModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString().toUpperCase() ?? 'PENDING';
    WithdrawalStatus status;
    switch (statusStr) {
      case 'APPROVED':
        status = WithdrawalStatus.approved;
        break;
      case 'PAID':
        status = WithdrawalStatus.paid;
        break;
      case 'REJECTED':
        status = WithdrawalStatus.rejected;
        break;
      case 'FAILED':
        status = WithdrawalStatus.failed;
        break;
      case 'CANCELLED':
        status = WithdrawalStatus.cancelled;
        break;
      default:
        status = WithdrawalStatus.pending;
    }

    RiderBankAccountModel? bAccount;
    if (json['bankAccount'] is Map) {
      bAccount = RiderBankAccountModel.fromJson(Map<String, dynamic>.from(json['bankAccount']));
    }

    return RiderWithdrawalModel(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      bankAccountId: (json['bankAccountId'] is Map
              ? (json['bankAccountId']['_id'] ?? json['bankAccountId']['id'])
              : json['bankAccountId'])
          ?.toString() ??
          '',
      status: status,
      notes: json['notes']?.toString() ?? '',
      paymentReference: json['paymentReference']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      bankAccount: bAccount,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'bankAccountId': bankAccountId,
        if (notes.isNotEmpty) 'notes': notes,
      };
}
