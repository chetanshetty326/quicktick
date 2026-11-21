import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/ai/handwritten_list_rag_service.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/core/utils/invoice_pdf_generator.dart';
import 'package:quicklink/features/customer/domain/entities/cart_item_entity.dart';
import 'package:quicklink/features/customer/domain/entities/cart_pricing_entity.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';
import 'package:quicklink/features/customer/domain/entities/handwritten_item_match_entity.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:flutter/services.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';

class MockLocalCache implements ILocalCacheService {
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

class MockCatalogRepo implements ICatalogRepository {
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
      subtotal: 200,
      deliveryFee: 25,
      platformFee: 5,
      total: 230,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOrderRepo implements IOrderRepository {
  bool cancelShouldSucceed = true;
  String cancelErrorMessage = 'Cannot cancel order once preparation has started';
  bool invoiceShouldFail = false;

  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  Future<Either<Failure, bool>> cancelOrder(String orderId, String reason) async {
    if (cancelShouldSucceed) {
      return const Right(true);
    } else {
      return Left(OrderCancelNotAllowedFailure(message: cancelErrorMessage));
    }
  }

  @override
  Future<Either<Failure, List<int>>> downloadOrderInvoice(String orderId) async {
    if (invoiceShouldFail) {
      return const Left(ServerFailure(message: 'Invoice not generated yet on server (404)'));
    }
    // Return sample PDF header bytes
    return Right(Uint8List.fromList('%PDF-1.4\n%TEST\n%%EOF'.codeUnits));
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(String customerId) async {
    return const Right([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return '.';
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('open_filex'),
    (MethodCall methodCall) async => {'type': 0, 'message': 'done'},
  );

  final mockStoreCatalog = [
    const ProductEntity(
      id: 'p_milk',
      name: 'Nandini Toned Fresh Milk',
      description: 'Pasteurised Toned Milk',
      price: 24.0,
      unit: '500 ml',
      imageUrl: '',
      categoryId: 'cat_dairy',
      stock: 5, // Limited stock for testing boundary condition
      isAvailable: true,
      storeId: 'store_01',
    ),
    const ProductEntity(
      id: 'p_atta',
      name: 'Aashirvaad Superior MP Atta',
      description: 'Whole Wheat',
      price: 245.0,
      unit: '5 kg',
      imageUrl: '',
      categoryId: 'cat_staples',
      stock: 0, // OUT OF STOCK for negative testing
      isAvailable: false,
      storeId: 'store_01',
    ),
  ];

  final mockActiveOrder = OrderEntity(
    id: 'ord_123',
    orderNumber: 'QT-100234',
    customerId: 'cust_01',
    customerName: 'Chetan Shetty',
    customerPhone: '+919876543210',
    deliveryAddress: 'Flat 402, Green Glen Layout, Bellandur, Bengaluru',
    storeId: 'store_01',
    storeName: 'QuickMart Supermarket',
    storeAddress: 'Outer Ring Road, Bengaluru',
    items: const [
      OrderItemEntity(
        productId: 'p_milk',
        nameSnapshot: 'Nandini Toned Fresh Milk',
        priceSnapshot: 24.0,
        quantity: 2,
        unit: '500 ml',
      ),
    ],
    subtotal: 48.0,
    deliveryFee: 25.0,
    platformFee: 5.0,
    tax: 2.4,
    discount: 0.0,
    tip: 10.0,
    grandTotal: 90.4,
    status: OrderStatus.placed,
    deliveryOtp: '4589',
    paymentStatus: 'PAID',
    paymentMethod: 'UPI',
    createdAt: DateTime.now(),
  );

  group('PRODUCTION LEVEL: Order Cancellation [Positive & Negative]', () {
    late CustomerBloc bloc;
    late MockOrderRepo mockOrderRepo;
    late MockLocalCache mockCache;

    setUp(() {
      mockCache = MockLocalCache();
      mockOrderRepo = MockOrderRepo();
      bloc = CustomerBloc(
        catalogRepo: MockCatalogRepo(),
        orderRepo: mockOrderRepo,
        localCache: mockCache,
      );
    });

    tearDown(() => bloc.close());

    test('[POSITIVE] Cancelling an eligible placed order updates status & emits success', () async {
      mockOrderRepo.cancelShouldSucceed = true;
      bloc.emit(bloc.state.copyWith(myOrders: [mockActiveOrder]));

      expect(bloc.state.myOrders[0].status, OrderStatus.placed);

      bloc.add(const CancelOrderEvent(orderId: 'ord_123', reason: 'Changed my mind'));
      await pumpEventQueue();

      expect(bloc.state.myOrders[0].status, OrderStatus.cancelled);
      expect(bloc.state.successMessage, 'Order cancelled successfully');
      expect(bloc.state.errorMessage, isNull);
    });

    test('[NEGATIVE] Rejecting cancel when order is in preparation shows clear error without breaking UI', () async {
      mockOrderRepo.cancelShouldSucceed = false;
      mockOrderRepo.cancelErrorMessage = 'Cannot cancel order: store has started preparing your items';

      final preparingOrder = mockActiveOrder.copyWith(status: OrderStatus.preparing);
      bloc.emit(bloc.state.copyWith(myOrders: [preparingOrder]));

      bloc.add(const CancelOrderEvent(orderId: 'ord_123', reason: 'Late delivery'));
      await pumpEventQueue();

      // In-memory status must NOT be cancelled
      expect(bloc.state.myOrders[0].status, OrderStatus.preparing);
      expect(bloc.state.errorMessage, contains('store has started preparing'));
    });
  });

  group('PRODUCTION LEVEL: Invoice Download Pipeline [Positive & Fallback Negative]', () {
    late CustomerBloc bloc;
    late MockOrderRepo mockOrderRepo;
    late MockLocalCache mockCache;

    setUp(() {
      mockCache = MockLocalCache();
      mockOrderRepo = MockOrderRepo();
      bloc = CustomerBloc(
        catalogRepo: MockCatalogRepo(),
        orderRepo: mockOrderRepo,
        localCache: mockCache,
      );
    });

    tearDown(() => bloc.close());

    test('[POSITIVE] Vector PDF Generator creates valid, compliant PDF 1.4 Tax Invoice', () {
      final pdfBytes = InvoicePdfGenerator.generate(mockActiveOrder);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(500)); // Non-trivial vector PDF
      final header = String.fromCharCodes(pdfBytes.take(8));
      expect(header, startsWith('%PDF-1.4'));

      final content = String.fromCharCodes(pdfBytes);
      expect(content, contains('TAX INVOICE'));
      expect(content, contains('QUICK TICK'));
      expect(content, contains('QT-100234'));
      expect(content, contains('Nandini Toned Fresh Milk'));
      expect(content, contains('90.40')); // Grand total
    });

    test('[NEGATIVE / 404] When backend 404s, CustomerBloc emits clear user message without unhandled error', () async {
      mockOrderRepo.invoiceShouldFail = true; // Server returns 404
      bloc.emit(bloc.state.copyWith(myOrders: [mockActiveOrder]));

      final emittedStates = <CustomerState>[];
      final sub = bloc.stream.listen(emittedStates.add);

      bloc.add(const DownloadOrderInvoiceEvent('ord_123'));
      await Future.delayed(const Duration(milliseconds: 100));
      await pumpEventQueue();
      await sub.cancel();

      // Verify that clear user message is emitted
      final last = emittedStates.lastWhere((s) => !s.isDownloadingInvoice, orElse: () => bloc.state);
      expect(last.isDownloadingInvoice, isFalse);
      expect(last.errorMessage, 'Something went wrong, will be downloaded in some time.');
      expect(last.lastDownloadedInvoicePath, isNull);
    });
  });

  group('PRODUCTION LEVEL: AI Handwritten List RAG [Positive, Negative & Boundaries]', () {
    late CustomerBloc bloc;
    late MockLocalCache mockCache;

    setUp(() {
      mockCache = MockLocalCache();
      bloc = CustomerBloc(
        catalogRepo: MockCatalogRepo(),
        orderRepo: MockOrderRepo(),
        localCache: mockCache,
      );
    });

    tearDown(() => bloc.close());

    test('[BOUNDARY / NEGATIVE] Attempting to select quantity beyond available stock is clamped', () async {
      final matches = [
        HandwrittenItemMatchEntity(
          rawText: 'Nandini milk 10 pkts',
          itemName: 'Nandini milk',
          quantity: 5, // Store only has 5 in stock!
          matchedProduct: mockStoreCatalog[0], // stock: 5
          isSelected: true,
        ),
      ];

      final scanResult = HandwrittenListScanResultEntity(
        matches: matches,
        scannedAt: DateTime.now(),
      );

      bloc.emit(bloc.state.copyWith(handwrittenScanResult: scanResult));

      // Attempt to increment past stock of 5
      bloc.add(const UpdateHandwrittenItemQuantityEvent(index: 0, delta: 1));
      await pumpEventQueue();

      // Quantity must NOT exceed 5
      expect(bloc.state.handwrittenScanResult?.matches[0].quantity, 5);
    });

    test('[NEGATIVE] Out-of-stock or non-existent items are unselected and marked cleanly', () {
      final outOfStockMatch = HandwrittenItemMatchEntity(
        rawText: 'Aashirvaad atta 5kg',
        itemName: 'Aashirvaad atta',
        matchedProduct: mockStoreCatalog[1], // stock: 0, isAvailable: false
        isSelected: false,
        statusNote: 'Temporarily Out of Stock',
      );

      final nonExistentMatch = const HandwrittenItemMatchEntity(
        rawText: 'Exotic Truffle Oil',
        itemName: 'Exotic Truffle Oil',
        matchedProduct: null,
        isSelected: false,
        statusNote: 'Not available at this store',
      );

      expect(outOfStockMatch.isFound, isFalse);
      expect(nonExistentMatch.isFound, isFalse);
    });

    test('[NEGATIVE] Empty selection cannot be added to cart', () async {
      final matches = [
        const HandwrittenItemMatchEntity(
          rawText: 'Exotic Truffle Oil',
          itemName: 'Exotic Truffle Oil',
          matchedProduct: null,
          isSelected: false,
        ),
      ];

      final scanResult = HandwrittenListScanResultEntity(
        matches: matches,
        scannedAt: DateTime.now(),
      );

      bloc.emit(bloc.state.copyWith(handwrittenScanResult: scanResult, cartItems: []));

      bloc.add(const AddHandwrittenMatchesToCartEvent());
      await pumpEventQueue();

      // Cart must remain empty and error message surfaced
      expect(bloc.state.cartItems, isEmpty);
      expect(bloc.state.errorMessage, 'No available items selected to add.');
    });
  });

  group('PRODUCTION LEVEL: Cart Integrity & Math [Positive & Edge Cases]', () {
    late CustomerBloc bloc;
    late MockLocalCache mockCache;

    setUp(() {
      mockCache = MockLocalCache();
      bloc = CustomerBloc(
        catalogRepo: MockCatalogRepo(),
        orderRepo: MockOrderRepo(),
        localCache: mockCache,
      );
    });

    tearDown(() => bloc.close());

    test('[POSITIVE] Adding identical item increments quantity rather than duplicating cart row', () async {
      final matches = [
        HandwrittenItemMatchEntity(
          rawText: 'Nandini milk',
          itemName: 'Nandini milk',
          quantity: 2,
          matchedProduct: mockStoreCatalog[0],
          isSelected: true,
        ),
      ];

      final scanResult = HandwrittenListScanResultEntity(
        matches: matches,
        scannedAt: DateTime.now(),
      );

      // Pre-populate cart with 1 milk
      bloc.emit(bloc.state.copyWith(
        cartItems: [CartItemEntity(product: mockStoreCatalog[0], quantity: 1)],
        handwrittenScanResult: scanResult,
      ));

      expect(bloc.state.cartItems.length, 1);
      expect(bloc.state.cartItems[0].quantity, 1);

      bloc.add(const AddHandwrittenMatchesToCartEvent());
      await pumpEventQueue();

      // Total quantity must be 1 + 2 = 3, single row
      expect(bloc.state.cartItems.length, 1);
      expect(bloc.state.cartItems[0].quantity, 3);
    });
  });
}
