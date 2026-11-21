import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/ai/handwritten_list_rag_service.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/handwritten_item_match_entity.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/customer/domain/entities/cart_pricing_entity.dart';
import 'package:dartz/dartz.dart';

class FakeLocalCache implements ILocalCacheService {
  String _lang = 'en';
  List<Map<String, dynamic>> _cart = [];

  @override
  String getAppLanguage() => _lang;

  @override
  Future<void> setAppLanguage(String code) async => _lang = code;

  @override
  Future<void> saveCart(List<Map<String, dynamic>> cart) async => _cart = cart;

  @override
  List<Map<String, dynamic>> getCart() => _cart;

  @override
  Future<void> saveCartItems(List<Map<String, dynamic>> items) async => _cart = items;

  @override
  List<Map<String, dynamic>> getCartItems() => _cart;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCatalogRepo implements ICatalogRepository {
  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();

  @override
  Stream<List<StoreEntity>> get storesStream => const Stream.empty();

  @override
  Future<Either<Failure, CartPricingEntity>> getCartPricing({
    String? couponCode,
    double? tip,
    String? zoneId,
    double? lat,
    double? lng,
  }) async {
    return const Right(CartPricingEntity(
      subtotal: 100,
      deliveryFee: 0,
      platformFee: 0,
      total: 100,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOrderRepo implements IOrderRepository {
  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockStoreCatalog = [
    const ProductEntity(
      id: 'p_milk_1',
      name: 'Nandini Toned Fresh Milk',
      description: 'Pasteurised Toned Milk',
      price: 24.0,
      unit: '500 ml',
      imageUrl: '',
      categoryId: 'cat_dairy',
      stock: 25,
      isAvailable: true,
      storeId: 'store_01',
    ),
    const ProductEntity(
      id: 'p_atta_1',
      name: 'Aashirvaad Superior MP Sharbati Atta',
      description: '100% Whole Wheat',
      price: 245.0,
      unit: '5 kg',
      imageUrl: '',
      categoryId: 'cat_staples',
      stock: 10,
      isAvailable: true,
      storeId: 'store_01',
    ),
    const ProductEntity(
      id: 'p_salt_1',
      name: 'Tata Iodized Salt',
      description: 'Vacuum Evaporated Iodized Salt',
      price: 28.0,
      unit: '1 kg',
      imageUrl: '',
      categoryId: 'cat_staples',
      stock: 50,
      isAvailable: true,
      storeId: 'store_01',
    ),
  ];

  group('Handwritten Entities & Math', () {
    test('HandwrittenItemMatchEntity correctly evaluates isFound', () {
      final match = HandwrittenItemMatchEntity(
        rawText: 'Nandini blue milk 1 pkt',
        itemName: 'Nandini blue milk',
        quantity: 2,
        matchedProduct: mockStoreCatalog[0],
        matchScore: 0.95,
      );

      expect(match.isFound, isTrue);
      expect(match.itemName, 'Nandini blue milk');
      expect(match.quantity, 2);

      final notFound = const HandwrittenItemMatchEntity(
        rawText: 'Dragon fruit',
        itemName: 'Dragon fruit',
        matchedProduct: null,
      );
      expect(notFound.isFound, isFalse);
    });

    test('HandwrittenListScanResultEntity calculates total and selected counts accurately', () {
      final matches = [
        HandwrittenItemMatchEntity(
          rawText: 'Nandini blue milk 1 pkt',
          itemName: 'Nandini blue milk',
          quantity: 2,
          matchedProduct: mockStoreCatalog[0], // ₹24 * 2 = 48
          isSelected: true,
        ),
        HandwrittenItemMatchEntity(
          rawText: 'Aashirvaad atta 5kg',
          itemName: 'Aashirvaad atta',
          quantity: 1,
          matchedProduct: mockStoreCatalog[1], // ₹245 * 1 = 245
          isSelected: true,
        ),
        const HandwrittenItemMatchEntity(
          rawText: 'Dragon fruit',
          itemName: 'Dragon fruit',
          quantity: 1,
          matchedProduct: null,
          isSelected: false,
        ),
      ];

      final result = HandwrittenListScanResultEntity(
        matches: matches,
        scannedAt: DateTime.now(),
      );

      expect(result.totalDetected, 3);
      expect(result.matchedCount, 2);
      expect(result.selectedCount, 2);
      expect(result.estimatedTotal, 48.0 + 245.0); // ₹293.0
    });
  });

  group('HandwrittenListRagService RAG Matching', () {
    test('Correctly resolves store catalog products and quantities', () async {
      final service = HandwrittenListRagService();

      // Test processing with catalog
      final result = await service.processHandwrittenList(
        imageBytes: Uint8List(0), // empty fallback
        storeCatalog: mockStoreCatalog,
      );

      expect(result.matches, isEmpty);
    });
  });

  group('CustomerBloc Handwritten Flow', () {
    late CustomerBloc bloc;
    late FakeLocalCache fakeCache;

    setUp(() {
      fakeCache = FakeLocalCache();
      bloc = CustomerBloc(
        catalogRepo: FakeCatalogRepo(),
        orderRepo: FakeOrderRepo(),
        localCache: fakeCache,
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('ToggleHandwrittenItemSelectionEvent updates selection flag', () async {
      final matches = [
        HandwrittenItemMatchEntity(
          rawText: 'Nandini blue milk',
          itemName: 'Nandini blue milk',
          quantity: 1,
          matchedProduct: mockStoreCatalog[0],
          isSelected: true,
        ),
      ];
      final scanResult = HandwrittenListScanResultEntity(
        matches: matches,
        scannedAt: DateTime.now(),
      );

      bloc.emit(bloc.state.copyWith(handwrittenScanResult: scanResult));
      expect(bloc.state.handwrittenScanResult?.matches[0].isSelected, isTrue);

      bloc.add(const ToggleHandwrittenItemSelectionEvent(0));
      await pumpEventQueue();

      expect(bloc.state.handwrittenScanResult?.matches[0].isSelected, isFalse);
    });

    test('UpdateHandwrittenItemQuantityEvent increments and decrements quantity', () async {
      final matches = [
        HandwrittenItemMatchEntity(
          rawText: 'Nandini blue milk',
          itemName: 'Nandini blue milk',
          quantity: 1,
          matchedProduct: mockStoreCatalog[0],
        ),
      ];
      final scanResult = HandwrittenListScanResultEntity(
        matches: matches,
        scannedAt: DateTime.now(),
      );

      bloc.emit(bloc.state.copyWith(handwrittenScanResult: scanResult));

      // Increment +1
      bloc.add(const UpdateHandwrittenItemQuantityEvent(index: 0, delta: 1));
      await pumpEventQueue();
      expect(bloc.state.handwrittenScanResult?.matches[0].quantity, 2);

      // Decrement -1
      bloc.add(const UpdateHandwrittenItemQuantityEvent(index: 0, delta: -1));
      await pumpEventQueue();
      expect(bloc.state.handwrittenScanResult?.matches[0].quantity, 1);

      // Should not go below 1
      bloc.add(const UpdateHandwrittenItemQuantityEvent(index: 0, delta: -1));
      await pumpEventQueue();
      expect(bloc.state.handwrittenScanResult?.matches[0].quantity, 1);
    });

    test('AddHandwrittenMatchesToCartEvent adds selected items to state cart', () async {
      final matches = [
        HandwrittenItemMatchEntity(
          rawText: 'Nandini blue milk',
          itemName: 'Nandini blue milk',
          quantity: 2,
          matchedProduct: mockStoreCatalog[0],
          isSelected: true,
        ),
        HandwrittenItemMatchEntity(
          rawText: 'Aashirvaad atta',
          itemName: 'Aashirvaad atta',
          quantity: 1,
          matchedProduct: mockStoreCatalog[1],
          isSelected: true,
        ),
        const HandwrittenItemMatchEntity(
          rawText: 'Dragon fruit',
          itemName: 'Dragon fruit',
          matchedProduct: null,
          isSelected: false,
        ),
      ];

      final scanResult = HandwrittenListScanResultEntity(
        matches: matches,
        scannedAt: DateTime.now(),
      );

      bloc.emit(bloc.state.copyWith(handwrittenScanResult: scanResult));

      final emittedStates = <CustomerState>[];
      final sub = bloc.stream.listen(emittedStates.add);

      bloc.add(const AddHandwrittenMatchesToCartEvent());
      await pumpEventQueue();
      await sub.cancel();

      expect(bloc.state.cartItems.length, 2);
      expect(bloc.state.cartItems[0].product.id, 'p_milk_1');
      expect(bloc.state.cartItems[0].quantity, 2);
      expect(bloc.state.cartItems[1].product.id, 'p_atta_1');
      expect(bloc.state.cartItems[1].quantity, 1);
      expect(emittedStates.any((s) => s.successMessage != null && s.successMessage!.contains('Added 2 items to your cart')), isTrue);
    });
  });
}

