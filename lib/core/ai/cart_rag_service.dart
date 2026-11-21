import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/customer/domain/entities/cart_item_entity.dart';
import '../../features/customer/domain/entities/cart_optimization_entity.dart';
import '../../features/customer/domain/entities/catalog_entities.dart';
import 'ai_client.dart';
import 'catalog_retriever.dart';

class CartRagService {
  final IAiClient _aiClient;
  final CatalogRetriever _retriever;

  CartRagService({
    IAiClient? aiClient,
    CatalogRetriever? retriever,
  })  : _aiClient = aiClient ?? GroqAiClient(),
        _retriever = retriever ?? const CatalogRetriever();

  /// Optimizes the user's cart using RAG with on-device heuristic fallback.
  Future<CartOptimizationEntity> optimizeCart({
    required List<CartItemEntity> cartItems,
    required List<ProductEntity> storeCatalog,
    required CartOptimizationType type,
  }) async {
    if (cartItems.isEmpty || storeCatalog.isEmpty) {
      return CartOptimizationEntity(
        type: type,
        suggestions: const [],
        totalPotentialSavings: 0.0,
      );
    }

    // Step 1: Retrieval (Filter relevant in-stock products from store)
    final candidates = _retriever.retrieveCandidates(
      cartItems: cartItems,
      storeCatalog: storeCatalog,
    );

    if (candidates.isEmpty) {
      return CartOptimizationEntity(
        type: type,
        suggestions: const [],
        totalPotentialSavings: 0.0,
      );
    }

    // Attempt AI Generation if client is configured
    final aiResult = await _tryAiOptimization(
      cartItems: cartItems,
      candidates: candidates,
      type: type,
    );

    if (aiResult != null && aiResult.hasSuggestions) {
      return aiResult;
    }

    // Step 2 & 3 Fallback: Fast, deterministic on-device heuristic engine
    return _runLocalHeuristicOptimization(
      cartItems: cartItems,
      candidates: candidates,
      type: type,
    );
  }

  /// AI-based RAG optimization using LLM
  Future<CartOptimizationEntity?> _tryAiOptimization({
    required List<CartItemEntity> cartItems,
    required List<ProductEntity> candidates,
    required CartOptimizationType type,
  }) async {
    try {
      final systemPrompt = '''
You are QuickTick's Smart Cart Optimization AI.
Your job is to recommend ${type == CartOptimizationType.budget ? 'cheaper alternative items to save money' : 'healthier alternative items (whole-grain, unrefined, low-sugar, high-fiber)'} strictly from the provided candidate store products.

RULES:
1. ONLY suggest items that exist in the CANDIDATES list. Never invent product IDs.
2. For each recommendation, provide originalProductId, suggestedProductId, savings (per unit), reason (short, max 10 words), and healthTag (e.g. "Zero Maida", "Save ₹30").
3. Output MUST be valid JSON:
{
  "suggestions": [
    {
      "originalProductId": "id_here",
      "suggestedProductId": "id_here",
      "savings": 20.0,
      "reason": "Equivalent quality with lower price",
      "healthTag": "Budget Friendly"
    }
  ]
}
''';

      final userPrompt = '''
CURRENT CART:
${cartItems.map((c) => '{"id": "${c.productId}", "name": "${c.product.name}", "price": ${c.product.price}, "unit": "${c.product.unit}", "qty": ${c.quantity}}').join('\n')}

STORE CANDIDATES:
${candidates.take(25).map((p) => '{"id": "${p.id}", "name": "${p.name}", "price": ${p.price}, "unit": "${p.unit}"}').join('\n')}
''';

      final responseText = await _aiClient.generateCompletion(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      if (responseText == null || responseText.trim().isEmpty) return null;

      final data = json.decode(responseText);
      final rawList = data['suggestions'] as List?;
      if (rawList == null || rawList.isEmpty) return null;

      final productMap = {for (final p in candidates) p.id: p};
      final cartMap = {for (final c in cartItems) c.productId: c};
      final suggestions = <CartSwapSuggestion>[];

      for (final raw in rawList) {
        final origId = raw['originalProductId']?.toString();
        final suggId = raw['suggestedProductId']?.toString();
        if (origId == null || suggId == null) continue;

        final cartItem = cartMap[origId];
        final suggestedProduct = productMap[suggId];
        if (cartItem == null || suggestedProduct == null) continue;

        final rawSavings = raw['savings'];
        final savings = rawSavings is num ? rawSavings.toDouble() : (cartItem.product.price - suggestedProduct.price).clamp(0.0, 9999.0);
        final reason = raw['reason']?.toString() ?? 'Smart alternative';
        final healthTag = raw['healthTag']?.toString();

        suggestions.add(
          CartSwapSuggestion(
            originalProduct: cartItem.product,
            suggestedProduct: suggestedProduct,
            savings: savings,
            reason: reason,
            quantity: cartItem.quantity,
            healthTag: healthTag,
          ),
        );
      }

      if (suggestions.isEmpty) return null;

      final totalSavings = suggestions.fold(0.0, (acc, s) => acc + s.totalSavings);
      return CartOptimizationEntity(
        type: type,
        suggestions: suggestions,
        totalPotentialSavings: totalSavings,
      );
    } catch (e) {
      debugPrint('[CartRagService] AI parsing failed: $e');
      return null;
    }
  }

  /// On-device heuristic engine (Instant, 100% reliable, zero network latency)
  CartOptimizationEntity _runLocalHeuristicOptimization({
    required List<CartItemEntity> cartItems,
    required List<ProductEntity> candidates,
    required CartOptimizationType type,
  }) {
    final suggestions = <CartSwapSuggestion>[];

    if (type == CartOptimizationType.budget) {
      for (final cartItem in cartItems) {
        final orig = cartItem.product;
        final origWeight = CatalogRetriever.parseUnitWeightInGramsOrMl(orig.unit);

        // Find cheaper item in same category with comparable or higher volume
        ProductEntity? bestAlternative;
        double maxSaving = 0.0;

        for (final candidate in candidates) {
          if (candidate.categoryId != orig.categoryId) continue;
          if (candidate.price >= orig.price) continue;

          final candWeight = CatalogRetriever.parseUnitWeightInGramsOrMl(candidate.unit);
          // If candidate is within 80% of original weight or higher
          if (candWeight >= origWeight * 0.8) {
            final saving = orig.price - candidate.price;
            if (saving > maxSaving) {
              maxSaving = saving;
              bestAlternative = candidate;
            }
          }
        }

        if (bestAlternative != null && maxSaving > 0) {
          suggestions.add(
            CartSwapSuggestion(
              originalProduct: orig,
              suggestedProduct: bestAlternative,
              savings: maxSaving,
              reason: 'Save ₹${maxSaving.toStringAsFixed(0)} with similar ${bestAlternative.unit}',
              quantity: cartItem.quantity,
              healthTag: 'Save ₹${maxSaving.toStringAsFixed(0)}',
            ),
          );
        }
      }
    } else {
      // Healthy Mode
      for (final cartItem in cartItems) {
        final orig = cartItem.product;
        final origNameLower = orig.name.toLowerCase();

        final match = _findHealthyAlternative(origNameLower, orig.categoryId, candidates);
        if (match != null) {
          final saving = (orig.price - match.product.price).clamp(0.0, 9999.0);
          suggestions.add(
            CartSwapSuggestion(
              originalProduct: orig,
              suggestedProduct: match.product,
              savings: saving,
              reason: match.reason,
              quantity: cartItem.quantity,
              healthTag: match.tag,
            ),
          );
        }
      }
    }

    final totalSavings = suggestions.fold(0.0, (acc, s) => acc + s.totalSavings);

    return CartOptimizationEntity(
      type: type,
      suggestions: suggestions,
      totalPotentialSavings: totalSavings,
    );
  }

  _HealthyMatch? _findHealthyAlternative(String origName, String categoryId, List<ProductEntity> candidates) {
    // 1. White Bread -> Brown / Whole Wheat / Multigrain
    if (origName.contains('white bread') || origName.contains('sandwich bread')) {
      final cand = candidates.firstWhere(
        (p) {
          final n = p.name.toLowerCase();
          return n.contains('brown bread') || n.contains('wheat bread') || n.contains('multigrain') || n.contains('atta bread');
        },
        orElse: () => candidates.firstWhere((p) => p.name.toLowerCase().contains('bread'), orElse: () => candidates.first),
      );
      if (cand != candidates.first || cand.name.toLowerCase().contains('wheat') || cand.name.toLowerCase().contains('brown')) {
        return _HealthyMatch(cand, 'Zero maida, high dietary fiber for digestion', 'High Fiber');
      }
    }

    // 2. Refined Sugar -> Jaggery / Brown Sugar
    if (origName.contains('white sugar') || (origName.contains('sugar') && !origName.contains('jaggery') && !origName.contains('brown'))) {
      final cand = candidates.firstWhere(
        (p) {
          final n = p.name.toLowerCase();
          return n.contains('jaggery') || n.contains('brown sugar') || n.contains('gur');
        },
        orElse: () => candidates.first,
      );
      if (cand.name.toLowerCase().contains('jaggery') || cand.name.toLowerCase().contains('brown sugar') || cand.name.toLowerCase().contains('gur')) {
        return _HealthyMatch(cand, 'Unrefined natural minerals, avoids blood sugar spikes', 'Unrefined Minerals');
      }
    }

    // 3. Fried Chips / Snacks -> Roasted / Makhana / Dry Fruits
    if (origName.contains('chips') || origName.contains('kurkure') || origName.contains('fried')) {
      final cand = candidates.firstWhere(
        (p) {
          final n = p.name.toLowerCase();
          return n.contains('makhana') || n.contains('roasted') || n.contains('nuts') || n.contains('almond');
        },
        orElse: () => candidates.first,
      );
      if (cand.name.toLowerCase().contains('makhana') || cand.name.toLowerCase().contains('roasted') || cand.name.toLowerCase().contains('nuts')) {
        return _HealthyMatch(cand, 'Roasted, non-fried with high protein and zero trans fats', 'Non-Fried');
      }
    }

    // 4. Maida -> Atta / Millets
    if (origName.contains('maida') || origName.contains('refined flour')) {
      final cand = candidates.firstWhere(
        (p) {
          final n = p.name.toLowerCase();
          return n.contains('atta') || n.contains('ragi') || n.contains('millet') || n.contains('wheat');
        },
        orElse: () => candidates.first,
      );
      if (cand.name.toLowerCase().contains('atta') || cand.name.toLowerCase().contains('ragi') || cand.name.toLowerCase().contains('millet')) {
        return _HealthyMatch(cand, 'Whole grain flour rich in complex carbohydrates', 'Whole Grain');
      }
    }

    // 5. Sugary Soda / Carbonated drinks -> Tender Coconut / Natural Juice
    if (origName.contains('cola') || origName.contains('pepsi') || origName.contains('soda') || origName.contains('sprite')) {
      final cand = candidates.firstWhere(
        (p) {
          final n = p.name.toLowerCase();
          return n.contains('coconut') || n.contains('green tea') || n.contains('fruit juice') || n.contains('tender');
        },
        orElse: () => candidates.first,
      );
      if (cand.name.toLowerCase().contains('coconut') || cand.name.toLowerCase().contains('green tea') || cand.name.toLowerCase().contains('juice')) {
        return _HealthyMatch(cand, 'Natural electrolytes, zero artificial preservatives', 'Natural Hydration');
      }
    }

    return null;
  }
}

class _HealthyMatch {
  final ProductEntity product;
  final String reason;
  final String tag;

  _HealthyMatch(this.product, this.reason, this.tag);
}

