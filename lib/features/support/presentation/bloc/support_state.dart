import 'package:equatable/equatable.dart';
import '../../domain/entities/support_ticket_entity.dart';

class SupportState extends Equatable {
  final bool isLoading;
  final bool isCreatingTicket;
  final bool isSendingReply;
  final List<SupportTicketEntity> tickets;
  final SupportTicketEntity? selectedTicket;
  final List<SupportMessageEntity> messages;
  final int totalTickets;
  final int currentPage;
  final int totalPages;
  final String? activeStatusFilter;
  final SupportTicketEntity? newlyCreatedTicket;
  final String? errorMessage;
  final String? successMessage;

  const SupportState({
    this.isLoading = false,
    this.isCreatingTicket = false,
    this.isSendingReply = false,
    this.tickets = const [],
    this.selectedTicket,
    this.messages = const [],
    this.totalTickets = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.activeStatusFilter,
    this.newlyCreatedTicket,
    this.errorMessage,
    this.successMessage,
  });

  SupportState copyWith({
    bool? isLoading,
    bool? isCreatingTicket,
    bool? isSendingReply,
    List<SupportTicketEntity>? tickets,
    SupportTicketEntity? selectedTicket,
    List<SupportMessageEntity>? messages,
    int? totalTickets,
    int? currentPage,
    int? totalPages,
    String? activeStatusFilter,
    SupportTicketEntity? newlyCreatedTicket,
    bool clearNewlyCreatedTicket = false,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return SupportState(
      isLoading: isLoading ?? this.isLoading,
      isCreatingTicket: isCreatingTicket ?? this.isCreatingTicket,
      isSendingReply: isSendingReply ?? this.isSendingReply,
      tickets: tickets ?? this.tickets,
      selectedTicket: selectedTicket ?? this.selectedTicket,
      messages: messages ?? this.messages,
      totalTickets: totalTickets ?? this.totalTickets,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      activeStatusFilter: activeStatusFilter ?? this.activeStatusFilter,
      newlyCreatedTicket: clearNewlyCreatedTicket
          ? null
          : (newlyCreatedTicket ?? this.newlyCreatedTicket),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isCreatingTicket,
        isSendingReply,
        tickets,
        selectedTicket,
        messages,
        totalTickets,
        currentPage,
        totalPages,
        activeStatusFilter,
        newlyCreatedTicket,
        errorMessage,
        successMessage,
      ];
}
