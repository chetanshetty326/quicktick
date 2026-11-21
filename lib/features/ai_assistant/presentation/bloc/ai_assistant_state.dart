import 'package:equatable/equatable.dart';
import '../../domain/entities/ai_message_entity.dart';

class AiAssistantState extends Equatable {
  final List<AiMessageEntity> messages;
  final bool isLoading;
  final bool isListening;
  final bool isSpeaking;
  final bool speechOutputEnabled;
  final String selectedLanguageCode;
  final String? customerName;
  final String? cartSummary;
  final String? activeOrderStatus;
  final bool showIncomingCall;
  final String? callRiderName;
  final String? callStoreName;
  final String? callOrderNumber;
  final AiActionIntent? lastTriggeredIntent;

  const AiAssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.speechOutputEnabled = true,
    this.selectedLanguageCode = 'en',
    this.customerName,
    this.cartSummary,
    this.activeOrderStatus,
    this.showIncomingCall = false,
    this.callRiderName,
    this.callStoreName,
    this.callOrderNumber,
    this.lastTriggeredIntent,
  });

  AiAssistantState copyWith({
    List<AiMessageEntity>? messages,
    bool? isLoading,
    bool? isListening,
    bool? isSpeaking,
    bool? speechOutputEnabled,
    String? selectedLanguageCode,
    String? customerName,
    String? cartSummary,
    String? activeOrderStatus,
    bool? showIncomingCall,
    String? callRiderName,
    String? callStoreName,
    String? callOrderNumber,
    AiActionIntent? lastTriggeredIntent,
    bool clearTriggeredIntent = false,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      speechOutputEnabled: speechOutputEnabled ?? this.speechOutputEnabled,
      selectedLanguageCode: selectedLanguageCode ?? this.selectedLanguageCode,
      customerName: customerName ?? this.customerName,
      cartSummary: cartSummary ?? this.cartSummary,
      activeOrderStatus: activeOrderStatus ?? this.activeOrderStatus,
      showIncomingCall: showIncomingCall ?? this.showIncomingCall,
      callRiderName: callRiderName ?? this.callRiderName,
      callStoreName: callStoreName ?? this.callStoreName,
      callOrderNumber: callOrderNumber ?? this.callOrderNumber,
      lastTriggeredIntent: clearTriggeredIntent ? null : (lastTriggeredIntent ?? this.lastTriggeredIntent),
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isLoading,
        isListening,
        isSpeaking,
        speechOutputEnabled,
        selectedLanguageCode,
        customerName,
        cartSummary,
        activeOrderStatus,
        showIncomingCall,
        callRiderName,
        callStoreName,
        callOrderNumber,
        lastTriggeredIntent,
      ];
}

