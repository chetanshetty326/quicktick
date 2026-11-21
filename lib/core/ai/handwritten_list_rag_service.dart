import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../features/customer/domain/entities/catalog_entities.dart';
import '../../features/customer/domain/entities/handwritten_item_match_entity.dart';
import '../security/secure_storage_service.dart';
import '../utils/product_matcher.dart';

/// Service that transcribes handwritten grocery lists using Multimodal Vision AI
/// and uses RAG (Retrieval-Augmented Generation) against the store catalog to
/// resolve exact in-stock SKUs, package sizes, and quantities.
class HandwrittenListRagService {
  final Dio _dio;
  final ISecureStorageService? _secureStorage;

  static const String _envGroqKey = String.fromEnvironment('GROQ_API_KEY');

  HandwrittenListRagService({
    Dio? dio,
    ISecureStorageService? secureStorage,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            )),
        _secureStorage = secureStorage;

  /// Analyzes an image of a handwritten grocery note and matches items against [storeCatalog].
  Future<HandwrittenListScanResultEntity> processHandwrittenList({
    required Uint8List imageBytes,
    String? imagePath,
    required List<ProductEntity> storeCatalog,
  }) async {
    // 1. Obtain active API key
    String apiKey = _envGroqKey;
    if (_secureStorage != null) {
      try {
        final userData = await _secureStorage.getUserData();
        final storedKey = userData['groq_api_key'];
        if (storedKey != null && storedKey.toString().isNotEmpty) {
          apiKey = storedKey.toString();
        }
      } catch (_) {}
    }

    // 2. Extract item lines and quantities from handwritten image via Vision AI
    List<Map<String, dynamic>> extractedItems = [];
    if (apiKey.isNotEmpty && imageBytes.isNotEmpty) {
      extractedItems = await _callVisionApi(apiKey, imageBytes);
    }

    // 3. Fallback: If Vision API returned empty or failed (e.g. offline/mock testing)
    if (extractedItems.isEmpty) {
      extractedItems = _fallbackItemExtractor(imageBytes);
    }

    // 4. RAG Entity Resolution: Match each detected item against store catalog
    final List<HandwrittenItemMatchEntity> matches = [];

    for (final raw in extractedItems) {
      final rawText = (raw['raw'] ?? raw['item'] ?? '').toString().trim();
      final itemName = (raw['item'] ?? rawText).toString().trim();
      if (rawText.isEmpty && itemName.isEmpty) continue;

      int qty = 1;
      if (raw['quantity'] != null) {
        if (raw['quantity'] is num) {
          qty = (raw['quantity'] as num).toInt();
        } else {
          qty = int.tryParse(raw['quantity'].toString()) ?? 1;
        }
      }
      if (qty < 1) qty = 1;

      final detectedUnit = raw['unit']?.toString();

      // RAG Retrieval: Look up in-stock candidates from the store catalog
      ProductEntity? matchedProduct = ProductMatcher.findBestMatch(storeCatalog, itemName);

      // If clean name didn't match, attempt search with rawText
      if (matchedProduct == null && rawText != itemName) {
        matchedProduct = ProductMatcher.findBestMatch(storeCatalog, rawText);
      }

      // If quantity is higher than stock, clamp to available stock
      if (matchedProduct != null && matchedProduct.stock > 0 && qty > matchedProduct.stock) {
        qty = matchedProduct.stock;
      }

      final isAvailable = matchedProduct != null && matchedProduct.isAvailable && matchedProduct.stock > 0;

      matches.add(HandwrittenItemMatchEntity(
        rawText: rawText.isNotEmpty ? rawText : itemName,
        itemName: itemName,
        quantity: qty,
        detectedUnit: detectedUnit,
        matchedProduct: matchedProduct,
        matchScore: isAvailable ? 0.95 : (matchedProduct != null ? 0.4 : 0.0),
        isSelected: isAvailable, // Pre-select only in-stock items
        statusNote: isAvailable
            ? 'In Stock · Exact Match'
            : (matchedProduct != null ? 'Temporarily Out of Stock' : 'Not available at this store'),
      ));
    }

    return HandwrittenListScanResultEntity(
      matches: matches,
      imagePath: imagePath,
      scannedAt: DateTime.now(),
    );
  }

  /// Calls Groq Vision models (llama-3.2-11b-vision-preview / llama-3.2-90b-vision-preview)
  Future<List<Map<String, dynamic>>> _callVisionApi(String apiKey, Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    // Detect image mime type from header magic numbers
    String mimeType = 'image/jpeg';
    if (imageBytes.length >= 8 &&
        imageBytes[0] == 0x89 &&
        imageBytes[1] == 0x50 &&
        imageBytes[2] == 0x4E &&
        imageBytes[3] == 0x47) {
      mimeType = 'image/png';
    }

    const systemPrompt = '''
You are QuickTick's Precision Grocery OCR & Assistant.
Your task is to analyze the provided image of a handwritten grocery shopping list or note.
Transcribe each handwritten item along with its specified quantity and unit.
Understand colloquial and Indian grocery terms (e.g., "doodh 1 pkt", "atta 5kg", "haalu", "bellam 1kg", "curd 500g", "eggs 6 nos", "bread", "maggi 4 pack").

OUTPUT FORMAT:
Return strictly a valid JSON object with an "items" array. No explanations, no markdown codeblocks, no chat.
Example:
{
  "items": [
    {"raw": "Nandini blue milk 1 pkt", "item": "Nandini blue milk", "quantity": 1, "unit": "pkt"},
    {"raw": "Aashirvaad atta 5kg", "item": "Aashirvaad atta", "quantity": 1, "unit": "5kg"},
    {"raw": "Tata salt", "item": "Tata salt", "quantity": 1, "unit": "1kg"}
  ]
}
''';

    for (final model in ['llama-3.2-11b-vision-preview', 'llama-3.2-90b-vision-preview']) {
      try {
        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
          ),
          data: {
            'model': model,
            'temperature': 0.1,
            'max_tokens': 500,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'text',
                    'text': systemPrompt,
                  },
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:$mimeType;base64,$base64Image',
                    },
                  },
                ],
              },
            ],
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final content = response.data['choices']?[0]?['message']?['content']?.toString() ?? '';
          if (content.isNotEmpty) {
            final parsed = _parseJsonContent(content);
            if (parsed.isNotEmpty) return parsed;
          }
        }
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  /// Extracts the JSON array from LLM response safely
  List<Map<String, dynamic>> _parseJsonContent(String rawContent) {
    try {
      var cleaned = rawContent.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final decoded = jsonDecode(cleaned);
      if (decoded is Map && decoded['items'] is List) {
        return (decoded['items'] as List).whereType<Map<String, dynamic>>().toList();
      } else if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  /// Deterministic local fallback if image API cannot be reached
  List<Map<String, dynamic>> _fallbackItemExtractor(Uint8List imageBytes) {
    // If the image cannot be processed remotely, return empty list so the UI can inform the user
    return [];
  }
}

