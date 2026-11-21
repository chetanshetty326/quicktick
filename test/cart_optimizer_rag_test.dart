import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/ai/ai_client.dart';
import 'package:quicklink/core/ai/catalog_retriever.dart';
import 'package:quicklink/core/ai/cart_rag_service.dart';
import 'package:quicklink/features/customer/domain/entities/cart_item_entity.dart';
import 'package:quicklink/features/customer/domain/entities/cart_optimization_entity.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

class FakeAiClient implements IAiClient {
  String? cannedResponse;

  @override
  Future<String?> generateCompletion({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    return cannedResponse;
  }
}

void main() {
  group('CatalogRetriever', () {
    const retriever = CatalogRetriever();

    final productInCart = ProductEntity(
      id: 'p1',
      storeId: 'store_1',
      categoryId: 'cat_bakery',
      name: 'Britannia White Bread',
      description: 'Classic white bread',
      price: 50.0,
      unit: '400g',
      stock: 10,
      isAvailable: true,
      imageUrl: '',
    );

    final candidateCheaperBread = ProductEntity(
      id: 'p2',
      storeId: 'store_1',
      categoryId: 'cat_bakery',
      name: 'Local Daily White Bread',
      description: 'Fresh bakery bread',
      price: 35.0,
      unit: '400g',
      stock: 8,
      isAvailable: true,
      imageUrl: '',
    );

    final candidateDifferentCategory = ProductEntity(
      id: 'p3',
      storeId: 'store_1',
      categoryId: 'cat_dairy',
      name: 'Amul Milk',
      description: 'Milk',
      price: 30.0,
      unit: '500ml',
      stock: 12,
      isAvailable: true,
      imageUrl: '',
    );

    final outOfStockProduct = ProductEntity(
      id: 'p4',
      storeId: 'store_1',
      categoryId: 'cat_bakery',
      name: 'Modern Bread',
      description: 'Bread',
      price: 30.0,
      unit: '400g',
      stock: 0,
      isAvailable: false,
      imageUrl: '',
    );

    test('retrieves relevant available products and excludes cart items & out-of-stock items', () {
      final cart = [CartItemEntity(product: productInCart, quantity: 1)];
      final catalog = [
        productInCart,
        candidateCheaperBread,
        candidateDifferentCategory,
        outOfStockProduct,
      ];

      final results = retriever.retrieveCandidates(
        cartItems: cart,
        storeCatalog: catalog,
      );

      expect(results.length, 1);
      expect(results.first.id, 'p2');
    });

    test('parses unit weights in grams or ml correctly', () {
      expect(CatalogRetriever.parseUnitWeightInGramsOrMl('400g'), 400.0);
      expect(CatalogRetriever.parseUnitWeightInGramsOrMl('1 kg'), 1000.0);
      expect(CatalogRetriever.parseUnitWeightInGramsOrMl('500ml'), 500.0);
      expect(CatalogRetriever.parseUnitWeightInGramsOrMl('1 L'), 1000.0);
      expect(CatalogRetriever.parseUnitWeightInGramsOrMl('2.5 Litre'), 2500.0);
    });
  });

  group('CartRagService', () {
    late CartRagService service;
    late FakeAiClient fakeAiClient;

    final expensiveBread = ProductEntity(
      id: 'p_exp_bread',
      storeId: 'store_1',
      categoryId: 'cat_bakery',
      name: 'Premium Sandwich White Bread',
      description: 'White bread',
      price: 60.0,
      unit: '400g',
      stock: 15,
      isAvailable: true,
      imageUrl: '',
    );

    final cheaperBread = ProductEntity(
      id: 'p_cheap_bread',
      storeId: 'store_1',
      categoryId: 'cat_bakery',
      name: 'Daily Fresh White Bread',
      description: 'White bread',
      price: 40.0,
      unit: '400g',
      stock: 10,
      isAvailable: true,
      imageUrl: '',
    );

    final wholeWheatBread = ProductEntity(
      id: 'p_wheat_bread',
      storeId: 'store_1',
      categoryId: 'cat_bakery',
      name: 'The Health Factory Whole Wheat Bread',
      description: '100% whole grain zero maida',
      price: 55.0,
      unit: '400g',
      stock: 10,
      isAvailable: true,
      imageUrl: '',
    );

    final whiteSugar = ProductEntity(
      id: 'p_white_sugar',
      storeId: 'store_1',
      categoryId: 'cat_staples',
      name: 'Madhur Refined White Sugar',
      description: 'Refined sugar',
      price: 60.0,
      unit: '1 kg',
      stock: 20,
      isAvailable: true,
      imageUrl: '',
    );

    final organicJaggery = ProductEntity(
      id: 'p_jaggery',
      storeId: 'store_1',
      categoryId: 'cat_staples',
      name: 'Organic Jaggery Powder',
      description: 'Unrefined natural jaggery',
      price: 75.0,
      unit: '1 kg',
      stock: 15,
      isAvailable: true,
      imageUrl: '',
    );

    setUp(() {
      fakeAiClient = FakeAiClient();
      service = CartRagService(aiClient: fakeAiClient);
    });

    test('Budget Mode: recommends cheaper alternative and calculates exact savings', () async {
      fakeAiClient.cannedResponse = null; // Triggers local heuristic fallback

      final cart = [CartItemEntity(product: expensiveBread, quantity: 2)];
      final catalog = [expensiveBread, cheaperBread];

      final result = await service.optimizeCart(
        cartItems: cart,
        storeCatalog: catalog,
        type: CartOptimizationType.budget,
      );

      expect(result.hasSuggestions, isTrue);
      expect(result.suggestions.length, 1);
      final suggestion = result.suggestions.first;
      expect(suggestion.originalProduct.id, 'p_exp_bread');
      expect(suggestion.suggestedProduct.id, 'p_cheap_bread');
      expect(suggestion.savings, 20.0);
      expect(suggestion.totalSavings, 40.0); // 2 units * ₹20
      expect(result.totalPotentialSavings, 40.0);
    });

    test('Healthy Mode: recommends whole-grain or unrefined alternatives', () async {
      fakeAiClient.cannedResponse = null;

      final cart = [
        CartItemEntity(product: expensiveBread, quantity: 1),
        CartItemEntity(product: whiteSugar, quantity: 1),
      ];
      final catalog = [expensiveBread, wholeWheatBread, whiteSugar, organicJaggery];

      final result = await service.optimizeCart(
        cartItems: cart,
        storeCatalog: catalog,
        type: CartOptimizationType.healthy,
      );

      expect(result.hasSuggestions, isTrue);
      expect(result.suggestions.length, 2);

      final breadSwap = result.suggestions.firstWhere((s) => s.originalProduct.id == 'p_exp_bread');
      expect(breadSwap.suggestedProduct.id, 'p_wheat_bread');
      expect(breadSwap.healthTag, 'High Fiber');

      final sugarSwap = result.suggestions.firstWhere((s) => s.originalProduct.id == 'p_white_sugar');
      expect(sugarSwap.suggestedProduct.id, 'p_jaggery');
      expect(sugarSwap.healthTag, 'Unrefined Minerals');
    });

    test('returns empty suggestions when cart is already optimal', () async {
      fakeAiClient.cannedResponse = null;

      // Cart already has cheapest bread
      final cart = [CartItemEntity(product: cheaperBread, quantity: 1)];
      final catalog = [expensiveBread, cheaperBread];

      final result = await service.optimizeCart(
        cartItems: cart,
        storeCatalog: catalog,
        type: CartOptimizationType.budget,
      );

      expect(result.hasSuggestions, isFalse);
      expect(result.totalPotentialSavings, 0.0);
    });

    test('AI Output Parsing: properly parses valid JSON from LLM into suggestions', () async {
      fakeAiClient.cannedResponse = '''
{
  "suggestions": [
    {
      "originalProductId": "p_exp_bread",
      "suggestedProductId": "p_cheap_bread",
      "savings": 20.0,
      "reason": "Top rated budget option",
      "healthTag": "Best Value"
    }
  ]
}
''';

      final cart = [CartItemEntity(product: expensiveBread, quantity: 1)];
      final catalog = [expensiveBread, cheaperBread];

      final result = await service.optimizeCart(
        cartItems: cart,
        storeCatalog: catalog,
        type: CartOptimizationType.budget,
      );

      expect(result.hasSuggestions, isTrue);
      expect(result.suggestions.first.reason, 'Top rated budget option');
      expect(result.suggestions.first.healthTag, 'Best Value');
      expect(result.totalPotentialSavings, 20.0);
    });
  });
}
