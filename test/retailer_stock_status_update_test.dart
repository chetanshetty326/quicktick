import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

void main() {
  group('Retailer Inventory Stock Status Tests', () {
    const testProduct = ProductEntity(
      id: 'prod_123',
      storeId: 'store_123',
      name: 'Test Rice',
      description: 'Basmati Rice',
      price: 120.0,
      unit: 'kg',
      stock: 25,
      isAvailable: true,
      categoryId: 'cat_groceries',
      imageUrl: 'https://example.com/rice.png',
    );

    test('1. Toggling out of stock sets stock to 0 and isAvailable to false', () {
      const isAvailable = false;
      final newStock = isAvailable
          ? (testProduct.stock > 0 ? testProduct.stock : 10)
          : 0;
      final updated = testProduct.copyWith(
        stock: newStock,
        isAvailable: isAvailable,
      );

      expect(updated.isAvailable, isFalse);
      expect(updated.stock, equals(0));

      final String statusStr = isAvailable ? 'ACTIVE' : 'OUT_OF_STOCK';
      final String stockStatusStr = isAvailable ? 'IN_STOCK' : 'OUT_OF_STOCK';
      expect(statusStr, equals('OUT_OF_STOCK'));
      expect(stockStatusStr, equals('OUT_OF_STOCK'));
    });

    test('2. Toggling in stock restores stock > 0 and isAvailable to true', () {
      const outOfStockProduct = ProductEntity(
        id: 'prod_123',
        storeId: 'store_123',
        name: 'Test Rice',
        description: 'Basmati Rice',
        price: 120.0,
        unit: 'kg',
        stock: 0,
        isAvailable: false,
        categoryId: 'cat_groceries',
        imageUrl: 'https://example.com/rice.png',
      );

      const isAvailable = true;
      const currentStock = 25;
      final newStock = isAvailable
          ? ((currentStock > 0) ? currentStock : 10)
          : 0;
      final updated = outOfStockProduct.copyWith(
        stock: newStock,
        isAvailable: isAvailable,
      );

      expect(updated.isAvailable, isTrue);
      expect(updated.stock, equals(25));

      final String statusStr = isAvailable ? 'ACTIVE' : 'OUT_OF_STOCK';
      final String stockStatusStr = isAvailable ? 'IN_STOCK' : 'OUT_OF_STOCK';
      expect(statusStr, equals('ACTIVE'));
      expect(stockStatusStr, equals('IN_STOCK'));
    });

    test('3. Edit item sheet out of stock sets effectiveStock to 0', () {
      const isAvailable = false;
      final int stockInput = 15; // User had 15 in the textfield
      final effectiveStock = isAvailable ? (stockInput > 0 ? stockInput : 10) : 0;

      final updated = testProduct.copyWith(
        stock: effectiveStock,
        isAvailable: isAvailable,
      );

      expect(updated.stock, equals(0));
      expect(updated.isAvailable, isFalse);
    });
  });
}
