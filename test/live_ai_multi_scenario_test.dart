import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/ai/ai_client.dart';

void main() {
  test('Live AI Multi-Feature Real-World Query Test', () async {
    final client = GroqAiClient();

    final scenarios = [
      {
        'title': 'Scenario 1: Recipe to Cart (Sandwich)',
        'systemPrompt': 'You are QuickTick Grocery AI. Recommend fresh ingredients for making a healthy breakfast sandwich. Return formatted JSON.',
        'userPrompt': 'I want to make a healthy sandwich for breakfast, what items should I buy?',
      },
      {
        'title': 'Scenario 2: Cart Optimization (Healthy Diet Swap)',
        'systemPrompt': 'You are QuickTick Cart Optimizer AI. Given refined/processed cart items, suggest clean, healthy, whole-grain alternatives. Return formatted JSON.',
        'userPrompt': 'My cart has: White Bread (Maida), Refined White Sugar, and Fried Potato Chips. What healthy items should I swap them for?',
      },
      {
        'title': 'Scenario 3: Quick Care / Mood Search (Cold & Cough Relief)',
        'systemPrompt': 'You are QuickTick Wellness AI. Suggest quick 10-minute grocery and wellness items for immediate cold and sore throat relief. Return formatted JSON.',
        'userPrompt': 'I have a bad cold, headache and sore throat. What essential items can I order right now?',
      },
    ];

    print('\n================================================================');
    print('       EXECUTING MULTIPLE LIVE AI SCENARIOS VIA CLOUD           ');
    print('================================================================\n');

    for (final scenario in scenarios) {
      print('----------------------------------------------------------------');
      print('🎯 ${scenario['title']}');
      print('❓ USER: "${scenario['userPrompt']}"');
      print('📡 Contacting cloud AI...');

      final sw = Stopwatch()..start();
      final response = await client.generateCompletion(
        systemPrompt: scenario['systemPrompt']!,
        userPrompt: scenario['userPrompt']!,
      );
      sw.stop();

      print('⏱️ Response Time: ${sw.elapsedMilliseconds} ms');
      print('🤖 LIVE CLOUD RESPONSE:');
      print(response);
      print('----------------------------------------------------------------\n');

      expect(response, isNotNull);
      expect(response!.isNotEmpty, isTrue);
    }

    print('================================================================');
    print('🎉 ALL LIVE AI SCENARIOS COMPLETED SUCCESSFULLY!');
    print('================================================================\n');
  });
}

