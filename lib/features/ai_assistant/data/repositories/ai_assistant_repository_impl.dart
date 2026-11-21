import '../../domain/entities/ai_message_entity.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import '../datasources/ai_assistant_remote_data_source.dart';
import '../datasources/speech_service.dart';

class AiAssistantRepositoryImpl implements IAiAssistantRepository {
  final IAiAssistantRemoteDataSource _remoteDataSource;
  final ISpeechService _speechService;

  AiAssistantRepositoryImpl({
    required IAiAssistantRemoteDataSource remoteDataSource,
    required ISpeechService speechService,
  })  : _remoteDataSource = remoteDataSource,
        _speechService = speechService;

  @override
  Future<AiMessageEntity> processMessage({
    required String userMessage,
    required String languageCode,
    String? customerName,
    String? currentCartSummary,
    String? activeOrderStatus,
  }) async {
    return await _remoteDataSource.queryAssistant(
      prompt: userMessage,
      languageCode: languageCode,
      customerName: customerName,
      currentCartSummary: currentCartSummary,
      activeOrderStatus: activeOrderStatus,
    );
  }

  @override
  Future<void> speakText(String text, {required String languageCode}) async {
    await _speechService.speak(text, localeId: languageCode);
  }

  @override
  Future<void> stopSpeaking() async {
    await _speechService.stopSpeaking();
  }

  @override
  Future<bool> initializeSpeech() async {
    return await _speechService.initialize();
  }

  @override
  Future<void> startListening({
    required Function(String recognizedWords) onResult,
    required String languageCode,
  }) async {
    await _speechService.startListening(
      onResult: onResult,
      localeId: languageCode,
    );
  }

  @override
  Future<void> stopListening() async {
    await _speechService.stopListening();
  }
}

