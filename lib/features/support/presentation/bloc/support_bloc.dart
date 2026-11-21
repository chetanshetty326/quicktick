import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/support_repository.dart';
import 'support_event.dart';
import 'support_state.dart';

export 'support_event.dart';
export 'support_state.dart';

class SupportBloc extends Bloc<SupportEvent, SupportState> {
  final ISupportRepository _supportRepo;

  SupportBloc({required ISupportRepository supportRepo})
      : _supportRepo = supportRepo,
        super(const SupportState()) {
    on<FetchSupportTicketsEvent>(_onFetchTickets);
    on<SelectTicketDetailsEvent>(_onSelectTicketDetails);
    on<CreateSupportTicketEvent>(_onCreateTicket);
    on<ReplySupportTicketEvent>(_onReplyTicket);
    on<ResetTicketCreatedEvent>(_onResetTicketCreated);
  }

  Future<void> _onFetchTickets(
    FetchSupportTicketsEvent event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    final res = await _supportRepo.getTickets(
      status: event.status,
      page: event.page,
      limit: event.limit,
    );

    res.fold(
      (failure) => emit(state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      )),
      (data) => emit(state.copyWith(
        isLoading: false,
        tickets: data.tickets,
        totalTickets: data.total,
        currentPage: data.page,
        totalPages: data.pages,
        activeStatusFilter: event.status,
      )),
    );
  }

  Future<void> _onSelectTicketDetails(
    SelectTicketDetailsEvent event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    final res = await _supportRepo.getTicketDetails(event.ticketId);

    res.fold(
      (failure) => emit(state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      )),
      (data) => emit(state.copyWith(
        isLoading: false,
        selectedTicket: data.ticket,
        messages: data.messages,
      )),
    );
  }

  Future<void> _onCreateTicket(
    CreateSupportTicketEvent event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(isCreatingTicket: true, clearMessages: true));
    final res = await _supportRepo.createTicket(
      app: event.app,
      category: event.category,
      subject: event.subject,
      description: event.description,
      relatedOrderId: event.relatedOrderId,
      attachments: event.attachments,
    );

    res.fold(
      (failure) => emit(state.copyWith(
        isCreatingTicket: false,
        errorMessage: failure.message,
      )),
      (ticket) {
        final updatedList = [ticket, ...state.tickets];
        emit(state.copyWith(
          isCreatingTicket: false,
          tickets: updatedList,
          newlyCreatedTicket: ticket,
          successMessage: 'Ticket ${ticket.ticketNumber} created successfully!',
        ));
      },
    );
  }

  Future<void> _onReplyTicket(
    ReplySupportTicketEvent event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(isSendingReply: true, clearMessages: true));
    final res = await _supportRepo.replyTicket(
      ticketId: event.ticketId,
      body: event.body,
      attachments: event.attachments,
    );

    res.fold(
      (failure) => emit(state.copyWith(
        isSendingReply: false,
        errorMessage: failure.message,
      )),
      (message) {
        final updatedMessages = [...state.messages, message];
        // Per doc section 4.5: Re-opens ticket when user replies
        final updatedTicket = (state.selectedTicket?.status == 'resolved' ||
                state.selectedTicket?.status == 'closed')
            ? state.selectedTicket?.copyWith(status: 'open')
            : state.selectedTicket;

        emit(state.copyWith(
          isSendingReply: false,
          selectedTicket: updatedTicket ?? state.selectedTicket,
          messages: updatedMessages,
        ));
      },
    );
  }

  void _onResetTicketCreated(
    ResetTicketCreatedEvent event,
    Emitter<SupportState> emit,
  ) {
    emit(state.copyWith(clearNewlyCreatedTicket: true));
  }
}
