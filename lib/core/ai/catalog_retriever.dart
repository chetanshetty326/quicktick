import '../../features/customer/domain/entities/cart_item_entity.dart';
import '../../features/customer/domain/entities/catalog_entities.dart';

class CatalogRetriever {
  const CatalogRetriever();

  /// Retrieves relevant candidate products from the active store catalog
  /// that can serve as substitutes for the items currently in the cart.
  List<ProductEntity> retrieveCandidates({
    required List<CartItemEntity> cartItems,
    required List<ProductEntity> storeCatalog,
    String? targetCategory,
  }) {
    if (cartItems.isEmpty || storeCatalog.isEmpty) return const [];

    final cartProductIds = cartItems.map((c) => c.productId).toSet();
    final cartCategoryIds = cartItems
        .map((c) => c.product.categoryId)
        .where((id) => id.isNotEmpty)
        .toSet();

    return storeCatalog.where((product) {
      // Must be available and in-stock
      if (!product.isAvailable || product.stock <= 0) return false;
      // Must not already be in the cart
      if (cartProductIds.contains(product.id)) return false;

      // Filter by category relevance
      if (targetCategory != null && targetCategory.isNotEmpty) {
        return product.categoryId == targetCategory;
      }
      return cartCategoryIds.contains(product.categoryId);
    }).toList();
  }

  /// Extracts standard measurement quantity (e.g. "500g" -> 500, "1 L" -> 1000, "1 kg" -> 1000)
  static double parseUnitWeightInGramsOrMl(String unit) {
    final lower = unit.toLowerCase().trim();
    final numMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    if (numMatch == null) return 1.0;

    final val = double.tryParse(numMatch.group(1)!) ?? 1.0;
    if (lower.contains('ml')) {
      return val;
    }
    if (lower.contains('kg') ||
        lower.contains('litre') ||
        lower.contains('liter') ||
        lower.endsWith(' l') ||
        (lower.endsWith('l') && !lower.endsWith('ml'))) {
      return val * 1000.0;
    }
    return val;
  }
}
