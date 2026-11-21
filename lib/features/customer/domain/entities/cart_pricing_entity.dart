import 'package:equatable/equatable.dart';

class TaxBreakdownEntity extends Equatable {
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  const TaxBreakdownEntity({
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    this.total = 0.0,
  });

  bool get hasBreakdown => cgst > 0 || sgst > 0 || igst > 0;

  factory TaxBreakdownEntity.fromJson(Map<String, dynamic> json) {
    final cgst = (json['cgst'] as num?)?.toDouble() ?? 0.0;
    final sgst = (json['sgst'] as num?)?.toDouble() ?? 0.0;
    final igst = (json['igst'] as num?)?.toDouble() ?? 0.0;
    final rawTotal = (json['total'] as num?)?.toDouble();
    return TaxBreakdownEntity(
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      total: (rawTotal != null && rawTotal > 0) ? rawTotal : (cgst + sgst + igst),
    );
  }

  Map<String, dynamic> toJson() => {
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'total': total,
      };

  @override
  List<Object?> get props => [cgst, sgst, igst, total];
}

class CartPricingEntity extends Equatable {
  final String cartId;
  final double subtotal;
  final double deliveryFee;
  final double platformFee;
  final double discount;
  final double tip;
  final double tax;
  final TaxBreakdownEntity taxBreakdown;
  final double total;
  final double freeDeliveryThreshold;
  final double minOrderAmount;
  final String? retailerId;

  const CartPricingEntity({
    this.cartId = '',
    required this.subtotal,
    required this.deliveryFee,
    required this.platformFee,
    this.discount = 0.0,
    this.tip = 0.0,
    this.tax = 0.0,
    this.taxBreakdown = const TaxBreakdownEntity(),
    required this.total,
    this.freeDeliveryThreshold = 0.0,
    this.minOrderAmount = 0.0,
    this.retailerId,
  });

  bool get isFreeDelivery => deliveryFee == 0.0;

  CartPricingEntity copyWith({
    String? cartId,
    double? subtotal,
    double? deliveryFee,
    double? platformFee,
    double? discount,
    double? tip,
    double? tax,
    TaxBreakdownEntity? taxBreakdown,
    double? total,
    double? freeDeliveryThreshold,
    double? minOrderAmount,
    String? retailerId,
  }) {
    return CartPricingEntity(
      cartId: cartId ?? this.cartId,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      platformFee: platformFee ?? this.platformFee,
      discount: discount ?? this.discount,
      tip: tip ?? this.tip,
      tax: tax ?? this.tax,
      taxBreakdown: taxBreakdown ?? this.taxBreakdown,
      total: total ?? this.total,
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      retailerId: retailerId ?? this.retailerId,
    );
  }

  @override
  List<Object?> get props => [
        cartId,
        subtotal,
        deliveryFee,
        platformFee,
        discount,
        tip,
        tax,
        taxBreakdown,
        total,
        freeDeliveryThreshold,
        minOrderAmount,
        retailerId,
      ];
}
