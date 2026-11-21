import '../../domain/entities/coupon_entity.dart';

class CouponModel extends CouponEntity {
  const CouponModel({
    required super.code,
    required super.label,
    required super.minOrder,
    super.description,
    super.type,
    super.value,
    super.maxDiscount,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? json['description']?.toString() ?? json['code']?.toString() ?? 'Offer',
      minOrder: (json['minOrder'] as num?)?.toDouble() ??
          (json['minOrderAmount'] as num?)?.toDouble() ??
          (json['minOrderValue'] as num?)?.toDouble() ??
          0.0,
      description: json['description']?.toString(),
      type: json['discountType']?.toString() ?? json['type']?.toString(),
      value: (json['discountValue'] as num?)?.toDouble() ?? (json['value'] as num?)?.toDouble(),
      maxDiscount: (json['maxDiscount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'label': label,
      'minOrder': minOrder,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      if (value != null) 'value': value,
      if (maxDiscount != null) 'maxDiscount': maxDiscount,
    };
  }
}

class CouponValidationModel extends CouponValidationEntity {
  const CouponValidationModel({
    required super.code,
    required super.label,
    required super.discount,
    required super.freeDelivery,
    required super.minOrder,
    super.maxDiscount,
    super.isValid = true,
    super.errorMessage,
    super.errorCode,
  });

  static String mapReasonToCustomerMessage(String? reason, {String? defaultMsg}) {
    switch (reason?.toUpperCase().trim()) {
      case 'MIN_ORDER_NOT_MET':
        return 'Add more items to use this coupon';
      case 'EXPIRED':
        return 'This coupon has expired';
      case 'INVALID_CODE':
        return 'Invalid coupon code';
      case 'NOT_APPLICABLE_TO_RETAILER':
        return 'Coupon does not apply to this shop';
      case 'USAGE_LIMIT_REACHED':
        return 'Coupon is no longer available';
      case 'ALREADY_USED':
        return 'You have already used this coupon';
      default:
        return defaultMsg ?? 'Coupon cannot be applied';
    }
  }

  factory CouponValidationModel.fromJson(Map<String, dynamic> json, {String defaultCode = ''}) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json);

    final bool explicitValid = data['valid'] == true;
    final String? reason = data['reason']?.toString();

    // If backend explicitly returned valid: false
    if (data.containsKey('valid') && !explicitValid) {
      final code = defaultCode.isNotEmpty
          ? defaultCode
          : (data['code']?.toString() ?? '');
      return CouponValidationModel.fromError(
        code: code,
        errorMessage: mapReasonToCustomerMessage(reason, defaultMsg: data['message']?.toString()),
        errorCode: reason,
      );
    }

    final couponMeta = data['coupon'] is Map ? Map<String, dynamic>.from(data['coupon'] as Map) : null;
    final code = couponMeta?['code']?.toString() ??
        data['code']?.toString() ??
        defaultCode;
    final label = couponMeta?['description']?.toString() ??
        data['label']?.toString() ??
        code;
    final discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
    final freeDelivery = data['freeDelivery'] == true || couponMeta?['freeDelivery'] == true;
    final minOrder = (couponMeta?['minOrderAmount'] as num?)?.toDouble() ??
        (couponMeta?['minOrder'] as num?)?.toDouble() ??
        (data['minOrder'] as num?)?.toDouble() ??
        (data['minOrderValue'] as num?)?.toDouble() ??
        0.0;
    final maxDiscount = (couponMeta?['maxDiscount'] as num?)?.toDouble() ??
        (data['maxDiscount'] as num?)?.toDouble();

    return CouponValidationModel(
      code: code,
      label: label,
      discount: discount,
      freeDelivery: freeDelivery,
      minOrder: minOrder,
      maxDiscount: maxDiscount,
      isValid: true,
    );
  }

  factory CouponValidationModel.fromError({
    required String code,
    required String errorMessage,
    String? errorCode,
  }) {
    return CouponValidationModel(
      code: code,
      label: '',
      discount: 0.0,
      freeDelivery: false,
      minOrder: 0.0,
      isValid: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'label': label,
      'discount': discount,
      'freeDelivery': freeDelivery,
      'minOrder': minOrder,
      if (maxDiscount != null) 'maxDiscount': maxDiscount,
      'isValid': isValid,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (errorCode != null) 'errorCode': errorCode,
    };
  }
}
