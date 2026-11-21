import '../../features/customer/domain/entities/catalog_entities.dart';

/// Shared helper for matching natural-language grocery item names (e.g., "2 kg tomatoes", "1L milk")
/// against catalog [ProductEntity] items cleanly without duplicating logic across UI and AI Assistant.
class ProductMatcher {
  ProductMatcher._();

  static final RegExp _quantityPrefixRegex = RegExp(
    r'^\s*\d+(?:\.\d+)?\s*(?:kg|kgs|g|gm|gms|grams|gram|l|ltr|litre|litres|ml|pcs|pc|pack|packs|packet|packets|bottle|bottles|box|boxes|dozen|x)?\b\s*',
    caseSensitive: false,
  );

  static const Set<String> _fillerWords = {
    'a',
    'an',
    'the',
    'of',
    'some',
    'few',
    'one',
    'two',
    'three',
    'packet',
    'packets',
    'bottle',
    'bottles',
    'kg',
    'gram',
    'grams',
    'litre',
    'litres',
  };

  /// Strips leading quantities/units and normalizes whitespace.
  static String normalizeQuery(String raw) {
    var q = raw.trim().toLowerCase();
    q = q.replaceAll(_quantityPrefixRegex, '').trim();
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final filtered = tokens.where((t) => !_fillerWords.contains(t)).toList();
    return (filtered.isNotEmpty ? filtered : tokens).join(' ').trim();
  }

  /// Basic English singularization for grocery items (e.g., tomatoes -> tomato, eggs -> egg).
  static String singularize(String word) {
    final w = word.trim().toLowerCase();
    if (w.length <= 3) return w;
    if (w.endsWith('ies') && w.length > 4) {
      return '${w.substring(0, w.length - 3)}y';
    }
    if (w.endsWith('oes') && w.length > 4) {
      return w.substring(0, w.length - 2);
    }
    if (w.endsWith('s') && !w.endsWith('ss') && !w.endsWith('us') && !w.endsWith('is')) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  static List<String> _buildVariants(String raw) {
    final normalized = normalizeQuery(raw);
    if (normalized.isEmpty) return const [];

    final variants = <String>{normalized};
    final singularPhrase = normalized.split(RegExp(r'\s+')).map(singularize).join(' ');
    if (singularPhrase.isNotEmpty) {
      variants.add(singularPhrase);
    }

    for (final token in normalized.split(RegExp(r'\s+'))) {
      if (token.length >= 3) {
        variants.add(token);
        final s = singularize(token);
        if (s.length >= 3) variants.add(s);
      }
    }
    return variants.toList();
  }

  /// Returns matching products ordered by match strength and availability.
  static List<ProductEntity> findMatches(
    List<ProductEntity> products,
    String rawQuery, {
    int limit = 4,
  }) {
    final variants = _buildVariants(rawQuery);
    if (variants.isEmpty || products.isEmpty) return const [];

    final primary = variants.first;
    final singularPrimary = variants.length > 1 ? variants[1] : primary;

    final scored = <(ProductEntity product, int score)>[];
    for (final p in products) {
      final name = p.name.toLowerCase();
      final cat = (p.categoryName ?? '').toLowerCase();
      final inStock = p.stock > 0 && p.isAvailable;

      int score = 0;
      if (name == primary || name == singularPrimary) {
        score = 100;
      } else if (name.startsWith(primary) || name.startsWith(singularPrimary)) {
        score = 85;
      } else if (name.contains(primary) || name.contains(singularPrimary)) {
        score = 75;
      } else {
        for (final v in variants.skip(2)) {
          if (name.contains(v)) {
            score = 50;
            break;
          }
          if (cat.contains(v)) {
            score = 30;
          }
        }
      }

      if (score > 0) {
        // Prefer available, in-stock items over out-of-stock ones
        if (inStock) score += 20;
        scored.add((p, score));
      }
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final seenIds = <String>{};
    final results = <ProductEntity>[];
    for (final entry in scored) {
      if (seenIds.add(entry.$1.id)) {
        results.add(entry.$1);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  /// Returns the single best matching product (preferring in-stock), or null.
  static ProductEntity? findBestMatch(List<ProductEntity> products, String rawQuery) {
    final matches = findMatches(products, rawQuery, limit: 1);
    return matches.isNotEmpty ? matches.first : null;
  }
}

