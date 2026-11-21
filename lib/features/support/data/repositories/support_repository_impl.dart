import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/support_ticket_entity.dart';
import '../../domain/repositories/support_repository.dart';
import '../datasources/support_remote_data_source.dart';

class SupportRepositoryImpl implements ISupportRepository {
  final ISupportRemoteDataSource _remoteDataSource;

  SupportRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, ({List<SupportTicketEntity> tickets, int total, int page, int pages})>>
      getTickets({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result = await _remoteDataSource.getTickets(
        status: status,
        page: page,
        limit: limit,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch support tickets: $e'));
    }
  }

  @override
  Future<Either<Failure, ({SupportTicketEntity ticket, List<SupportMessageEntity> messages})>>
      getTicketDetails(String ticketId) async {
    try {
      final result = await _remoteDataSource.getTicketDetails(ticketId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load ticket details: $e'));
    }
  }

  @override
  Future<Either<Failure, SupportTicketEntity>> createTicket({
    required String app,
    required String category,
    required String subject,
    required String description,
    String? relatedOrderId,
    List<String>? attachments,
  }) async {
    try {
      final ticket = await _remoteDataSource.createTicket(
        app: app,
        category: category,
        subject: subject,
        description: description,
        relatedOrderId: relatedOrderId,
        attachments: attachments,
      );
      return Right(ticket);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to create support ticket: $e'));
    }
  }

  @override
  Future<Either<Failure, SupportMessageEntity>> replyTicket({
    required String ticketId,
    required String body,
    List<String>? attachments,
  }) async {
    try {
      final message = await _remoteDataSource.replyTicket(
        ticketId: ticketId,
        body: body,
        attachments: attachments,
      );
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to send message: $e'));
    }
  }
}
