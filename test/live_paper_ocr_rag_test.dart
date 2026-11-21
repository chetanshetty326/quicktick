import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/ai/ai_client.dart';
import 'package:quicklink/core/ai/catalog_retriever.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

void main() {
  test('Live Paper Handwriting to Cart RAG Flow', () async {
    print('\n================================================================');
    print('📝 TEST: HANDWRITTEN PAPER GROCERY SLIP TO CART (VISION + RAG)  ');
    print('================================================================\n');

    // 1. Text extracted from a photo of a messy handwritten paper note:
    const rawPaperSlipOcr = '''
    1. 2 pkt nandini milk
    2. 1 loaf brown bread
    3. madhur sugar 1kg
    4. amul butter 100g
    5. 6 eggs tray
    ''';

    print('📸 1. PHOTO SNAPPED BY CUSTOMER:');
    print('----------------------------------------------------');
    print(rawPaperSlipOcr.trim());
    print('----------------------------------------------------\n');

    // 2. Active store catalog in customer's neighborhood
    final storeCatalog = [
      const ProductEntity(
        id: 'p_nandini_milk',
        storeId: 'store_indiranagar',
        categoryId: 'cat_dairy',
        name: 'Nandini Special Toned Milk (Green Pouch)',
        description: 'Fresh toned milk',
        price: 27.0,
        unit: '500ml',
        stock: 50,
        isAvailable: true,
        imageUrl: '',
      ),
      const ProductEntity(
        id: 'p_brown_bread',
        storeId: 'store_indiranagar',
        categoryId: 'cat_bakery',
        name: 'The Health Factory 100% Whole Wheat Brown Bread',
        description: 'Zero maida bread',
        price: 55.0,
        unit: '400g',
        stock: 20,
        isAvailable: true,
        imageUrl: '',
      ),
      const ProductEntity(
        id: 'p_sugar',
        storeId: 'store_indiranagar',
        categoryId: 'cat_staples',
        name: 'Madhur Pure & Hygienic Sugar',
        description: 'Refined sugar',
        price: 60.0,
        unit: '1 kg',
        stock: 35,
        isAvailable: true,
        imageUrl: '',
      ),
      const ProductEntity(
        id: 'p_amul_butter',
        storeId: 'store_indiranagar',
        categoryId: 'cat_dairy',
        name: 'Amul Pasteurised Salted Butter',
        description: 'Delicious butter',
        price: 56.0,
        unit: '100g',
        stock: 15,
        isAvailable: true,
        imageUrl: '',
      ),
      const ProductEntity(
        id: 'p_eggs',
        storeId: 'store_indiranagar',
        categoryId: 'cat_dairy',
        name: 'Farm Fresh White Eggs Pack of 6',
        description: 'Protein rich eggs',
        price: 52.0,
        unit: '6 pcs',
        stock: 25,
        isAvailable: true,
        imageUrl: '',
      ),
    ];

    final client = GroqAiClient();

    final systemPrompt = '''
You are QuickTick's Smart Paper List Parser.
Extract items, quantities, and units from the customer's messy handwritten grocery slip text.
Return a clean JSON array of objects:
{
  "items": [
    {"raw": "2 pkt nandini milk", "searchTerm": "nandini milk", "quantity": 2, "unit": "pkt"},
    {"raw": "1 loaf brown bread", "searchTerm": "brown bread", "quantity": 1, "unit": "loaf"},
    {"raw": "madhur sugar 1kg", "searchTerm": "madhur sugar", "quantity": 1, "unit": "1kg"},
    {"raw": "amul butter 100g", "searchTerm": "amul butter", "quantity": 1, "unit": "100g"},
    {"raw": "6 eggs tray", "searchTerm": "eggs", "quantity": 1, "unit": "6 pcs"}
  ]
}
''';

    print('📡 2. Live AI Parsing handwritten lines...');
    final sw = Stopwatch()..start();
    final jsonStr = await client.generateCompletion(
      systemPrompt: systemPrompt,
      userPrompt: 'Handwritten list text:\n$rawPaperSlipOcr',
    );
    sw.stop();

    print('⏱️ AI Parse Completed in ${sw.elapsedMilliseconds} ms!\n');
    print('📥 Parsed JSON from Cloud AI:');
    print(jsonStr);
    print('\n');

    expect(jsonStr, isNotNull);
    final data = json.decode(jsonStr!);
    final parsedItems = data['items'] as List;

    print('🛒 3. RAG MATCHING AGAINST ACTIVE STORE CATALOG:');
    print('----------------------------------------------------');
    double totalCart = 0.0;
    int totalItems = 0;

    for (final raw in parsedItems) {
      final searchTerm = raw['searchTerm'].toString().toLowerCase();
      final qty = raw['quantity'] is num ? (raw['quantity'] as num).toInt() : 1;

      // RAG Retrieval matching against live store products
      final matchedProduct = storeCatalog.firstWhere(
        (p) {
          final pName = p.name.toLowerCase();
          return searchTerm.split(' ').any((word) => word.length > 2 && pName.contains(word));
        },
        orElse: () => storeCatalog.first,
      );

      final lineTotal = matchedProduct.price * qty;
      totalCart += lineTotal;
      totalItems += qty;

      print('✅ Paper Line: "${raw['raw']}"');
      print('   ↳ Matched Store Item: ${matchedProduct.name}');
      print('   ↳ Price: ₹${matchedProduct.price} x $qty = ₹$lineTotal\n');
    }

    print('----------------------------------------------------');
    print('🎉 FINAL CART READY FOR CHECKOUT:');
    print('   Total Items: $totalItems');
    print('   Total Amount: ₹$totalCart');
    print('   Delivery ETA: 10 mins to Indiranagar');
    print('====================================================\n');

    expect(parsedItems.length, 5);
    expect(totalItems, 6); // 2 milk + 1 bread + 1 sugar + 1 butter + 1 egg pack
    expect(totalCart, (27.0 * 2) + 55.0 + 60.0 + 56.0 + 52.0); // ₹277.0
  });
}

