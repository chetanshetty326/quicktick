import '../../domain/entities/cart_pricing_entity.dart';

class CartPricingModel extends CartPricingEntity {
  const CartPricingModel({
    super.cartId,
    required super.subtotal,
    required super.deliveryFee,
    required super.platformFee,
    super.discount,
    super.tip,
    super.tax,
    super.taxBreakdown,
    required super.total,
    super.freeDeliveryThreshold,
    super.minOrderAmount,
    super.retailerId,
  });

  factory CartPricingModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json);

    final taxBreakdownMap = data['taxBreakdown'] is Map
        ? Map<String, dynamic>.from(data['taxBreakdown'] as Map)
        : <String, dynamic>{};

    return CartPricingModel(
      cartId: data['_id']?.toString() ?? data['id']?.toString() ?? data['cartId']?.toString() ?? '',
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      tip: (data['tip'] as num?)?.toDouble() ?? 0.0,
      tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
      taxBreakdown: TaxBreakdownEntity.fromJson(taxBreakdownMap),
      total: (data['total'] as num?)?.toDouble() ??
          (data['grandTotal'] as num?)?.toDouble() ??
          0.0,
      freeDeliveryThreshold: (data['freeDeliveryThreshold'] as num?)?.toDouble() ?? 0.0,
      minOrderAmount: (data['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
      retailerId: data['retailerId'] is Map
          ? (data['retailerId']['_id'] ?? data['retailerId']['id'])?.toString()
          : data['retailerId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': cartId,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'platformFee': platformFee,
        'discount': discount,
        'tip': tip,
        'tax': tax,
        'taxBreakdown': taxBreakdown.toJson(),
        'total': total,
        'freeDeliveryThreshold': freeDeliveryThreshold,
        'minOrderAmount': minOrderAmount,
        if (retailerId != null) 'retailerId': retailerId,
      };
}
