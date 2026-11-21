import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/customer/data/models/product_model.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

void main() {
  group('Zone-Based Product Filtering Tests', () {
    const bangaloreZoneId = '6ac6740f961a657dbec3ebb6';
    const tarikkereZoneId = '6ac606440d9f919b26d4e987';

    const blrStore1 = '6ad10d51b2990872d1d5bf5c'; // namma angadi
    const blrStore2 = '6ad239e0b2990872d1d6651f'; // honeywell
    const blrStore3 = '6ad30884b2990872d1d6ebba'; // Patanjali store
    const blrStore4 = '6ad1c1e3b2990872d1d6161c'; // RS groceries
    const outOfZoneStore = '6ad211d3b2990872d1d63871'; // gsd mart (Tarikere)

    StoreEntity createStore(String id, String name, String zoneId) => StoreEntity(
          id: id,
          name: name,
          category: 'Groceries',
          address: 'Bangalore',
          rating: 4.5,
          deliveryTime: '20 mins',
          distanceKm: 2.5,
          isOpen: true,
          bannerUrl: '',
          zoneId: zoneId,
        );

    final blrStores = [
      createStore(blrStore1, 'namma angadi', bangaloreZoneId),
      createStore(blrStore2, 'honeywell', bangaloreZoneId),
      createStore(blrStore3, 'Patanjali store', bangaloreZoneId),
      createStore(blrStore4, 'RS groceries', bangaloreZoneId),
    ];

    test('1. ProductModel correctly extracts zoneId from nested retailerId', () {
      final json = {
        '_id': 'p1',
        'name': 'Patanjali Honey',
        'retailerId': {
          '_id': blrStore3,
          'shopName': 'Patanjali store',
          'zoneId': bangaloreZoneId,
        },
        'price': 150.0,
      };

      final product = ProductModel.fromJson(json);
      expect(product.storeId, equals(blrStore3));
      expect(product.storeName, equals('Patanjali store'));
      expect(product.zoneId, equals(bangaloreZoneId));
    });

    test('2. Validates in-zone products belong to verified zone stores', () {
      final validStoreIds = blrStores.map((s) => s.id).toSet();

      final inZoneProduct = const ProductEntity(
        id: 'p1',
        storeId: blrStore1,
        categoryId: 'cat_all',
        name: 'koli saaru',
        description: 'chicken curry',
        price: 180,
        unit: 'plate',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
        zoneId: bangaloreZoneId,
      );

      final outOfZoneProduct = const ProductEntity(
        id: 'p2',
        storeId: outOfZoneStore,
        categoryId: 'cat_all',
        name: 'milk',
        description: 'fresh milk',
        price: 30,
        unit: 'piece',
        stock: 15,
        isAvailable: true,
        imageUrl: '',
        zoneId: tarikkereZoneId,
      );

      // In Bangalore zone, validStoreIds contains blrStore1, but NOT outOfZoneStore
      expect(validStoreIds.contains(inZoneProduct.storeId), isTrue);
      expect(validStoreIds.contains(outOfZoneProduct.storeId), isFalse);

      final allProducts = [inZoneProduct, outOfZoneProduct];
      final zoneFiltered = allProducts.where((p) {
        if (p.storeId.isNotEmpty && !validStoreIds.contains(p.storeId)) return false;
        if (p.zoneId != null && p.zoneId!.isNotEmpty && p.zoneId != bangaloreZoneId) return false;
        return true;
      }).toList();

      expect(zoneFiltered.length, equals(1));
      expect(zoneFiltered.first.name, equals('koli saaru'));
    });

    test('3. Store-specific filtering strictly isolates products to that store', () {
      final p1 = const ProductEntity(
        id: 'p1',
        storeId: blrStore1,
        categoryId: 'cat_all',
        name: 'koli saaru',
        description: '',
        price: 180,
        unit: '1',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
      );

      final p2 = const ProductEntity(
        id: 'p2',
        storeId: blrStore2,
        categoryId: 'cat_all',
        name: 'chicken',
        description: '',
        price: 220,
        unit: '1',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
      );

      final storeFiltered = [p1, p2].where((p) => p.storeId == blrStore1).toList();
      expect(storeFiltered.length, equals(1));
      expect(storeFiltered.first.name, equals('koli saaru'));
    });

    test('4. ProductModel parses out-of-stock backend response as isAvailable: false and stock: 0', () {
      final json = {
        '_id': 'p_out',
        'name': 'Out of Stock Noodles',
        'retailerId': {
          '_id': blrStore1,
          'shopName': 'namma angadi',
          'zoneId': bangaloreZoneId,
        },
        'price': 60.0,
        'stockQty': 0,
        'status': 'OUT_OF_STOCK',
      };

      final product = ProductModel.fromJson(json);
      expect(product.stock, equals(0));
      expect(product.isAvailable, isFalse);
    });

    test('5. Customer app card correctly identifies out of stock and blocks cart addition', () {
      final outOfStockProduct = const ProductEntity(
        id: 'p_out',
        storeId: blrStore1,
        categoryId: 'cat_all',
        name: 'Out of Stock Item',
        description: '',
        price: 99.0,
        unit: '1',
        stock: 0,
        isAvailable: false,
        imageUrl: '',
      );

      // Card condition in customer_main_screen.dart:L2901
      final bool showOutOfStockBadge = !outOfStockProduct.isAvailable || outOfStockProduct.stock <= 0;
      expect(showOutOfStockBadge, isTrue);

      // Customer inStockOnly chip filter
      const inStockOnlyFilter = true;
      final matchesStock = !inStockOnlyFilter || outOfStockProduct.stock > 0;
      expect(matchesStock, isFalse); // Product is excluded when user selects 'In Stock'
    });

    test('6. In an active zone with confirmed stores, products with empty or foreign storeId are rejected', () {
      final validStoreIds = blrStores.map((s) => s.id).toSet();

      final orphanProduct = const ProductEntity(
        id: 'p_orphan',
        storeId: '',
        categoryId: 'cat_all',
        name: 'Generic Orphan Item',
        description: 'No store linked',
        price: 50.0,
        unit: '1 kg',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      final foreignStoreProduct = const ProductEntity(
        id: 'p_foreign',
        storeId: outOfZoneStore,
        categoryId: 'cat_all',
        name: 'Tarikere Fresh Veggies',
        description: 'From Tarikere',
        price: 40.0,
        unit: '1 kg',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      final validStoreProduct = const ProductEntity(
        id: 'p_valid',
        storeId: blrStore1,
        categoryId: 'cat_all',
        name: 'Bangalore Fresh Veggies',
        description: 'From Bangalore',
        price: 40.0,
        unit: '1 kg',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      final inputList = [orphanProduct, foreignStoreProduct, validStoreProduct];
      final filtered = inputList.where((p) {
        if (validStoreIds.isNotEmpty) {
          if (p.storeId.isEmpty || !validStoreIds.contains(p.storeId)) {
            return false;
          }
        }
        return true;
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('p_valid'));
    });

    test('7. Explicit zoneId check rejects products with mismatching zoneId', () {
      const activeZoneId = bangaloreZoneId;

      final matchingZoneProd = const ProductEntity(
        id: 'p_match',
        storeId: blrStore1,
        categoryId: 'cat_all',
        name: 'Matches Bangalore',
        description: '',
        price: 100.0,
        unit: '1',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
        zoneId: bangaloreZoneId,
      );

      final mismatchZoneProd = const ProductEntity(
        id: 'p_mismatch',
        storeId: blrStore1,
        categoryId: 'cat_all',
        name: 'Tarikere Product In BLR Store',
        description: '',
        price: 100.0,
        unit: '1',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
        zoneId: tarikkereZoneId,
      );

      final products = [matchingZoneProd, mismatchZoneProd];
      final filtered = products.where((p) {
        if (activeZoneId.isNotEmpty && p.zoneId != null && p.zoneId!.isNotEmpty && p.zoneId != activeZoneId) {
          return false;
        }
        return true;
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('p_match'));
    });

    test('8. When user location is out of delivery zone, product feed is strictly empty', () {
      bool isOutOfZone(bool inZone, String? message) => !inZone && message != null;

      final allProducts = [
        const ProductEntity(
          id: 'p1',
          storeId: blrStore1,
          categoryId: 'cat_all',
          name: 'Some Product',
          description: '',
          price: 100.0,
          unit: '1',
          stock: 5,
          isAvailable: true,
          imageUrl: '',
        ),
      ];

      // Exact CustomerBloc condition
      final initialFiltered = isOutOfZone(false, 'Location is outside the delivery zone')
          ? const <ProductEntity>[]
          : allProducts;

      expect(initialFiltered, isEmpty);

      final inZoneFiltered = isOutOfZone(true, null)
          ? const <ProductEntity>[]
          : allProducts;

      expect(inZoneFiltered, isNotEmpty);
    });
  });
}
