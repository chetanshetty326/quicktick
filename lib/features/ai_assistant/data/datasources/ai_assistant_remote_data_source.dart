import 'package:dio/dio.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/ai_message_entity.dart';

abstract class IAiAssistantRemoteDataSource {
  Future<AiMessageEntity> queryAssistant({
    required String prompt,
    required String languageCode,
    String? customerName,
    String? currentCartSummary,
    String? activeOrderStatus,
  });
}

class GroqAiRemoteDataSourceImpl implements IAiAssistantRemoteDataSource {
  final Dio _dio;
  final ISecureStorageService _secureStorage;

  // Key injected at compile-time via --dart-define=GROQ_API_KEY=... or fallback to secure storage
  static const String _envGroqKey = String.fromEnvironment('GROQ_API_KEY');

  GroqAiRemoteDataSourceImpl({
    Dio? dio,
    required ISecureStorageService secureStorage,
  })  : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 12))),
        _secureStorage = secureStorage;

  @override
  Future<AiMessageEntity> queryAssistant({
    required String prompt,
    required String languageCode,
    String? customerName,
    String? currentCartSummary,
    String? activeOrderStatus,
  }) async {
    // 1. Check for Groq API key
    String activeKey = _envGroqKey;
    if (activeKey.isEmpty) {
      try {
        final userData = await _secureStorage.getUserData();
        final storedKey = userData['groq_api_key'];
        if (storedKey != null && storedKey.isNotEmpty) {
          activeKey = storedKey;
        }
      } catch (_) {}
    }

    // 2. If API key is available, call Groq for real-time conversational response
    if (activeKey.isNotEmpty) {
      for (final modelName in ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant']) {
        try {
          final response = await _dio.post(
            'https://api.groq.com/openai/v1/chat/completions',
            options: Options(
              headers: {
                'Authorization': 'Bearer $activeKey',
                'Content-Type': 'application/json',
              },
            ),
            data: {
              'model': modelName,
              'temperature': 0.6,
              'max_tokens': 350,
              'messages': [
                {
                  'role': 'system',
                  'content': _buildSystemPrompt(
                    languageCode: languageCode,
                    customerName: customerName,
                    cartSummary: currentCartSummary,
                    orderStatus: activeOrderStatus,
                  ),
                },
                {
                  'role': 'user',
                  'content': prompt,
                },
              ],
            },
          );

          if (response.statusCode == 200 && response.data != null) {
            final content = response.data['choices']?[0]?['message']?['content']?.toString() ?? '';
            if (content.isNotEmpty) {
              return _parseAiResponse(
                content,
                languageCode: languageCode,
                userPrompt: prompt,
              );
            }
          }
        } catch (_) {
          // If this model is unavailable on the account, try the next model
          continue;
        }
      }
    }

    // 3. Fallback Smart Intent Engine (100% Free, Zero Key, Completely Offline)
    return _smartLocalResponse(
      prompt: prompt,
      languageCode: languageCode,
      customerName: customerName,
      cartSummary: currentCartSummary,
      orderStatus: activeOrderStatus,
    );
  }

  String _buildSystemPrompt({
    required String languageCode,
    String? customerName,
    String? cartSummary,
    String? orderStatus,
  }) {
    final name = customerName?.isNotEmpty == true ? customerName : 'customer';
    final langInstruction = _getLanguageInstruction(languageCode);

    return '''
You are "QuickTick AI Concierge", a warm, helpful, and ultra-fast grocery shopping and customer support assistant for QuickTick delivery app.
Customer Name: $name.
Active Order Status: ${orderStatus ?? 'No active orders'}.
Current Cart: ${cartSummary ?? 'Cart is empty'}.

Rules:
1. $langInstruction
2. Keep replies concise, helpful, and conversational.
3. If the user wants to search an item, append [ACTION:SEARCH|item_name].
4. If the user wants to add items, append [ACTION:ADD_CART|item1,item2].
5. If the user asks about order status or delivery, append [ACTION:TRACK_ORDER].
6. If the user asks about offers or discounts, append [ACTION:COUPONS].
7. If the customer reports an issue, complains about an incorrect answer, or asks for support/refunds, append [ACTION:SUPPORT] and state: "If any response is incorrect, please contact QuickTick Customer Support." (translated to the user's language).
8. If the user asks about product stock or availability (e.g. "is milk in stock", "how many eggs left"), append [ACTION:STOCK|item_name].
9. If the user asks about payment status, transaction details, or payment confirmation, append [ACTION:PAYMENT_STATUS].
10. If the user asks for a recipe or cooking ingredients/steps, explain the recipe clearly with prep time, cook time, and step-by-step instructions, and append [ACTION:RECIPE|DishName|item1,item2,...].
11. Never ask for passwords, OTP, or payment card details.
''';
  }

  String _getLanguageInstruction(String code) {
    switch (code.toLowerCase()) {
      case 'kn':
      case 'kn_in':
        return 'Respond naturally in Kannada (ಕನ್ನಡ). Use friendly Bangalore conversational style.';
      case 'hi':
      case 'hi_in':
        return 'Respond naturally in Hindi (हिंदी / Hinglish). Friendly and polite.';
      case 'ta':
      case 'ta_in':
        return 'Respond naturally in Tamil (தமிழ்). Friendly and helpful.';
      case 'te':
      case 'te_in':
        return 'Respond naturally in Telugu (తెలుగు). Friendly and helpful.';
      default:
        return 'Respond in polite and friendly Indian English.';
    }
  }

  bool _isAddToCartIntent(String rawPrompt) {
    final lower = rawPrompt.toLowerCase().trim();
    if (lower.contains('cart') ||
        lower.contains('ಕಾರ್ಟ್') ||
        lower.contains('कार्ट') ||
        RegExp(r'\b(add|put)\b').hasMatch(lower) ||
        RegExp(r'\bbuy\b').hasMatch(lower) ||
        lower.contains('ಸೇರಿಸಿ') ||
        lower.contains('जोड़ें')) {
      // Avoid hijacking order status queries unless explicitly mentioning cart/add
      if ((lower.contains('order status') || lower.contains('track')) &&
          !lower.contains('cart') &&
          !lower.contains('add')) {
        return false;
      }
      return true;
    }
    return false;
  }

  List<String> _extractCartItems(String rawPrompt) {
    var text = rawPrompt.toLowerCase().trim();
    // Remove conversational wrappers in English, Kannada, and Hindi
    text = text.replaceAll(
      RegExp(
        r'\b(please|can you|could you|hey|quicktick|add|put|into|to|in|my|the|cart|buy|want|need|get|me|some|items|item|it|this|that|now|for)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text
        .replaceAll('ಕಾರ್ಟ್‌ಗೆ', ' ')
        .replaceAll('ಕಾರ್ಟ್', ' ')
        .replaceAll('ಸೇರಿಸಿ', ' ')
        .replaceAll('कार्ट में', ' ')
        .replaceAll('कार्ट', ' ')
        .replaceAll('जोड़ें', ' ');

    // Split multiple items cleanly
    final rawParts = text.split(RegExp(r'(?:,|\band\b|&|\+|ಮತ್ತು|ಮತ್ತೆ|और)'));
    final items = <String>[];
    for (final part in rawParts) {
      final cleaned = part.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.length >= 2) {
        items.add(cleaned);
      }
    }
    return items;
  }

  AiMessageEntity _parseAiResponse(
    String rawContent, {
    required String languageCode,
    String userPrompt = '',
  }) {
    AiActionIntent intent = const AiActionIntent(type: AiActionType.none);
    RecipeDetails? parsedRecipe;
    // Strip hidden reasoning tags if a model emits them
    String cleanedText = rawContent
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .trim();

    final actionRegex = RegExp(
      r'\[\s*ACTION\s*:\s*([A-Za-z_]+)\s*(?:\|\s*([^\]]*))?\s*\]',
      caseSensitive: false,
    );
    final match = actionRegex.firstMatch(cleanedText);

    if (match != null) {
      final actionTypeStr = (match.group(1) ?? '').trim().toUpperCase();
      final payload = match.group(2)?.trim();
      cleanedText = cleanedText.replaceAll(match.group(0)!, '').trim();

      switch (actionTypeStr) {
        case 'SEARCH':
          intent = AiActionIntent(type: AiActionType.searchProduct, query: payload);
          break;
        case 'ADD_CART':
          final items = (payload != null && payload.isNotEmpty)
              ? payload.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
              : _extractCartItems(userPrompt);
          intent = AiActionIntent(
            type: AiActionType.addItemsToCart,
            itemNames: items,
            query: items.join(', '),
          );
          break;
        case 'TRACK_ORDER':
          intent = const AiActionIntent(type: AiActionType.trackOrder);
          break;
        case 'COUPONS':
          intent = const AiActionIntent(type: AiActionType.viewCoupons);
          break;
        case 'SUPPORT':
          intent = const AiActionIntent(type: AiActionType.customerSupport);
          break;
        case 'STOCK':
          intent = AiActionIntent(type: AiActionType.checkStock, stockItemQuery: payload, query: payload);
          break;
        case 'PAYMENT_STATUS':
          intent = const AiActionIntent(type: AiActionType.paymentStatus);
          break;
        case 'RECIPE':
          final parts = payload != null ? payload.split('|') : <String>[];
          final dishName = parts.isNotEmpty ? parts[0].trim() : 'Recipe';
          final items = parts.length > 1
              ? parts[1].split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
              : <String>[];
          parsedRecipe = _getRecipeForDish(dishName, languageCode);
          final finalItems = items.isNotEmpty
              ? items
              : parsedRecipe.ingredients.map((e) => e.matchedQuery ?? e.name).toList();
          intent = AiActionIntent(
            type: AiActionType.recipeGuide,
            recipeDetails: parsedRecipe,
            itemNames: finalItems,
          );
          break;
        default:
          intent = const AiActionIntent(type: AiActionType.none);
      }
    }

    // Safety promotion: if the customer explicitly asked to add to cart, ensure ADD_CART intent fires
    // even if the LLM emitted SEARCH or omitted the [ACTION:ADD_CART] tag.
    if (userPrompt.isNotEmpty &&
        _isAddToCartIntent(userPrompt) &&
        (intent.type == AiActionType.none || intent.type == AiActionType.searchProduct)) {
      final extracted = _extractCartItems(userPrompt);
      final fallbackItems = extracted.isNotEmpty
          ? extracted
          : (intent.query != null && intent.query!.trim().isNotEmpty ? [intent.query!.trim()] : <String>[]);
      intent = AiActionIntent(
        type: AiActionType.addItemsToCart,
        itemNames: fallbackItems,
        query: fallbackItems.join(', '),
      );
    }

    return AiMessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: cleanedText,
      sender: AiSender.assistant,
      timestamp: DateTime.now(),
      actionIntent: intent,
      languageCode: languageCode,
      recipeDetails: parsedRecipe,
      suggestions: _getDefaultSuggestions(languageCode),
    );
  }

  AiMessageEntity _smartLocalResponse({
    required String prompt,
    required String languageCode,
    String? customerName,
    String? cartSummary,
    String? orderStatus,
  }) {
    final lower = prompt.toLowerCase().trim();
    final name = customerName?.isNotEmpty == true ? customerName! : '';
    final isKannada = languageCode.startsWith('kn');
    final isHindi = languageCode.startsWith('hi');

    // 1. Stock / Inventory Details Check
    if (lower.contains('stock') || lower.contains('available') || lower.contains('how many') ||
        lower.contains('units left') || lower.contains('quantity') || lower.contains('yestide') ||
        lower.contains('kitna') || lower.contains('bacha')) {
      final item = _extractProductQuery(lower);
      final text = isKannada
          ? '$item ಲೈವ್ ಸ್ಟಾಕ್ ಮತ್ತು ಲಭ್ಯತೆಯ ವಿವರಗಳನ್ನು ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ.'
          : (isHindi
              ? '$item का लाइव स्टॉक और उपलब्धता विवरण चेक किया जा रहा है।'
              : 'Checking live inventory and stock availability for $item.');
      return AiMessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: AiSender.assistant,
        timestamp: DateTime.now(),
        actionIntent: AiActionIntent(
          type: AiActionType.checkStock,
          stockItemQuery: item,
          query: item,
        ),
        languageCode: languageCode,
        suggestions: _getDefaultSuggestions(languageCode),
      );
    }

    // 2. Payment Status & Transaction Update
    if (lower.contains('payment') || lower.contains('paid') || lower.contains('refund') ||
        lower.contains('transaction') || lower.contains('upi') || lower.contains('cod') ||
        lower.contains('paise') || lower.contains('hana') || lower.contains('failed payment')) {
      final text = isKannada
          ? 'ನಿಮ್ಮ ಇತ್ತೀಚಿನ ಆರ್ಡರ್ ಪಾವತಿ ಸ್ಥಿತಿಯನ್ನು ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ.'
          : (isHindi
              ? 'आपके हाल के ऑर्डर का पेमेंट स्टेटस और ट्रांजेक्शन विवरण दिखाया जा रहा है।'
              : 'Checking live payment status and transaction details for your recent order.');
      return AiMessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: AiSender.assistant,
        timestamp: DateTime.now(),
        actionIntent: const AiActionIntent(type: AiActionType.paymentStatus),
        languageCode: languageCode,
        suggestions: _getDefaultSuggestions(languageCode),
      );
    }

    // 3. Recipes / Meal Planning & Cooking Guide (Advanced with animations & ingredients)
    if (lower.contains('recipe') || lower.contains('how to make') || lower.contains('how to cook') ||
        lower.contains('madodu hege') || lower.contains('kaise banaye') || lower.contains('dish') ||
        lower.contains('biryani') || lower.contains('paneer') || lower.contains('chai') ||
        lower.contains('tea') || lower.contains('pasta') || lower.contains('maggi') ||
        lower.contains('dosa') || lower.contains('curry') || lower.contains('dal')) {
      final recipe = _getRecipeForDish(lower, languageCode);
      final itemNames = recipe.ingredients.map((e) => e.matchedQuery ?? e.name).toList();

      final text = isKannada
          ? '${recipe.title} ಮಾಡುವ ವಿಧಾನ ಮತ್ತು ಬೇಕಾಗುವ ಎಲ್ಲಾ ತಾಜಾ ಸಾಮಗ್ರಿಗಳು ಸಿದ್ಧವಾಗಿವೆ. ಕಾರ್ಟ್‌ಗೆ ಸೇರಿಸಲು ಕೆಳಗಿನ ಬಟನ್ ಒತ್ತಿ!'
          : (isHindi
              ? '${recipe.title} की स्वादिष्ट रेसिपी और सभी जरूरी सामग्री तैयार हैं। एक क्लिक में सभी सामग्री कार्ट में जोड़ें!'
              : 'Here is the step-by-step master recipe for ${recipe.title}! You can add all fresh ingredients directly to your cart below.');

      return AiMessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: AiSender.assistant,
        timestamp: DateTime.now(),
        actionIntent: AiActionIntent(
          type: AiActionType.recipeGuide,
          recipeDetails: recipe,
          itemNames: itemNames,
        ),
        recipeDetails: recipe,
        languageCode: languageCode,
        suggestions: _getDefaultSuggestions(languageCode),
      );
    }

    // 4. Order Tracking / Delivery
    if (lower.contains('order') || lower.contains('delivery') || lower.contains('track') ||
        lower.contains('elli') || lower.contains('kahan') || lower.contains('arriving')) {
      final text = isKannada
          ? 'ನಿಮ್ಮ ಆರ್ಡರ್ ಸ್ಥಿತಿ: ${orderStatus ?? "ಯಾವುದೇ ಸಕ್ರಿಯ ಆರ್ಡರ್ ಇಲ್ಲ"}. ಲೈವ್ ಟ್ರ್ಯಾಕಿಂಗ್ ತೆರೆಯಲಾಗುತ್ತಿದೆ.'
          : (isHindi
              ? 'आपका ऑर्डर स्टेटस: ${orderStatus ?? "कोई सक्रिय ऑर्डर नहीं है"}। लाइव ट्रैकिंग खोली जा रही है।'
              : 'Your current order status: ${orderStatus ?? "No active order"}. Opening live tracking.');
      return AiMessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: AiSender.assistant,
        timestamp: DateTime.now(),
        actionIntent: const AiActionIntent(type: AiActionType.trackOrder),
        languageCode: languageCode,
        suggestions: _getDefaultSuggestions(languageCode),
      );
    }

    // 5. Coupons & Offers
    if (lower.contains('coupon') || lower.contains('offer') || lower.contains('discount') ||
        lower.contains('off') || lower.contains('kodiri') || lower.contains('chhoot')) {
      final text = isKannada
          ? 'ಇಂದು ಲಭ್ಯವಿರುವ ಅತ್ಯುತ್ತಮ ರಿಯಾಯಿತಿ ಕೂಪನ್‌ಗಳನ್ನು ಪರಿಶೀಲಿಸಿ!'
          : (isHindi
              ? 'आज के बेस्ट डिस्काउंट कूपन चेक करें और अधिक बचत करें!'
              : 'Check out today\'s best discount coupons to save more on your order!');
      return AiMessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: AiSender.assistant,
        timestamp: DateTime.now(),
        actionIntent: const AiActionIntent(type: AiActionType.viewCoupons),
        languageCode: languageCode,
        suggestions: _getDefaultSuggestions(languageCode),
      );
    }

    // 5.5. Add to Cart Intent (English, Kannada, Hindi)
    if (_isAddToCartIntent(lower)) {
      final items = _extractCartItems(prompt);
      final label = items.isNotEmpty ? items.join(', ') : '';
      final text = items.isNotEmpty
          ? (isKannada
              ? '$label ಅನ್ನು ನಿಮ್ಮ ಕಾರ್ಟ್‌ಗೆ ಸೇರಿಸಲಾಗುತ್ತಿದೆ!'
              : (isHindi
                  ? '$label को आपके कार्ट में जोड़ा जा रहा है!'
                  : 'Adding $label to your cart!'))
          : (isKannada
              ? 'ನೀವು ಯಾವ ವಸ್ತುವನ್ನು ಕಾರ್ಟ್‌ಗೆ ಸೇರಿಸಲು ಬಯಸುತ್ತೀರಿ?'
              : (isHindi
                  ? 'आप कार्ट में कौन सा सामान जोड़ना चाहते हैं?'
                  : 'Adding item to your cart! You can also pick from the items below.'));
      return AiMessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: AiSender.assistant,
        timestamp: DateTime.now(),
        actionIntent: AiActionIntent(
          type: AiActionType.addItemsToCart,
          itemNames: items,
          query: label,
        ),
        languageCode: languageCode,
        suggestions: _getDefaultSuggestions(languageCode),
      );
    }

    // 6. Specific Grocery Search (Milk, Bread, Eggs, Butter, Curd)
    final groceryKeywords = ['milk', 'bread', 'egg', 'butter', 'curd', 'doodh', 'haalu', 'tomato', 'potato', 'onion', 'rice', 'oil'];
    for (final kw in groceryKeywords) {
      if (lower.contains(kw)) {
        final text = isKannada
            ? 'ನಿಮ್ಮ ಹತ್ತಿರದ ಅಂಗಡಿಯಲ್ಲಿ $kw ಹುಡುಕಲಾಗುತ್ತಿದೆ.'
            : (isHindi
                ? 'आपके नजदीकी स्टोर में $kw खोजा जा रहा है।'
                : 'Searching for $kw in your nearest store.');
        return AiMessageEntity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          sender: AiSender.assistant,
          timestamp: DateTime.now(),
          actionIntent: AiActionIntent(type: AiActionType.searchProduct, query: kw),
          languageCode: languageCode,
          suggestions: _getDefaultSuggestions(languageCode),
        );
      }
    }

    // 7. Customer Support / Wrong Response / Help / Refund
    if (lower.contains('support') || lower.contains('help') || lower.contains('refund') ||
        lower.contains('wrong') || lower.contains('issue') || lower.contains('thappu') ||
        lower.contains('galat') || lower.contains('complaint') || lower.contains('care')) {
      final text = isKannada
          ? 'ಯಾವುದೇ ಪ್ರತಿಕ್ರಿಯೆ ತಪ್ಪಾಗಿದ್ದರೆ ಅಥವಾ ಹೆಚ್ಚಿನ ಸಹಾಯ ಬೇಕಾದರೆ, ದಯವಿಟ್ಟು ಗ್ರಾಹಕ ಬೆಂಬಲವನ್ನು ಸಂಪರ್ಕಿಸಿ.'
          : (isHindi
              ? 'यदि कोई जानकारी गलत है या आपको सहायता चाहिए, तो कृपया हमारे कस्टमर सपोर्ट से संपर्क करें।'
              : 'If any response is incorrect or you need direct assistance, please contact Customer Support.');
      return AiMessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: AiSender.assistant,
        timestamp: DateTime.now(),
        actionIntent: const AiActionIntent(type: AiActionType.customerSupport),
        languageCode: languageCode,
        suggestions: _getDefaultSuggestions(languageCode),
      );
    }

    // 8. Friendly Welcome / General Help
    final greeting = isKannada
        ? 'ನಮಸ್ಕಾರ ${name.isNotEmpty ? name : ""}! QuickTick ಗೆ ಸ್ವಾಗತ. ಇಂದು ನಾನು ನಿಮಗೆ ಯಾವ ದಿನಸಿ ಸಾಮಗ್ರಿ ಹುಡುಕಲು ಸಹಾಯ ಮಾಡಲಿ?'
        : (isHindi
            ? 'नमस्ते ${name.isNotEmpty ? name : ""}! QuickTick में आपका स्वागत है। आज मैं आपके लिए कौन सी ग्रोसरी खोजने में मदद करूँ?'
            : 'Hello ${name.isNotEmpty ? name : ""}! Welcome to QuickTick. What fresh groceries can I help you find today?');

    return AiMessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: greeting,
      sender: AiSender.assistant,
      timestamp: DateTime.now(),
      actionIntent: const AiActionIntent(type: AiActionType.none),
      languageCode: languageCode,
      suggestions: _getDefaultSuggestions(languageCode),
    );
  }

  String _extractProductQuery(String query) {
    final cleaned = query
        .replaceAll(RegExp(r'\b(is|in|stock|available|how|many|units|left|of|check|details|for|the|please|tell|me)\b'), '')
        .trim();
    if (cleaned.isNotEmpty) return cleaned;
    return 'items';
  }

  RecipeDetails _getRecipeForDish(String query, String languageCode) {
    final q = query.toLowerCase();

    if (q.contains('paneer')) {
      return const RecipeDetails(
        title: 'Paneer Butter Masala',
        prepTime: '15 mins',
        cookTime: '20 mins',
        servings: '3-4 Servings',
        difficulty: 'Medium',
        cuisine: 'North Indian',
        ingredients: [
          RecipeIngredient(name: 'Fresh Paneer', quantity: '200g', matchedQuery: 'Paneer'),
          RecipeIngredient(name: 'Amul Butter', quantity: '50g', matchedQuery: 'Butter'),
          RecipeIngredient(name: 'Ripe Tomatoes', quantity: '4 medium', matchedQuery: 'Tomato'),
          RecipeIngredient(name: 'Fresh Cream', quantity: '100ml', matchedQuery: 'Cream'),
          RecipeIngredient(name: 'Ginger Garlic Paste', quantity: '2 tbsp', matchedQuery: 'Ginger'),
          RecipeIngredient(name: 'Garam Masala', quantity: '1 tsp', matchedQuery: 'Garam Masala'),
        ],
        steps: [
          'Blanch and puree 4 ripe red tomatoes until silky smooth.',
          'Melt 2 tbsp Amul butter in a pan, sauté ginger-garlic paste until aromatic.',
          'Add tomato puree, red chili powder, and turmeric. Cook on medium heat until butter separates (approx 8 mins).',
          'Whisk in fresh cream and garam masala to create a luxurious restaurant gravy.',
          'Gently slide in diced fresh paneer cubes and simmer on low for 3-4 minutes.',
          'Garnish with kasuri methi and extra cream swirl. Serve hot with buttery Naan or Jeera Rice!',
        ],
        chefTip: 'Soak raw paneer cubes in warm salted water for 10 minutes prior to cooking for an ultra-soft, melt-in-mouth texture!',
      );
    }

    if (q.contains('biryani')) {
      return const RecipeDetails(
        title: 'Hyderabadi Dum Biryani',
        prepTime: '25 mins',
        cookTime: '35 mins',
        servings: '4 Servings',
        difficulty: 'Advanced',
        cuisine: 'Royal Indian',
        ingredients: [
          RecipeIngredient(name: 'Basmati Rice', quantity: '500g', matchedQuery: 'Rice'),
          RecipeIngredient(name: 'Red Onions', quantity: '3 large', matchedQuery: 'Onion'),
          RecipeIngredient(name: 'Biryani Masala', quantity: '2 tbsp', matchedQuery: 'Biryani Masala'),
          RecipeIngredient(name: 'Cooking Oil / Ghee', quantity: '4 tbsp', matchedQuery: 'Oil'),
          RecipeIngredient(name: 'Fresh Curd / Yogurt', quantity: '1 cup', matchedQuery: 'Curd'),
          RecipeIngredient(name: 'Mint & Coriander', quantity: '1 bunch', matchedQuery: 'Coriander'),
        ],
        steps: [
          'Wash and soak aged Basmati rice for 30 minutes, then par-boil with whole spices until 70% done.',
          'Thinly slice onions and fry in hot oil until crispy golden-brown (birista).',
          'Marinate veggies or choice protein with curd, ginger-garlic, biryani spices, and chopped mint.',
          'In a heavy-bottomed handi, layer the spiced marinade, topped evenly with fragrant par-boiled rice.',
          'Scatter fried onions, fresh mint, saffron milk, and pure desi ghee on top.',
          'Seal tightly with foil or dough and cook on low dum flame for 25 minutes to lock in royal aroma!',
        ],
        chefTip: 'Never stir biryani right after opening dum—rest it covered for 8 minutes so rice grains remain intact and fluffy!',
      );
    }

    if (q.contains('tea') || q.contains('chai')) {
      return const RecipeDetails(
        title: 'Authentic Masala Chai',
        prepTime: '3 mins',
        cookTime: '7 mins',
        servings: '2 Cups',
        difficulty: 'Easy',
        cuisine: 'Indian Beverage',
        ingredients: [
          RecipeIngredient(name: 'Fresh Milk', quantity: '1 cup (250ml)', matchedQuery: 'Milk'),
          RecipeIngredient(name: 'Strong Tea Powder', quantity: '2 tsp', matchedQuery: 'Tea Powder'),
          RecipeIngredient(name: 'Fresh Ginger', quantity: '1 inch crushed', matchedQuery: 'Ginger'),
          RecipeIngredient(name: 'Cardamom Pods', quantity: '2 pods', matchedQuery: 'Cardamom'),
          RecipeIngredient(name: 'Sugar', quantity: '2 tsp', matchedQuery: 'Sugar'),
        ],
        steps: [
          'Bring 1 cup water to a rolling boil with crushed ginger and cracked green cardamom.',
          'Add 2 tsp rich Assam/Darjeeling tea powder and let it brew for 2 minutes on medium heat.',
          'Pour in 1 cup fresh creamy milk and add sugar as per taste preference.',
          'Allow the chai to froth and rise 2 to 3 times on medium-low flame for maximum creaminess.',
          'Strain through a fine mesh strainer into kulhad cups and enjoy with hot snacks!',
        ],
        chefTip: 'Crush the cardamom along with its outer green peel to release the fragrant essential oils directly into the boiling water!',
      );
    }

    if (q.contains('dosa')) {
      return const RecipeDetails(
        title: 'Crispy Golden Masala Dosa',
        prepTime: '10 mins',
        cookTime: '15 mins',
        servings: '2 Servings',
        difficulty: 'Easy',
        cuisine: 'South Indian',
        ingredients: [
          RecipeIngredient(name: 'Dosa Batter', quantity: '500g', matchedQuery: 'Dosa Batter'),
          RecipeIngredient(name: 'Potatoes', quantity: '3 boiled', matchedQuery: 'Potato'),
          RecipeIngredient(name: 'Onions', quantity: '1 finely chopped', matchedQuery: 'Onion'),
          RecipeIngredient(name: 'Green Chilies', quantity: '2 sliced', matchedQuery: 'Chili'),
          RecipeIngredient(name: 'Desi Ghee / Butter', quantity: '2 tbsp', matchedQuery: 'Butter'),
          RecipeIngredient(name: 'Mustard Seeds & Curry Leaves', quantity: '1 tsp', matchedQuery: 'Mustard'),
        ],
        steps: [
          'Temper mustard seeds, green chilies, and curry leaves in hot oil, then sauté chopped onions.',
          'Add coarsely mashed boiled potatoes, turmeric, and salt. Mix well to create flavorful aloo bhaji.',
          'Heat a seasoned cast iron tawa, pour a ladle of batter, and spread smoothly in outward concentric circles.',
          'Drizzle generous desi ghee or butter around the edges until golden-crisp.',
          'Spread a portion of potato bhaji in center, fold neatly, and serve with coconut chutney & sambar!',
        ],
        chefTip: 'Splash cold water droplets onto the hot tawa and wipe with a clean cloth before pouring batter for paper-thin crispiness!',
      );
    }

    if (q.contains('pasta')) {
      return const RecipeDetails(
        title: 'Creamy Garlic Italian Pasta',
        prepTime: '10 mins',
        cookTime: '15 mins',
        servings: '2 Servings',
        difficulty: 'Easy',
        cuisine: 'Italian',
        ingredients: [
          RecipeIngredient(name: 'Penne / Fusilli Pasta', quantity: '200g', matchedQuery: 'Pasta'),
          RecipeIngredient(name: 'Pasta Sauce / Marinara', quantity: '1 jar', matchedQuery: 'Pasta Sauce'),
          RecipeIngredient(name: 'Fresh Garlic', quantity: '4 cloves minced', matchedQuery: 'Garlic'),
          RecipeIngredient(name: 'Olive Oil / Butter', quantity: '2 tbsp', matchedQuery: 'Butter'),
          RecipeIngredient(name: 'Cheese / Mozzarella', quantity: '100g', matchedQuery: 'Cheese'),
          RecipeIngredient(name: 'Oregano & Chili Flakes', quantity: '1 tsp', matchedQuery: 'Oregano'),
        ],
        steps: [
          'Boil 4 cups water with generous salt. Cook pasta for 9-10 mins until perfectly al dente.',
          'Sauté minced garlic in extra virgin olive oil or butter until golden and fragrant.',
          'Pour in tomato herb pasta sauce with oregano and chili flakes, simmering on low for 3 minutes.',
          'Reserve 3 tablespoons starchy pasta water and toss the drained pasta into the simmering sauce.',
          'Fold in grated mozzarella or cheddar cheese until melted and glossy. Serve immediately!',
        ],
        chefTip: 'Always save a splash of salted pasta water—the rich starchy water binds the sauce seamlessly to the pasta!',
      );
    }

    if (q.contains('maggi') || q.contains('noodle')) {
      return const RecipeDetails(
        title: 'Street-Style Spicy Butter Maggi',
        prepTime: '2 mins',
        cookTime: '6 mins',
        servings: '1-2 Servings',
        difficulty: 'Easy',
        cuisine: 'Street Food',
        ingredients: [
          RecipeIngredient(name: 'Maggi Noodles', quantity: '2 packs', matchedQuery: 'Maggi'),
          RecipeIngredient(name: 'Amul Butter', quantity: '1 tbsp', matchedQuery: 'Butter'),
          RecipeIngredient(name: 'Onion', quantity: '1 small chopped', matchedQuery: 'Onion'),
          RecipeIngredient(name: 'Tomato', quantity: '1 chopped', matchedQuery: 'Tomato'),
          RecipeIngredient(name: 'Green Peas', quantity: '1/4 cup', matchedQuery: 'Peas'),
        ],
        steps: [
          'Melt 1 tbsp butter in a pan, toss in chopped onions, tomatoes, and green peas for 2 minutes.',
          'Add 1.5 cups water along with both Maggi tastemaker sachets and bring to a rapid boil.',
          'Break noodle cakes into the pan and stir gently to loosen the strands.',
          'Cook on medium heat for 3-4 minutes until water is absorbed and noodles are perfectly tender.',
          'Top with an extra dab of butter or grated cheese slice and serve piping hot!',
        ],
        chefTip: 'Sautéing the vegetables in butter first before boiling gives the broth an incredible restaurant street flavor!',
      );
    }

    // Fallback Gourmet Recipe
    return const RecipeDetails(
      title: 'Quick Gourmet Home Dish',
      prepTime: '15 mins',
      cookTime: '20 mins',
      servings: '2-3 Servings',
      difficulty: 'Easy',
      cuisine: 'Homestyle',
      ingredients: [
        RecipeIngredient(name: 'Cooking Oil / Ghee', quantity: '2 tbsp', matchedQuery: 'Oil'),
        RecipeIngredient(name: 'Fresh Vegetables / Protein', quantity: '250g', matchedQuery: 'Vegetables'),
        RecipeIngredient(name: 'Onions & Tomatoes', quantity: '2 each', matchedQuery: 'Onion'),
        RecipeIngredient(name: 'Spices & Salt', quantity: 'to taste', matchedQuery: 'Salt'),
      ],
      steps: [
        'Chop fresh vegetables into uniform bite-sized pieces for even cooking.',
        'Heat 2 tbsp oil in a pan, add cumin or mustard seeds, followed by chopped onions.',
        'Add diced tomatoes and ground spices, cooking until fragrant and tender.',
        'Add main ingredients, pour 1/2 cup water, cover, and simmer for 10-12 minutes.',
        'Garnish with fresh coriander leaves and serve steaming hot with rice or bread!',
      ],
      chefTip: 'Cook on medium-low flame with the lid covered to retain maximum natural flavors and moisture!',
    );
  }

  List<String> _getDefaultSuggestions(String code) {
    if (code.startsWith('kn')) {
      return ['ಹಾಲು ಮತ್ತು ಬ್ರೆಡ್', 'ಇಂದಿನ ಕೂಪನ್‌ಗಳು', 'ನನ್ನ ಆರ್ಡರ್ ಎಲ್ಲಿದೆ?', 'ಗ್ರಾಹಕ ಬೆಂಬಲ'];
    } else if (code.startsWith('hi')) {
      return ['दूध और ब्रेड', 'आज के कूपन', 'मेरा ऑर्डर कहाँ है?', 'कस्टमर सपोर्ट'];
    }
    return ['Milk & Bread', 'Today\'s Coupons', 'Where is my order?', 'Customer Support'];
  }
}

