import 'package:equatable/equatable.dart';
import 'catalog_entities.dart';

class CartItemEntity extends Equatable {
  final ProductEntity product;
  final int quantity;

  const CartItemEntity({
    required this.product,
    required this.quantity,
  });

  double get total => product.price * quantity;
  String get productId => product.id;

  CartItemEntity copyWith({
    ProductEntity? product,
    int? quantity,
  }) {
    return CartItemEntity(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'product': {
          'id': product.id,
          'storeId': product.storeId,
          'categoryId': product.categoryId,
          'name': product.name,
          'description': product.description,
          'price': product.price,
          'originalPrice': product.originalPrice,
          'unit': product.unit,
          'stock': product.stock,
          'isAvailable': product.isAvailable,
          'imageUrl': product.imageUrl,
        },
        'quantity': quantity,
      };

  factory CartItemEntity.fromJson(Map<String, dynamic> json) {
    final pJson = Map<String, dynamic>.from(json['product']);
    return CartItemEntity(
      product: ProductEntity(
        id: pJson['id'] ?? '',
        storeId: pJson['storeId'] ?? '',
        categoryId: pJson['categoryId'] ?? '',
        name: pJson['name'] ?? '',
        description: pJson['description'] ?? '',
        price: (pJson['price'] as num?)?.toDouble() ?? 0.0,
        originalPrice: (pJson['originalPrice'] as num?)?.toDouble(),
        unit: pJson['unit'] ?? '',
        stock: pJson['stock'] ?? 0,
        isAvailable: pJson['isAvailable'] ?? true,
        imageUrl: pJson['imageUrl'] ?? '',
      ),
      quantity: json['quantity'] ?? 1,
    );
  }

  @override
  List<Object?> get props => [product, quantity];
}
