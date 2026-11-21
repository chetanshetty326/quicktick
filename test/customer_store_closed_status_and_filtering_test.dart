import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/customer/data/models/store_model.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/presentation/screens/customer_main_screen.dart';

void main() {
  group('1. StoreModel Closed Status Parsing Tests', () {
    test('Correctly parses isOpen: false', () {
      final json = {
        'id': 's1',
        'shopName': 'Closed Corner Store',
        'isOpen': false,
      };
      final store = StoreModel.fromJson(json);
      expect(store.isOpen, isFalse);
    });

    test('Correctly parses isStoreOpen: false', () {
      final json = {
        'id': 's2',
        'shopName': 'Night Owl Cafe',
        'isStoreOpen': false,
      };
      final store = StoreModel.fromJson(json);
      expect(store.isOpen, isFalse);
    });

    test('Correctly parses isOnline: false', () {
      final json = {
        'id': 's3',
        'shopName': 'Offline Bakers',
        'isOnline': false,
      };
      final store = StoreModel.fromJson(json);
      expect(store.isOpen, isFalse);
    });

    test('Correctly parses status: CLOSED and INACTIVE', () {
      final jsonClosed = {
        'id': 's4',
        'shopName': 'Sunday Closed Supermarket',
        'status': 'CLOSED',
      };
      final storeClosed = StoreModel.fromJson(jsonClosed);
      expect(storeClosed.isOpen, isFalse);

      final jsonInactive = {
        'id': 's5',
        'shopName': 'Temporary Inactive Hub',
        'status': 'INACTIVE',
      };
      final storeInactive = StoreModel.fromJson(jsonInactive);
      expect(storeInactive.isOpen, isFalse);
    });

    test('Correctly parses open stores', () {
      final json = {
        'id': 's6',
        'shopName': 'Active Daily Needs',
        'isOpen': true,
        'status': 'APPROVED',
      };
      final store = StoreModel.fromJson(json);
      expect(store.isOpen, isTrue);
    });

    test('Negative flags take precedence over status: APPROVED when retailer toggles closed', () {
      final jsonClosedApproved = {
        'id': 's7',
        'shopName': 'Approved But Closed Shop',
        'status': 'APPROVED',
        'isOpen': false,
      };
      final storeClosed = StoreModel.fromJson(jsonClosedApproved);
      expect(storeClosed.isOpen, isFalse);

      final jsonClosedString = {
        'id': 's8',
        'shopName': 'Offline String Shop',
        'status': 'APPROVED',
        'isOpen': 'false',
      };
      final storeStringClosed = StoreModel.fromJson(jsonClosedString);
      expect(storeStringClosed.isOpen, isFalse);
    });

    test('Toggling back online restores isOpen to true', () {
      final jsonBackOnline = {
        'id': 's7',
        'shopName': 'Approved And Re-opened Shop',
        'status': 'APPROVED',
        'isOpen': true,
      };
      final storeOnline = StoreModel.fromJson(jsonBackOnline);
      expect(storeOnline.isOpen, isTrue);
    });
  });

  group('2. Customer StoreCard Black & White & Non-Tappable Widget Tests', () {
    testWidgets('Closed store renders in Black & White (ColorFiltered) and shows CLOSED badge', (tester) async {
      const closedStore = StoreEntity(
        id: 'store_closed_01',
        name: 'The Rustic Oven',
        category: 'Bakery & Desserts',
        address: 'MG Road, Bengaluru',
        rating: 4.8,
        deliveryTime: '20 min',
        distanceKm: 1.5,
        isOpen: false, // CLOSED
        bannerUrl: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomerStoreCard(store: closedStore),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify ColorFiltered widget is present (Grayscale / B&W filter)
      final colorFilteredFinder = find.byType(ColorFiltered);
      expect(colorFilteredFinder, findsOneWidget);

      final colorFilteredWidget = tester.widget<ColorFiltered>(colorFilteredFinder);
      expect(colorFilteredWidget.colorFilter, isNotNull);

      // Verify "CLOSED" text is clearly stated
      expect(find.text('CLOSED'), findsWidgets);
      expect(find.text('Currently not accepting orders'), findsOneWidget);
    });

    testWidgets('Closed store card is NOT tappable and does not open store details modal', (tester) async {
      const closedStore = StoreEntity(
        id: 'store_closed_02',
        name: 'Midnight Brew Cafe',
        category: 'Cafe & Drinks',
        address: 'Indiranagar, Bengaluru',
        rating: 4.6,
        deliveryTime: '25 min',
        distanceKm: 2.0,
        isOpen: false, // CLOSED
        bannerUrl: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomerStoreCard(store: closedStore),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the GestureDetector for the card
      final gestureFinder = find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.child is ColorFiltered,
      );
      expect(gestureFinder, findsOneWidget);

      final gestureWidget = tester.widget<GestureDetector>(gestureFinder);
      // onTap must be null so that closed card is not tappable
      expect(gestureWidget.onTap, isNull);

      // Tap the card and pump
      await tester.tap(gestureFinder);
      await tester.pumpAndSettle();

      // Verify that no modal bottom sheet or "Browse Products" sheet was opened
      expect(find.text('Browse Products from Midnight Brew Cafe'), findsNothing);
    });

    testWidgets('Open store card renders in full color and IS tappable', (tester) async {
      const openStore = StoreEntity(
        id: 'store_open_01',
        name: 'BigBasket Express',
        category: 'Groceries & Fresh',
        address: 'Indiranagar, Bengaluru',
        rating: 4.7,
        deliveryTime: '15 min',
        distanceKm: 0.8,
        isOpen: true, // OPEN
        bannerUrl: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomerStoreCard(store: openStore),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open store should NOT have ColorFiltered applied to its root card content
      final colorFilteredFinder = find.byType(ColorFiltered);
      expect(colorFilteredFinder, findsNothing);

      // Open store should display its active rating
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('CLOSED'), findsNothing);

      // Verify onTap is active and clickable
      final gestureFinder = find.byType(GestureDetector);
      final gestureWidget = tester.widget<GestureDetector>(gestureFinder.first);
      expect(gestureWidget.onTap, isNotNull);
    });
  });

  group('3. Retailer Stores Having Products Filtering Logic Tests', () {
    test('Filters out stores with zero products and includes all retailers that have products', () {
      const storeWithProducts1 = StoreEntity(
        id: 'store_with_prod_1',
        name: 'Green Grocers',
        category: 'Produce',
        address: 'Local Area',
        rating: 4.8,
        deliveryTime: '15 min',
        distanceKm: 1.0,
        isOpen: true,
        bannerUrl: '',
      );

      const storeWithProducts2 = StoreEntity(
        id: 'store_with_prod_2',
        name: 'Spice Route',
        category: 'Food',
        address: 'Local Area',
        rating: 4.5,
        deliveryTime: '20 min',
        distanceKm: 1.5,
        isOpen: false, // Closed store having products
        bannerUrl: '',
      );

      const storeWithNoProducts = StoreEntity(
        id: 'store_empty',
        name: 'Empty Boutique',
        category: 'Clothing',
        address: 'Local Area',
        rating: 4.0,
        deliveryTime: '30 min',
        distanceKm: 3.0,
        isOpen: true,
        bannerUrl: '',
      );

      final allStores = [storeWithProducts1, storeWithProducts2, storeWithNoProducts];

      const product1 = ProductEntity(
        id: 'p1',
        storeId: 'store_with_prod_1',
        name: 'Fresh Spinach',
        description: '',
        price: 25.0,
        unit: 'bunch',
        imageUrl: '',
        categoryId: 'cat_veg',
        isAvailable: true,
        stock: 10,
      );

      const product2 = ProductEntity(
        id: 'p2',
        storeId: 'store_with_prod_2',
        name: 'Biryani Masala',
        description: '',
        price: 90.0,
        unit: 'pack',
        imageUrl: '',
        categoryId: 'cat_spices',
        isAvailable: true,
        stock: 5,
      );

      final allProducts = [product1, product2];

      // Simulate the filtering logic from _buildStoresSection
      final storeIdsWithProducts = allProducts.map((p) => p.storeId).toSet();
      final filteredStores = allStores.where((s) => storeIdsWithProducts.contains(s.id)).toList();

      expect(filteredStores.length, equals(2));
      expect(filteredStores.any((s) => s.id == 'store_with_prod_1'), isTrue);
      expect(filteredStores.any((s) => s.id == 'store_with_prod_2'), isTrue);
      expect(filteredStores.any((s) => s.id == 'store_empty'), isFalse);

      final openCount = filteredStores.where((s) => s.isOpen).length;
      expect(openCount, equals(1)); // Only store_with_prod_1 is open
    });
  });
}
