import 'package:equatable/equatable.dart';

enum BankAccountType { bank, upi }

class RiderBankAccountEntity extends Equatable {
  final String id;
  final BankAccountType type;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String upiVpa;
  final bool isDefault;
  final bool verified;
  final bool isActive;
  final DateTime? createdAt;

  const RiderBankAccountEntity({
    required this.id,
    required this.type,
    this.accountHolderName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.bankName = '',
    this.upiVpa = '',
    this.isDefault = false,
    this.verified = false,
    this.isActive = true,
    this.createdAt,
  });

  String get displayTitle {
    if (type == BankAccountType.upi) {
      return upiVpa.isNotEmpty ? upiVpa : 'UPI Account';
    }
    final masked = accountNumber.length > 4
        ? '•••• ${accountNumber.substring(accountNumber.length - 4)}'
        : accountNumber;
    return bankName.isNotEmpty ? '$bankName ($masked)' : 'Bank ($masked)';
  }

  String get displaySubtitle {
    if (type == BankAccountType.upi) {
      return 'UPI VPA • ${verified ? "Verified" : "Pending Verification"}';
    }
    return '${accountHolderName.isNotEmpty ? accountHolderName : "Bank Account"} • IFSC: $ifscCode';
  }

  @override
  List<Object?> get props => [
        id,
        type,
        accountHolderName,
        accountNumber,
        ifscCode,
        bankName,
        upiVpa,
        isDefault,
        verified,
        isActive,
        createdAt,
      ];
}

enum WithdrawalStatus {
  pending,
  approved,
  paid,
  rejected,
  failed,
  cancelled;

  String get label {
    switch (this) {
      case WithdrawalStatus.pending:
        return 'Pending Review';
      case WithdrawalStatus.approved:
        return 'Approved';
      case WithdrawalStatus.paid:
        return 'Paid / Settled';
      case WithdrawalStatus.rejected:
        return 'Rejected';
      case WithdrawalStatus.failed:
        return 'Failed';
      case WithdrawalStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isTerminal =>
      this == WithdrawalStatus.paid ||
      this == WithdrawalStatus.rejected ||
      this == WithdrawalStatus.failed ||
      this == WithdrawalStatus.cancelled;
}

class RiderWithdrawalEntity extends Equatable {
  final String id;
  final double amount;
  final String bankAccountId;
  final WithdrawalStatus status;
  final String notes;
  final String paymentReference;
  final String reason;
  final DateTime createdAt;
  final RiderBankAccountEntity? bankAccount;

  const RiderWithdrawalEntity({
    required this.id,
    required this.amount,
    required this.bankAccountId,
    required this.status,
    this.notes = '',
    this.paymentReference = '',
    this.reason = '',
    required this.createdAt,
    this.bankAccount,
  });

  @override
  List<Object?> get props => [
        id,
        amount,
        bankAccountId,
        status,
        notes,
        paymentReference,
        reason,
        createdAt,
        bankAccount,
      ];
}
