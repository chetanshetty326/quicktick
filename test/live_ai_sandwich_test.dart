import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/ai/ai_client.dart';

void main() {
  test('Live AI Query: I want to make a sandwich what items needed', () async {
    print('\n================================================================');
    print('      CONNECTING TO LIVE CLOUD AI (Groq llama-3.3-70b)         ');
    print('================================================================\n');

    final client = GroqAiClient();

    print('📡 Sending live request to Groq cloud API...');
    print('❓ Customer Query: "I want to make a sandwich, what items are needed?"\n');

    final systemPrompt = '''
You are QuickTick's Smart Recipe & Grocery AI.
When a customer asks what items are needed to cook or prepare a dish, identify the essential ingredients for a delicious, fresh version of that dish.
Format your output as a clean, structured JSON with:
1. "dishName": Name of the dish.
2. "prepTime": Preparation time.
3. "ingredients": List of objects with "item", "quantity", "category", and "tip".
4. "quickRecipeSteps": 3-4 bullet point steps to prepare it.
''';

    final userPrompt = 'I want to make a sandwich, what items are needed?';

    final stopwatch = Stopwatch()..start();
    final response = await client.generateCompletion(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
    stopwatch.stop();

    print('✅ LIVE AI RESPONSE RECEIVED IN ${stopwatch.elapsedMilliseconds}ms:\n');
    print(response);
    print('\n================================================================');

    expect(response, isNotNull);
    expect(response!.isNotEmpty, isTrue);
  });
}

