import 'package:equatable/equatable.dart';

abstract class SupportEvent extends Equatable {
  const SupportEvent();

  @override
  List<Object?> get props => [];
}

class FetchSupportTicketsEvent extends SupportEvent {
  final String? status;
  final int page;
  final int limit;

  const FetchSupportTicketsEvent({
    this.status,
    this.page = 1,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [status, page, limit];
}

class SelectTicketDetailsEvent extends SupportEvent {
  final String ticketId;

  const SelectTicketDetailsEvent(this.ticketId);

  @override
  List<Object?> get props => [ticketId];
}

class CreateSupportTicketEvent extends SupportEvent {
  final String app;
  final String category;
  final String subject;
  final String description;
  final String? relatedOrderId;
  final List<String>? attachments;

  const CreateSupportTicketEvent({
    required this.app,
    required this.category,
    required this.subject,
    required this.description,
    this.relatedOrderId,
    this.attachments,
  });

  @override
  List<Object?> get props => [app, category, subject, description, relatedOrderId, attachments];
}

class ReplySupportTicketEvent extends SupportEvent {
  final String ticketId;
  final String body;
  final List<String>? attachments;

  const ReplySupportTicketEvent({
    required this.ticketId,
    required this.body,
    this.attachments,
  });

  @override
  List<Object?> get props => [ticketId, body, attachments];
}

class ResetTicketCreatedEvent extends SupportEvent {
  const ResetTicketCreatedEvent();
}
