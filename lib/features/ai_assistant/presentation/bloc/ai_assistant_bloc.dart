import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/ai_message_entity.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import 'ai_assistant_event.dart';
import 'ai_assistant_state.dart';

class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final IAiAssistantRepository _repository;

  AiAssistantBloc({required IAiAssistantRepository repository})
      : _repository = repository,
        super(const AiAssistantState()) {
    on<InitAiAssistantEvent>(_onInit);
    on<ChangeLanguageEvent>(_onChangeLanguage);
    on<SendTextMessageEvent>(_onSendTextMessage);
    on<StartVoiceListeningEvent>(_onStartVoiceListening);
    on<StopVoiceListeningEvent>(_onStopVoiceListening);
    on<VoiceResultReceivedEvent>(_onVoiceResultReceived);
    on<ToggleSpeechOutputEvent>(_onToggleSpeechOutput);
    on<TriggerDeliveryArrivalCallEvent>(_onTriggerDeliveryArrivalCall);
    on<DismissDeliveryArrivalCallEvent>(_onDismissDeliveryArrivalCall);
    on<ClearChatEvent>(_onClearChat);
  }

  Future<void> _onInit(
    InitAiAssistantEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    emit(state.copyWith(
      customerName: event.customerName ?? state.customerName,
      cartSummary: event.cartSummary ?? state.cartSummary,
      activeOrderStatus: event.activeOrderStatus ?? state.activeOrderStatus,
    ));

    await _repository.initializeSpeech();

    // If chat is empty, introduce with a warm greeting
    if (state.messages.isEmpty) {
      final welcomeEntity = await _repository.processMessage(
        userMessage: 'hello',
        languageCode: state.selectedLanguageCode,
        customerName: state.customerName,
        currentCartSummary: state.cartSummary,
        activeOrderStatus: state.activeOrderStatus,
      );
      emit(state.copyWith(messages: [welcomeEntity]));

      if (state.speechOutputEnabled) {
        await _repository.speakText(
          welcomeEntity.text,
          languageCode: state.selectedLanguageCode,
        );
      }
    }
  }

  Future<void> _onChangeLanguage(
    ChangeLanguageEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    emit(state.copyWith(selectedLanguageCode: event.languageCode));
    await _repository.stopSpeaking();

    // Send a localized acknowledgement
    final ack = await _repository.processMessage(
      userMessage: 'hello',
      languageCode: event.languageCode,
      customerName: state.customerName,
      currentCartSummary: state.cartSummary,
      activeOrderStatus: state.activeOrderStatus,
    );
    emit(state.copyWith(messages: [...state.messages, ack]));

    if (state.speechOutputEnabled) {
      await _repository.speakText(ack.text, languageCode: event.languageCode);
    }
  }

  Future<void> _onSendTextMessage(
    SendTextMessageEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    final query = event.message.trim();
    if (query.isEmpty) return;

    // 1. Add user message
    final userMsg = AiMessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: query,
      sender: AiSender.user,
      timestamp: DateTime.now(),
      languageCode: state.selectedLanguageCode,
    );

    emit(state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearTriggeredIntent: true,
    ));

    // 2. Fetch AI response
    try {
      var aiResponse = await _repository.processMessage(
        userMessage: query,
        languageCode: state.selectedLanguageCode,
        customerName: state.customerName,
        currentCartSummary: state.cartSummary,
        activeOrderStatus: state.activeOrderStatus,
      );

      // Resolve context item when user says "add to cart" / "add it to cart" right after searching/checking stock
      if (aiResponse.actionIntent?.type == AiActionType.addItemsToCart &&
          aiResponse.actionIntent!.itemNames.isEmpty) {
        final contextItem = _findLastReferencedItem(state.messages);
        if (contextItem != null && contextItem.isNotEmpty) {
          aiResponse = AiMessageEntity(
            id: aiResponse.id,
            text: aiResponse.text,
            sender: aiResponse.sender,
            timestamp: aiResponse.timestamp,
            actionIntent: AiActionIntent(
              type: AiActionType.addItemsToCart,
              itemNames: [contextItem],
              query: contextItem,
            ),
            suggestions: aiResponse.suggestions,
            languageCode: aiResponse.languageCode,
            recipeDetails: aiResponse.recipeDetails,
          );
        }
      }

      emit(state.copyWith(
        messages: [...state.messages, aiResponse],
        isLoading: false,
        lastTriggeredIntent: aiResponse.actionIntent,
      ));

      // 3. Speak response aloud if enabled
      if (state.speechOutputEnabled) {
        await _repository.speakText(
          aiResponse.text,
          languageCode: state.selectedLanguageCode,
        );
      }
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  String? _findLastReferencedItem(List<AiMessageEntity> history) {
    for (var i = history.length - 1; i >= 0; i--) {
      final intent = history[i].actionIntent;
      if (intent == null) continue;
      if (intent.itemNames.isNotEmpty) return intent.itemNames.first;
      if (intent.stockItemQuery != null && intent.stockItemQuery!.trim().isNotEmpty) {
        return intent.stockItemQuery!.trim();
      }
      if (intent.query != null && intent.query!.trim().isNotEmpty) {
        return intent.query!.trim();
      }
    }
    return null;
  }

  Future<void> _onStartVoiceListening(
    StartVoiceListeningEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    await _repository.stopSpeaking();
    emit(state.copyWith(isListening: true));

    await _repository.startListening(
      languageCode: state.selectedLanguageCode,
      onResult: (words) {
        if (!isClosed) {
          add(VoiceResultReceivedEvent(words));
        }
      },
    );
  }

  Future<void> _onStopVoiceListening(
    StopVoiceListeningEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    await _repository.stopListening();
    emit(state.copyWith(isListening: false));
  }

  Future<void> _onVoiceResultReceived(
    VoiceResultReceivedEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    emit(state.copyWith(isListening: false));
    add(SendTextMessageEvent(event.recognizedText));
  }

  Future<void> _onToggleSpeechOutput(
    ToggleSpeechOutputEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    final newValue = event.enable ?? !state.speechOutputEnabled;
    if (!newValue) {
      await _repository.stopSpeaking();
    }
    emit(state.copyWith(speechOutputEnabled: newValue));
  }

  Future<void> _onTriggerDeliveryArrivalCall(
    TriggerDeliveryArrivalCallEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    emit(state.copyWith(
      showIncomingCall: true,
      callRiderName: event.riderName,
      callStoreName: event.storeName,
      callOrderNumber: event.orderNumber,
    ));

    // Announce delivery arrival in the selected language
    final isKn = state.selectedLanguageCode.startsWith('kn');
    final isHi = state.selectedLanguageCode.startsWith('hi');
    final spokenAnnouncement = isKn
        ? 'ನಮಸ್ಕಾರ! ನಿಮ್ಮ ಕ್ವಿಕ್‌ಟಿಕ್ ಡೆಲಿವರಿ ಪಾರ್ಟ್ನರ್ ${event.riderName} ನಿಮ್ಮ ಆರ್ಡರ್‌ನೊಂದಿಗೆ ಬಂದಿದ್ದಾರೆ. ದಯವಿಟ್ಟು ಹೊರಗೆ ಬಂದು ಸ್ವೀಕರಿಸಿ.'
        : (isHi
            ? 'नमस्ते! आपके क्विकटिक डिलीवरी पार्टनर ${event.riderName} आपका ऑर्डर लेकर पहुँच चुके हैं। कृपया अपना ऑर्डर कलेक्ट करें।'
            : 'Hello! Your QuickTick delivery partner ${event.riderName} has arrived outside with your order from ${event.storeName}. Please collect your order.');

    await _repository.speakText(
      spokenAnnouncement,
      languageCode: state.selectedLanguageCode,
    );
  }

  Future<void> _onDismissDeliveryArrivalCall(
    DismissDeliveryArrivalCallEvent event,
    Emitter<AiAssistantState> emit,
  ) async {
    await _repository.stopSpeaking();
    emit(state.copyWith(
      showIncomingCall: false,
      callRiderName: null,
      callStoreName: null,
      callOrderNumber: null,
    ));
  }

  void _onClearChat(ClearChatEvent event, Emitter<AiAssistantState> emit) {
    emit(state.copyWith(messages: const []));
  }

  @override
  Future<void> close() async {
    await _repository.stopSpeaking();
    await _repository.stopListening();
    return super.close();
  }
}

