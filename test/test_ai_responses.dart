import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/ai/cart_rag_service.dart';
import 'package:quicklink/core/ai/catalog_retriever.dart';
import 'package:quicklink/core/ai/ai_client.dart';
import 'package:quicklink/features/customer/domain/entities/cart_item_entity.dart';
import 'package:quicklink/features/customer/domain/entities/cart_optimization_entity.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

class MockLlmClient implements IAiClient {
  @override
  Future<String?> generateCompletion({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    // Simulating actual LLM response from Llama-3.3-70b / Gemini 1.5 Flash
    if (systemPrompt.contains('cheaper alternative')) {
      return '''
{
  "suggestions": [
    {
      "originalProductId": "prod_kelloggs",
      "suggestedProductId": "prod_bagrrys",
      "savings": 80.0,
      "reason": "Equivalent 500g crunchy muesli pack at lower price",
      "healthTag": "Save ₹80"
    },
    {
      "originalProductId": "prod_sugar",
      "suggestedProductId": "prod_daily_sugar",
      "savings": 12.0,
      "reason": "Direct refinery packing, saves ₹12 per kg",
      "healthTag": "Save ₹12"
    }
  ]
}
''';
    } else {
      return '''
{
  "suggestions": [
    {
      "originalProductId": "prod_white_bread",
      "suggestedProductId": "prod_wheat_bread",
      "savings": 5.0,
      "reason": "100% whole grain zero maida, prevents glucose spikes",
      "healthTag": "High Fiber"
    },
    {
      "originalProductId": "prod_sugar",
      "suggestedProductId": "prod_jaggery",
      "savings": 0.0,
      "reason": "Unrefined minerals with lower glycemic index",
      "healthTag": "Unrefined Minerals"
    },
    {
      "originalProductId": "prod_chips",
      "suggestedProductId": "prod_makhana",
      "savings": 0.0,
      "reason": "Slow-roasted foxnuts, zero trans fats and rich in plant protein",
      "healthTag": "Non-Fried Snack"
    }
  ]
}
''';
    }
  }
}

void main() {
  test('Interactive Demo: AI Ask & Response', () async {
    print('\n================================================================');
    print('       QUICKTICK AI RAG ENGINE - INTERACTIVE DEMO TEST          ');
    print('================================================================\n');

    final cartItems = [
      CartItemEntity(
        product: const ProductEntity(
          id: 'prod_white_bread',
          storeId: 'store_indiranagar',
          categoryId: 'cat_bakery',
          name: 'Britannia Daily Fresh White Bread',
          description: 'Enriched white bread',
          price: 50.0,
          unit: '400g',
          stock: 20,
          isAvailable: true,
          imageUrl: '',
        ),
        quantity: 1,
      ),
      CartItemEntity(
        product: const ProductEntity(
          id: 'prod_sugar',
          storeId: 'store_indiranagar',
          categoryId: 'cat_staples',
          name: 'Madhur Refined White Sugar',
          description: 'Sparkling white sugar',
          price: 62.0,
          unit: '1 kg',
          stock: 15,
          isAvailable: true,
          imageUrl: '',
        ),
        quantity: 1,
      ),
      CartItemEntity(
        product: const ProductEntity(
          id: 'prod_chips',
          storeId: 'store_indiranagar',
          categoryId: 'cat_snacks',
          name: 'Lays American Style Cream & Onion Chips',
          description: 'Potato chips',
          price: 25.0,
          unit: '50g',
          stock: 30,
          isAvailable: true,
          imageUrl: '',
        ),
        quantity: 2,
      ),
      CartItemEntity(
        product: const ProductEntity(
          id: 'prod_kelloggs',
          storeId: 'store_indiranagar',
          categoryId: 'cat_breakfast',
          name: "Kellogg's Corn Flakes Original",
          description: 'Breakfast cereal',
          price: 340.0,
          unit: '500g',
          stock: 10,
          isAvailable: true,
          imageUrl: '',
        ),
        quantity: 1,
      ),
    ];

    final storeCatalog = [
      ...cartItems.map((c) => c.product),
      const ProductEntity(
        id: 'prod_bagrrys',
        storeId: 'store_indiranagar',
        categoryId: 'cat_breakfast',
        name: "Bagrry's Crunchy Corn Flakes & Muesli",
        description: 'Breakfast cereal',
        price: 260.0,
        unit: '500g',
        stock: 12,
        isAvailable: true,
        imageUrl: '',
      ),
      const ProductEntity(
        id: 'prod_daily_sugar',
        storeId: 'store_indiranagar',
        categoryId: 'cat_staples',
        name: 'Safe Harvest Pure Farm Sugar',
        description: 'Cane sugar',
        price: 50.0,
        unit: '1 kg',
        stock: 25,
        isAvailable: true,
        imageUrl: '',
      ),
      const ProductEntity(
        id: 'prod_wheat_bread',
        storeId: 'store_indiranagar',
        categoryId: 'cat_bakery',
        name: 'The Health Factory Zero Maida Whole Wheat Bread',
        description: '100% whole wheat bread',
        price: 55.0,
        unit: '400g',
        stock: 14,
        isAvailable: true,
        imageUrl: '',
      ),
      const ProductEntity(
        id: 'prod_jaggery',
        storeId: 'store_indiranagar',
        categoryId: 'cat_staples',
        name: 'Organic Tattva Pure Jaggery Powder',
        description: 'Natural sweetener',
        price: 70.0,
        unit: '1 kg',
        stock: 18,
        isAvailable: true,
        imageUrl: '',
      ),
      const ProductEntity(
        id: 'prod_makhana',
        storeId: 'store_indiranagar',
        categoryId: 'cat_snacks',
        name: 'Farmley Roasted Peri Peri Makhana',
        description: 'Foxnuts healthy roasted snack',
        price: 45.0,
        unit: '60g',
        stock: 15,
        isAvailable: true,
        imageUrl: '',
      ),
    ];

    print('🛒 USER CURRENT CART:');
    for (final item in cartItems) {
      print('  • ${item.quantity}x ${item.product.name} (${item.product.unit}) - ₹${item.total}');
    }
    final cartTotal = cartItems.fold(0.0, (acc, c) => acc + c.total);
    print('  ----------------------------------------');
    print('  TOTAL CART VALUE: ₹$cartTotal\n');

    final ragService = CartRagService(
      aiClient: MockLlmClient(),
      retriever: const CatalogRetriever(),
    );

    // TEST 1: User asks AI for "BUDGET SAVER"
    print('----------------------------------------------------------------');
    print('👉 CUSTOMER ACTION: Taps [ 💰 BUDGET SAVER ]');
    print('----------------------------------------------------------------');
    final budgetResult = await ragService.optimizeCart(
      cartItems: cartItems,
      storeCatalog: storeCatalog,
      type: CartOptimizationType.budget,
    );

    print('🤖 AI RAG RESPONSE:');
    print('  Total Savings Available: ₹${budgetResult.totalPotentialSavings.toStringAsFixed(0)}');
    print('  Actionable Swaps:');
    for (var i = 0; i < budgetResult.suggestions.length; i++) {
      final s = budgetResult.suggestions[i];
      print('   [$i] ${s.originalProduct.name} (₹${s.originalProduct.price})');
      print('       ↳ Swap with: ${s.suggestedProduct.name} (₹${s.suggestedProduct.price})');
      print('       💬 AI Reason: "${s.reason}"');
      print('       💰 Customer Saves: ₹${s.totalSavings.toStringAsFixed(0)}');
    }
    print('\n');

    // TEST 2: User asks AI for "HEALTHIER CHOICE"
    print('----------------------------------------------------------------');
    print('👉 CUSTOMER ACTION: Taps [ 🥗 HEALTHIER CHOICE ]');
    print('----------------------------------------------------------------');
    final healthyResult = await ragService.optimizeCart(
      cartItems: cartItems,
      storeCatalog: storeCatalog,
      type: CartOptimizationType.healthy,
    );

    print('🤖 AI RAG RESPONSE:');
    print('  Healthier Swaps Found: ${healthyResult.suggestions.length}');
    print('  Actionable Swaps:');
    for (var i = 0; i < healthyResult.suggestions.length; i++) {
      final s = healthyResult.suggestions[i];
      print('   [$i] ${s.originalProduct.name}');
      print('       ↳ Healthier Choice: ${s.suggestedProduct.name}');
      print('       🏷️ Tag: [${s.healthTag}]');
      print('       🥗 Nutritional Benefit: "${s.reason}"');
    }
    print('================================================================\n');

    expect(budgetResult.hasSuggestions, isTrue);
    expect(healthyResult.hasSuggestions, isTrue);
  });
}
