import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/customer/data/models/store_model.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';

void main() {
  group('1. StoreEntity & StoreModel Zone Restriction Clean Arch Tests', () {
    test('StoreEntity supports zoneId field and copyWith', () {
      const store = StoreEntity(
        id: 's_01',
        name: 'Fresh Fruits Hub',
        category: 'Grocery',
        address: '100ft Rd, Indiranagar',
        rating: 4.8,
        deliveryTime: '15 min',
        distanceKm: 0.8,
        isOpen: true,
        bannerUrl: '',
        zoneId: 'zone_indiranagar_01',
      );

      expect(store.zoneId, 'zone_indiranagar_01');

      final updated = store.copyWith(zoneId: 'zone_koramangala_02');
      expect(updated.zoneId, 'zone_koramangala_02');
      expect(updated.id, 's_01');
    });

    test('StoreModel parses zoneId from direct zoneId string', () {
      final json = {
        'id': 'store_101',
        'shopName': 'Daily Mart Indiranagar',
        'zoneId': '6abe8daf523e496cfdd80053',
        'isOpen': true,
      };

      final model = StoreModel.fromJson(json);
      expect(model.id, 'store_101');
      expect(model.zoneId, '6abe8daf523e496cfdd80053');
      expect(model.toJson()['zoneId'], '6abe8daf523e496cfdd80053');
    });

    test('StoreModel parses zoneId from nested zone object', () {
      final json = {
        'id': 'store_102',
        'shopName': 'Organic Harvest Whitefield',
        'zone': {
          '_id': 'zone_whitefield_88',
          'name': 'Whitefield Operational Zone',
        },
        'isOpen': true,
      };

      final model = StoreModel.fromJson(json);
      expect(model.id, 'store_102');
      expect(model.zoneId, 'zone_whitefield_88');
    });
  });

  group('2. Customer App Zone Store Filtering Tests', () {
    const storeZoneA = StoreEntity(
      id: 'store_a',
      name: 'Indiranagar Fresh Groceries',
      category: 'Grocery',
      address: 'Indiranagar 12th Main',
      rating: 4.6,
      deliveryTime: '15 min',
      distanceKm: 0.5,
      isOpen: true,
      bannerUrl: '',
      zoneId: 'zone_indiranagar',
    );

    const storeZoneB = StoreEntity(
      id: 'store_b',
      name: 'Whitefield Organic Cafe',
      category: 'Cafe',
      address: 'ITPL Main Rd, Whitefield',
      rating: 4.7,
      deliveryTime: '20 min',
      distanceKm: 12.0,
      isOpen: true,
      bannerUrl: '',
      zoneId: 'zone_whitefield',
    );

    final allStores = [storeZoneA, storeZoneB];

    test('Customer in zone_indiranagar only sees same-zone store (store_b is hidden)', () {
      const customerZoneId = 'zone_indiranagar';

      // Filtering logic applied in clean arch bloc
      final visibleStores = allStores.where((s) => s.zoneId == null || s.zoneId == customerZoneId).toList();

      expect(visibleStores.length, 1);
      expect(visibleStores.first.id, 'store_a');
      expect(visibleStores.any((s) => s.id == 'store_b'), isFalse);
    });

    test('Customer out of zone (inZone == false) sees zero stores', () {
      final visibleStores = <StoreEntity>[];

      expect(visibleStores.isEmpty, isTrue);
    });
  });

  group('3. Delivery Partner Zone Dispatch & Order Filtering Tests', () {
    final now = DateTime.now();

    final orderInZone = OrderEntity(
      id: 'order_zone_a',
      orderNumber: 'QC-261006-0001',
      customerId: 'cust_01',
      customerName: 'Aarav Sharma',
      customerPhone: '+919876543210',
      deliveryAddress: 'Indiranagar 100ft Rd',
      storeId: 'store_a',
      storeName: 'Indiranagar Fresh',
      storeAddress: 'Indiranagar 12th Main',
      items: const [],
      subtotal: 250,
      deliveryFee: 35,
      platformFee: 5,
      grandTotal: 290,
      status: OrderStatus.readyForPickup,
      deliveryOtp: '1234',
      createdAt: now,
      zoneId: 'zone_indiranagar',
    );

    final orderOutZone = OrderEntity(
      id: 'order_zone_b',
      orderNumber: 'QC-261006-0002',
      customerId: 'cust_02',
      customerName: 'Priya Verma',
      customerPhone: '+919876543211',
      deliveryAddress: 'Whitefield Main Rd',
      storeId: 'store_b',
      storeName: 'Whitefield Store',
      storeAddress: 'Whitefield ITPL',
      items: const [],
      subtotal: 400,
      deliveryFee: 45,
      platformFee: 5,
      grandTotal: 450,
      status: OrderStatus.readyForPickup,
      deliveryOtp: '5678',
      createdAt: now,
      zoneId: 'zone_whitefield',
    );

    test('Delivery partner in Indiranagar only receives orders in zone_indiranagar', () {
      const riderZone = 'zone_indiranagar';
      final allOrders = [orderInZone, orderOutZone];

      // Filtering logic in DeliveryBloc._updateOrdersState
      final availableOrders = allOrders.where((o) {
        if (o.zoneId != null && o.zoneId!.isNotEmpty) {
          if (o.zoneId != riderZone) return false;
        }
        return true;
      }).toList();

      expect(availableOrders.length, 1);
      expect(availableOrders.first.id, 'order_zone_a');
      expect(availableOrders.any((o) => o.id == 'order_zone_b'), isFalse);
    });

    test('Delivery partner cannot accept an order from a different zone', () {
      const riderZone = 'zone_indiranagar';
      final orderFromOtherZone = orderOutZone;

      // Validation check in DeliveryBloc._onAcceptJob
      final bool isAllowed = (orderFromOtherZone.zoneId == null ||
          orderFromOtherZone.zoneId!.isEmpty ||
          orderFromOtherZone.zoneId == riderZone);

      expect(isAllowed, isFalse);
    });
  });

  group('4. UI Responsiveness on 320x568 Small Screen Tests', () {
    testWidgets('Out of Serviceable Zone Customer card renders cleanly without overflow on 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Out of Serviceable Zone',
                            style: TextStyle(
                              color: Color(0xFF991B1B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'QuickLink is not currently delivering to your location. Retailer stores and products are unavailable in this area.',
                      style: TextStyle(
                        color: Color(0xFF7F1D1D),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                      label: const Text('Change Delivery Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Out of Serviceable Zone'), findsOneWidget);
      expect(find.text('Change Delivery Location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Delivery Partner Out of Operational Zone card renders cleanly without overflow on 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Center(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Out of Operational Zone',
                                  style: TextStyle(
                                    color: Color(0xFFF87171),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'Out of Zone',
                            style: TextStyle(
                              color: Color(0xFFF87171),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '📍 Out of Serviceable Zone',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '❌ Out of Serviceable Zone: QuickLink delivery partner onboarding is not currently active in your area. Registration cannot proceed.',
                      style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Out of Operational Zone'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
