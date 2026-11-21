import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/support_ticket_entity.dart';

abstract class ISupportRepository {
  Future<Either<Failure, ({List<SupportTicketEntity> tickets, int total, int page, int pages})>>
      getTickets({
    String? status,
    int page = 1,
    int limit = 20,
  });

  Future<Either<Failure, ({SupportTicketEntity ticket, List<SupportMessageEntity> messages})>>
      getTicketDetails(String ticketId);

  Future<Either<Failure, SupportTicketEntity>> createTicket({
    required String app,
    required String category,
    required String subject,
    required String description,
    String? relatedOrderId,
    List<String>? attachments,
  });

  Future<Either<Failure, SupportMessageEntity>> replyTicket({
    required String ticketId,
    required String body,
    List<String>? attachments,
  });
}
