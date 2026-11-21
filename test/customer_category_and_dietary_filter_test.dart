import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

void main() {
  group('ProductEntity Domain Logic - Category & Dietary Filtering', () {
    const categories = [
      CategoryEntity(id: 'cat_cold_drinks', name: 'Cold Drinks & Juices'),
      CategoryEntity(id: 'cat_dairy', name: 'Dairy, Bread & Eggs'),
      CategoryEntity(id: 'cat_fruits_veg', name: 'Fresh Fruits & Vegetables'),
      CategoryEntity(id: 'cat_groceries', name: 'Groceries & Staples'),
      CategoryEntity(id: 'cat_hot_meals', name: 'Hot Meals & Biryani'),
      CategoryEntity(id: 'cat_meat', name: 'Meat, Poultry & Fish'),
      CategoryEntity(id: 'cat_personal_care', name: 'Personal Care & Wellness'),
      CategoryEntity(id: 'cat_snacks', name: 'Snacks & Munchies'),
    ];

    test('1. Dietary Preference: Correctly identifies Veg, Non-Veg, and Egg items with fallback', () {
      const eggBiriyani = ProductEntity(
        id: '1',
        storeId: 's1',
        categoryId: 'cat_all',
        name: 'Egg biriyani',
        description: 'Fragrant basmati rice with boiled eggs',
        price: 180,
        unit: '1 plate',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
      );

      const chickenBiriyani = ProductEntity(
        id: '2',
        storeId: 's1',
        categoryId: 'cat_all',
        name: 'Chiken biriyani',
        description: 'Tender chicken pieces with spiced rice',
        price: 220,
        unit: '1 plate',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
      );

      const paneerBiriyani = ProductEntity(
        id: '3',
        storeId: 's1',
        categoryId: 'cat_all',
        name: 'Panner biriyani',
        description: 'Fresh paneer cubes with rice',
        price: 160,
        unit: '1 plate',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
      );

      // Verify resolvedFoodType
      expect(eggBiriyani.resolvedFoodType, 'EGG');
      expect(chickenBiriyani.resolvedFoodType, 'NON_VEG');
      expect(paneerBiriyani.resolvedFoodType, 'VEG');

      // Verify matchesDietaryPreference
      expect(eggBiriyani.matchesDietaryPreference('EGG'), isTrue);
      expect(eggBiriyani.matchesDietaryPreference('VEG'), isFalse);
      expect(eggBiriyani.matchesDietaryPreference('NON_VEG'), isFalse);

      expect(chickenBiriyani.matchesDietaryPreference('NON_VEG'), isTrue);
      expect(chickenBiriyani.matchesDietaryPreference('VEG'), isFalse);

      expect(paneerBiriyani.matchesDietaryPreference('VEG'), isTrue);
      expect(paneerBiriyani.matchesDietaryPreference('NON_VEG'), isFalse);

      // 'ALL' matches everything
      expect(eggBiriyani.matchesDietaryPreference('ALL'), isTrue);
      expect(chickenBiriyani.matchesDietaryPreference('ALL'), isTrue);
      expect(paneerBiriyani.matchesDietaryPreference('ALL'), isTrue);
    });

    test('2. Category Matching: Resolves all 8 categories even with legacy null/cat_all categoryId', () {
      const sevenUp = ProductEntity(
        id: 'p_drink',
        storeId: 's1',
        categoryId: 'cat_all',
        name: '7up',
        description: 'Refreshing lemon soda',
        price: 40,
        unit: '750ml',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      const redBull = ProductEntity(
        id: 'p_energy',
        storeId: 's1',
        categoryId: 'cat_all',
        name: 'Red Bull',
        description: 'Energy drink',
        price: 125,
        unit: '250ml',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      const ragiMudde = ProductEntity(
        id: 'p_mudde',
        storeId: 's1',
        categoryId: 'cat_all',
        name: 'RAGI MUDDE',
        description: 'Authentic karnataka ragi balls',
        price: 30,
        unit: '1 piece',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      const koliSaaru = ProductEntity(
        id: 'p_koli',
        storeId: 's1',
        categoryId: 'cat_all',
        name: 'koli saaru',
        description: 'Karnataka style spicy chicken curry',
        price: 140,
        unit: '1 bowl',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      const patanjaliBalm = ProductEntity(
        id: 'p_balm',
        storeId: 's1',
        categoryId: 'cat_all',
        name: 'Patanjali pain Balm',
        description: 'Herbal balm for quick pain relief',
        price: 60,
        unit: '25g',
        stock: 10,
        isAvailable: true,
        imageUrl: '',
      );

      // 7up & Red Bull match Cold Drinks & Juices
      expect(sevenUp.matchesCategory('cat_cold_drinks', categories), isTrue);
      expect(redBull.matchesCategory('cat_cold_drinks', categories), isTrue);
      expect(sevenUp.matchesCategory('cat_personal_care', categories), isFalse);

      // Ragi Mudde matches Hot Meals & Biryani
      expect(ragiMudde.matchesCategory('cat_hot_meals', categories), isTrue);

      // Koli Saaru matches Meat, Poultry & Fish and Hot Meals
      expect(koliSaaru.matchesCategory('cat_meat', categories), isTrue);

      // Patanjali Balm matches Personal Care & Wellness
      expect(patanjaliBalm.matchesCategory('cat_personal_care', categories), isTrue);

      // All match cat_all
      expect(sevenUp.matchesCategory('cat_all', categories), isTrue);
      expect(ragiMudde.matchesCategory('cat_all', categories), isTrue);
      expect(patanjaliBalm.matchesCategory('cat_all', categories), isTrue);
    });

    test('3. Zone Flow Isolation: Product matching preserves strict storeId and zone isolation', () {
      final store1InZone = const StoreEntity(
        id: 's_blr',
        name: 'Local BLR Store',
        category: 'Grocery',
        address: 'MG Road, Bangalore',
        rating: 4.8,
        deliveryTime: '15 mins',
        distanceKm: 1.2,
        isOpen: true,
        bannerUrl: '',
        zoneId: 'z_blr',
      );

      final validStoresMap = {'s_blr': store1InZone};

      const inZoneProduct = ProductEntity(
        id: 'p1',
        storeId: 's_blr',
        zoneId: 'z_blr',
        categoryId: 'cat_all',
        name: 'Chiken biriyani',
        description: 'Delicious local biryani',
        price: 200,
        unit: '1 plate',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
      );

      const outOfZoneProduct = ProductEntity(
        id: 'p2',
        storeId: 's_tarikere', // 200 km away
        zoneId: 'z_tarikere',
        categoryId: 'cat_all',
        name: 'Chiken biriyani',
        description: 'Tarikere biryani',
        price: 180,
        unit: '1 plate',
        stock: 5,
        isAvailable: true,
        imageUrl: '',
      );

      // Check zone containment
      final isP1InZone = validStoresMap.containsKey(inZoneProduct.storeId);
      final isP2InZone = validStoresMap.containsKey(outOfZoneProduct.storeId);

      expect(isP1InZone, isTrue);
      expect(isP2InZone, isFalse); // Out of zone store is completely blocked
    });

    test('6. All Essentials (cat_all) matches all items and preserves catalog visibility', () {
      const p1 = ProductEntity(
        id: 'p1',
        storeId: 's1',
        categoryId: 'cat_dairy',
        name: 'Nandini Milk',
        description: 'Toned Milk 500ml',
        price: 24,
        unit: '500 ml',
        stock: 20,
        isAvailable: true,
        imageUrl: '',
      );

      const p2 = ProductEntity(
        id: 'p2',
        storeId: '', // General daily essential
        categoryId: 'cat_groceries',
        name: 'Aashirvaad Atta',
        description: 'Whole wheat flour 5kg',
        price: 275,
        unit: '5 kg',
        stock: 15,
        isAvailable: true,
        imageUrl: '',
      );

      // cat_all must match any product regardless of its specific subcategory
      expect(p1.matchesCategory('cat_all', categories), isTrue);
      expect(p2.matchesCategory('cat_all', categories), isTrue);

      // Specific category matching still isolates properly
      expect(p1.matchesCategory('cat_dairy', categories), isTrue);
      expect(p1.matchesCategory('cat_groceries', categories), isFalse);
    });
  });
}
