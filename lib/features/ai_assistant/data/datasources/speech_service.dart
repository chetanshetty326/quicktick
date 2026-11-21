import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract class ISpeechService {
  Future<bool> initialize();
  Future<void> startListening({
    required Function(String words) onResult,
    required String localeId,
  });
  Future<void> stopListening();
  bool get isListening;

  Future<void> speak(String text, {required String localeId});
  Future<void> stopSpeaking();
}

class SpeechServiceImpl implements ISpeechService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechInitialized = false;

  @override
  bool get isListening => _speechToText.isListening;

  @override
  Future<bool> initialize() async {
    if (_speechInitialized) return true;
    try {
      _speechInitialized = await _speechToText.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (_) {
      _speechInitialized = false;
    }
    return _speechInitialized;
  }

  @override
  Future<void> startListening({
    required Function(String words) onResult,
    required String localeId,
  }) async {
    final ready = await initialize();
    if (!ready) return;

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: _mapLocaleToSpeechLocale(localeId),
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (_) {}
  }

  @override
  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
  }

  @override
  Future<void> speak(String text, {required String localeId}) async {
    try {
      await stopSpeaking();
      final ttsLocale = _mapLocaleToTtsLocale(localeId);
      await _flutterTts.setLanguage(ttsLocale);
      // Clean up markdown / action tags before speaking
      final cleanText = text
          .replaceAll(RegExp(r'\[ACTION:[^\]]+\]'), '')
          .replaceAll(RegExp(r'[*_#`~]'), '')
          .trim();
      if (cleanText.isNotEmpty) {
        await _flutterTts.speak(cleanText);
      }
    } catch (_) {}
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  String _mapLocaleToSpeechLocale(String code) {
    switch (code.toLowerCase()) {
      case 'kn':
      case 'kn_in':
        return 'kn_IN';
      case 'hi':
      case 'hi_in':
        return 'hi_IN';
      case 'ta':
      case 'ta_in':
        return 'ta_IN';
      case 'te':
      case 'te_in':
        return 'te_IN';
      case 'ml':
      case 'ml_in':
        return 'ml_IN';
      case 'mr':
      case 'mr_in':
        return 'mr_IN';
      default:
        return 'en_IN';
    }
  }

  String _mapLocaleToTtsLocale(String code) {
    switch (code.toLowerCase()) {
      case 'kn':
      case 'kn_in':
        return 'kn-IN';
      case 'hi':
      case 'hi_in':
        return 'hi-IN';
      case 'ta':
      case 'ta_in':
        return 'ta-IN';
      case 'te':
      case 'te_in':
        return 'te-IN';
      case 'ml':
      case 'ml_in':
        return 'ml-IN';
      case 'mr':
      case 'mr_in':
        return 'mr-IN';
      default:
        return 'en-IN';
    }
  }
}

