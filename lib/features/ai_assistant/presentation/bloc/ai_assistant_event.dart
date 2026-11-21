import 'package:equatable/equatable.dart';

abstract class AiAssistantEvent extends Equatable {
  const AiAssistantEvent();

  @override
  List<Object?> get props => [];
}

class InitAiAssistantEvent extends AiAssistantEvent {
  final String? customerName;
  final String? cartSummary;
  final String? activeOrderStatus;

  const InitAiAssistantEvent({
    this.customerName,
    this.cartSummary,
    this.activeOrderStatus,
  });

  @override
  List<Object?> get props => [customerName, cartSummary, activeOrderStatus];
}

class ChangeLanguageEvent extends AiAssistantEvent {
  final String languageCode;

  const ChangeLanguageEvent(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

class SendTextMessageEvent extends AiAssistantEvent {
  final String message;

  const SendTextMessageEvent(this.message);

  @override
  List<Object?> get props => [message];
}

class StartVoiceListeningEvent extends AiAssistantEvent {
  const StartVoiceListeningEvent();
}

class StopVoiceListeningEvent extends AiAssistantEvent {
  const StopVoiceListeningEvent();
}

class VoiceResultReceivedEvent extends AiAssistantEvent {
  final String recognizedText;

  const VoiceResultReceivedEvent(this.recognizedText);

  @override
  List<Object?> get props => [recognizedText];
}

class ToggleSpeechOutputEvent extends AiAssistantEvent {
  final bool? enable;

  const ToggleSpeechOutputEvent({this.enable});

  @override
  List<Object?> get props => [enable];
}

class TriggerDeliveryArrivalCallEvent extends AiAssistantEvent {
  final String riderName;
  final String storeName;
  final String orderNumber;

  const TriggerDeliveryArrivalCallEvent({
    required this.riderName,
    required this.storeName,
    required this.orderNumber,
  });

  @override
  List<Object?> get props => [riderName, storeName, orderNumber];
}

class DismissDeliveryArrivalCallEvent extends AiAssistantEvent {
  const DismissDeliveryArrivalCallEvent();
}

class ClearChatEvent extends AiAssistantEvent {
  const ClearChatEvent();
}

