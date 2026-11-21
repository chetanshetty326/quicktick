import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/core/utils/product_matcher.dart';
import 'package:quicklink/features/ai_assistant/data/datasources/ai_assistant_remote_data_source.dart';
import 'package:quicklink/features/ai_assistant/domain/entities/ai_message_entity.dart';
import 'package:quicklink/features/ai_assistant/domain/repositories/ai_assistant_repository.dart';
import 'package:quicklink/features/ai_assistant/presentation/bloc/ai_assistant_bloc.dart';
import 'package:quicklink/features/ai_assistant/presentation/bloc/ai_assistant_event.dart';
import 'package:quicklink/features/ai_assistant/presentation/bloc/ai_assistant_state.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

class _OfflineStubSecureStorage implements ISecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, String?>> getUserData() async => {};
}

class _FailingDioInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError));
  }
}

class MockAiAssistantRepository implements IAiAssistantRepository {
  String lastSpokenText = '';
  String lastSpokenLanguage = '';
  bool isSpeaking = false;
  bool isListening = false;

  @override
  Future<AiMessageEntity> processMessage({
    required String userMessage,
    required String languageCode,
    String? customerName,
    String? currentCartSummary,
    String? activeOrderStatus,
  }) async {
    final lower = userMessage.toLowerCase();
    AiActionIntent intent = const AiActionIntent(type: AiActionType.none);

    if (lower.contains('stock') || lower.contains('available') || lower.contains('units')) {
      intent = const AiActionIntent(
        type: AiActionType.checkStock,
        stockItemQuery: 'milk',
        query: 'milk',
      );
    } else if (lower.contains('payment') || lower.contains('paid')) {
      intent = const AiActionIntent(type: AiActionType.paymentStatus);
    } else if (lower.contains('recipe')) {
      intent = const AiActionIntent(
        type: AiActionType.recipeGuide,
        itemNames: ['Paneer 200g', 'Butter', 'Tomatoes'],
        recipeDetails: RecipeDetails(
          title: 'Paneer Butter Masala',
          prepTime: '15 mins',
          cookTime: '20 mins',
          servings: '3-4 Servings',
          difficulty: 'Medium',
          ingredients: [
            RecipeIngredient(name: 'Paneer 200g', quantity: '200g'),
            RecipeIngredient(name: 'Butter', quantity: '50g'),
            RecipeIngredient(name: 'Tomatoes', quantity: '4 medium'),
          ],
          steps: ['Sauté butter', 'Add puree', 'Add paneer'],
        ),
      );
    } else if (lower.contains('add') && lower.contains('cart')) {
      intent = const AiActionIntent(type: AiActionType.addItemsToCart, itemNames: []);
    } else if (lower.contains('milk') || lower.contains('haalu') || lower.contains('doodh')) {
      intent = const AiActionIntent(type: AiActionType.searchProduct, query: 'milk');
    } else if (lower.contains('order') || lower.contains('track')) {
      intent = const AiActionIntent(type: AiActionType.trackOrder);
    } else if (lower.contains('coupon') || lower.contains('offer')) {
      intent = const AiActionIntent(type: AiActionType.viewCoupons);
    } else if (lower.contains('support') || lower.contains('wrong') || lower.contains('help')) {
      intent = const AiActionIntent(type: AiActionType.customerSupport);
    } else if (lower.contains('paneer') || lower.contains('biryani')) {
      intent = const AiActionIntent(
        type: AiActionType.addItemsToCart,
        itemNames: ['Paneer 200g', 'Butter', 'Tomatoes'],
      );
    }

    return AiMessageEntity(
      id: 'test_msg_${DateTime.now().millisecondsSinceEpoch}',
      text: 'Response for $userMessage',
      sender: AiSender.assistant,
      timestamp: DateTime.now(),
      actionIntent: intent,
      languageCode: languageCode,
      suggestions: const ['Milk', 'Today Offers'],
    );
  }

  @override
  Future<void> speakText(String text, {required String languageCode}) async {
    lastSpokenText = text;
    lastSpokenLanguage = languageCode;
    isSpeaking = true;
  }

  @override
  Future<void> stopSpeaking() async {
    isSpeaking = false;
  }

  @override
  Future<bool> initializeSpeech() async {
    return true;
  }

  @override
  Future<void> startListening({
    required Function(String recognizedWords) onResult,
    required String languageCode,
  }) async {
    isListening = true;
  }

  @override
  Future<void> stopListening() async {
    isListening = false;
  }
}

void main() {
  group('AI Assistant - Clean Architecture & BLoC Verification', () {
    late MockAiAssistantRepository mockRepo;
    late AiAssistantBloc bloc;

    setUp(() {
      mockRepo = MockAiAssistantRepository();
      bloc = AiAssistantBloc(repository: mockRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test('1. Init event populates customer context and gives warm greeting', () async {
      bloc.add(const InitAiAssistantEvent(
        customerName: 'Chetan',
        cartSummary: '2 items in cart',
        activeOrderStatus: 'ON_THE_WAY',
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) =>
              s.customerName == 'Chetan' &&
              s.cartSummary == '2 items in cart' &&
              s.activeOrderStatus == 'ON_THE_WAY'),
          predicate<AiAssistantState>((s) =>
              s.messages.isNotEmpty &&
              s.messages.first.sender == AiSender.assistant),
        ]),
      );
      expect(mockRepo.lastSpokenText, contains('Response for hello'));
    });

    test('2. Language change triggers localized greeting and speech update', () async {
      bloc.add(const ChangeLanguageEvent('kn'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) => s.selectedLanguageCode == 'kn'),
          predicate<AiAssistantState>((s) =>
              s.messages.isNotEmpty &&
              s.selectedLanguageCode == 'kn'),
        ]),
      );
      expect(mockRepo.lastSpokenLanguage, equals('kn'));
    });

    test('3. Text query emits user message, loading state, and AI intent', () async {
      bloc.add(const SendTextMessageEvent('Find Nandini milk'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) =>
              s.isLoading == true &&
              s.messages.last.sender == AiSender.user &&
              s.messages.last.text == 'Find Nandini milk'),
          predicate<AiAssistantState>((s) =>
              s.isLoading == false &&
              s.messages.last.sender == AiSender.assistant &&
              s.lastTriggeredIntent?.type == AiActionType.searchProduct &&
              s.lastTriggeredIntent?.query == 'milk'),
        ]),
      );
    });

    test('4. Recipe request resolves to recipeGuide intent with multi-item cart items', () async {
      bloc.add(const SendTextMessageEvent('Recipe for paneer butter masala'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) => s.isLoading == true),
          predicate<AiAssistantState>((s) =>
              s.isLoading == false &&
              (s.lastTriggeredIntent?.type == AiActionType.recipeGuide ||
                  s.lastTriggeredIntent?.type == AiActionType.addItemsToCart) &&
              s.lastTriggeredIntent?.itemNames.length == 3),
        ]),
      );
    });

    test('5. Order status inquiry triggers trackOrder intent', () async {
      bloc.add(const SendTextMessageEvent('Where is my order?'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) => s.isLoading == true),
          predicate<AiAssistantState>((s) =>
              s.isLoading == false &&
              s.lastTriggeredIntent?.type == AiActionType.trackOrder),
        ]),
      );
    });

    test('6. Coupon inquiry triggers viewCoupons intent', () async {
      bloc.add(const SendTextMessageEvent('Show today offers and discount coupons'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) => s.isLoading == true),
          predicate<AiAssistantState>((s) =>
              s.isLoading == false &&
              s.lastTriggeredIntent?.type == AiActionType.viewCoupons),
        ]),
      );
    });

    test('7. Delivery arrival trigger activates full-screen call UI and speech', () async {
      bloc.add(const TriggerDeliveryArrivalCallEvent(
        riderName: 'Aman Kumar',
        storeName: 'Fresh Mart',
        orderNumber: 'ORD-9821',
      ));

      await expectLater(
        bloc.stream,
        emits(predicate<AiAssistantState>((s) =>
            s.showIncomingCall == true &&
            s.callRiderName == 'Aman Kumar' &&
            s.callStoreName == 'Fresh Mart' &&
            s.callOrderNumber == 'ORD-9821')),
      );

      expect(mockRepo.lastSpokenText, contains('Aman Kumar'));

      // Dismissal
      bloc.add(const DismissDeliveryArrivalCallEvent());
      await expectLater(
        bloc.stream,
        emits(predicate<AiAssistantState>((s) => s.showIncomingCall == false)),
      );
    });

    test('8. Customer support / incorrect response query triggers customerSupport intent', () async {
      bloc.add(const SendTextMessageEvent('This answer is wrong, I need customer support'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) => s.isLoading == true),
          predicate<AiAssistantState>((s) =>
              s.isLoading == false &&
              s.lastTriggeredIntent?.type == AiActionType.customerSupport),
        ]),
      );
    });

    test('9. Stock check query triggers checkStock intent with item query', () async {
      bloc.add(const SendTextMessageEvent('Is milk in stock?'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) => s.isLoading == true),
          predicate<AiAssistantState>((s) =>
              s.isLoading == false &&
              s.lastTriggeredIntent?.type == AiActionType.checkStock &&
              s.lastTriggeredIntent?.stockItemQuery == 'milk'),
        ]),
      );
    });

    test('10. Payment status query triggers paymentStatus intent', () async {
      bloc.add(const SendTextMessageEvent('Check my recent payment status'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) => s.isLoading == true),
          predicate<AiAssistantState>((s) =>
              s.isLoading == false &&
              s.lastTriggeredIntent?.type == AiActionType.paymentStatus),
        ]),
      );
    });

    test('11. Recipe inquiry triggers recipeGuide intent with structured RecipeDetails and item list', () async {
      bloc.add(const SendTextMessageEvent('Show me the recipe for paneer butter masala'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AiAssistantState>((s) => s.isLoading == true),
          predicate<AiAssistantState>((s) =>
              s.isLoading == false &&
              s.lastTriggeredIntent?.type == AiActionType.recipeGuide &&
              s.lastTriggeredIntent?.recipeDetails != null &&
              s.lastTriggeredIntent?.recipeDetails?.title == 'Paneer Butter Masala' &&
              s.lastTriggeredIntent?.itemNames.length == 3),
        ]),
      );
    });

    test('12. Contextual "add to cart" resolves item from previous message', () async {
      bloc.add(const SendTextMessageEvent('Is milk in stock?'));
      await Future.delayed(const Duration(milliseconds: 30));

      bloc.add(const SendTextMessageEvent('add to cart'));
      await Future.delayed(const Duration(milliseconds: 30));

      expect(bloc.state.lastTriggeredIntent?.type, AiActionType.addItemsToCart);
      expect(bloc.state.lastTriggeredIntent?.itemNames, ['milk']);
    });

    test('13. GroqAiRemoteDataSourceImpl offline engine detects add to cart with multiple items', () async {
      final dio = Dio()..interceptors.add(_FailingDioInterceptor());
      final ds = GroqAiRemoteDataSourceImpl(
        dio: dio,
        secureStorage: _OfflineStubSecureStorage(),
      );

      final res = await ds.queryAssistant(
        prompt: 'Add 2 milk and fresh bread to cart',
        languageCode: 'en',
      );

      expect(res.actionIntent?.type, AiActionType.addItemsToCart);
      expect(res.actionIntent?.itemNames, contains('2 milk'));
      expect(res.actionIntent?.itemNames, contains('fresh bread'));
    });

    test('14. ProductMatcher handles quantities, plurals, and prioritizes in-stock items', () {
      const products = [
        ProductEntity(
          id: 'p1',
          storeId: 's1',
          categoryId: 'c1',
          name: 'Fresh Tomato',
          description: '',
          price: 40,
          unit: '500g',
          stock: 0,
          isAvailable: false,
          imageUrl: '',
        ),
        ProductEntity(
          id: 'p2',
          storeId: 's1',
          categoryId: 'c1',
          name: 'Organic Tomato',
          description: '',
          price: 45,
          unit: '500g',
          stock: 10,
          isAvailable: true,
          imageUrl: '',
        ),
        ProductEntity(
          id: 'p3',
          storeId: 's1',
          categoryId: 'c1',
          name: 'Amul Taaza Milk',
          description: '',
          price: 30,
          unit: '500ml',
          stock: 20,
          isAvailable: true,
          imageUrl: '',
        ),
      ];

      final tomatoMatch = ProductMatcher.findBestMatch(products, '2 kg tomatoes');
      final milkMatch = ProductMatcher.findBestMatch(products, '1L milk');

      expect(tomatoMatch?.id, 'p2'); // Matches plural + skips out-of-stock p1
      expect(milkMatch?.id, 'p3');
    });
  });
}

