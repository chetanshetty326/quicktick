import 'package:equatable/equatable.dart';

/// Clean Architecture Entity representing an available promotional offer / coupon.
class CouponEntity extends Equatable {
  final String code;
  final String label;
  final double minOrder;
  final String? description;
  final String? type; // PERCENTAGE, FIXED, FREE_DELIVERY
  final double? value;
  final double? maxDiscount;

  const CouponEntity({
    required this.code,
    required this.label,
    required this.minOrder,
    this.description,
    this.type,
    this.value,
    this.maxDiscount,
  });

  @override
  List<Object?> get props => [code, label, minOrder, description, type, value, maxDiscount];
}

/// Clean Architecture Entity representing the result of validating a coupon.
class CouponValidationEntity extends Equatable {
  final String code;
  final String label;
  final double discount;
  final bool freeDelivery;
  final double minOrder;
  final double? maxDiscount;
  final bool isValid;
  final String? errorMessage;
  final String? errorCode;

  const CouponValidationEntity({
    required this.code,
    required this.label,
    required this.discount,
    required this.freeDelivery,
    required this.minOrder,
    this.maxDiscount,
    this.isValid = true,
    this.errorMessage,
    this.errorCode,
  });

  @override
  List<Object?> get props => [
        code,
        label,
        discount,
        freeDelivery,
        minOrder,
        maxDiscount,
        isValid,
        errorMessage,
        errorCode,
      ];
}
