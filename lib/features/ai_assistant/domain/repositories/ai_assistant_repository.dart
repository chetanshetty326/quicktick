import '../entities/ai_message_entity.dart';

abstract class IAiAssistantRepository {
  Future<AiMessageEntity> processMessage({
    required String userMessage,
    required String languageCode,
    String? customerName,
    String? currentCartSummary,
    String? activeOrderStatus,
  });

  Future<void> speakText(String text, {required String languageCode});
  Future<void> stopSpeaking();

  Future<bool> initializeSpeech();
  Future<void> startListening({
    required Function(String recognizedWords) onResult,
    required String languageCode,
  });
  Future<void> stopListening();
}

