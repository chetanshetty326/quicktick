import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/support_ticket_model.dart';

abstract class ISupportRemoteDataSource {
  Future<({List<SupportTicketModel> tickets, int total, int page, int pages})> getTickets({
    String? status,
    int page = 1,
    int limit = 20,
  });

  Future<({SupportTicketModel ticket, List<SupportMessageModel> messages})> getTicketDetails(
    String ticketId,
  );

  Future<SupportTicketModel> createTicket({
    required String app,
    required String category,
    required String subject,
    required String description,
    String? relatedOrderId,
    List<String>? attachments,
  });

  Future<SupportMessageModel> replyTicket({
    required String ticketId,
    required String body,
    List<String>? attachments,
  });
}

class SupportRemoteDataSourceImpl implements ISupportRemoteDataSource {
  final ApiClient _apiClient;

  SupportRemoteDataSourceImpl(this._apiClient);

  @override
  Future<({List<SupportTicketModel> tickets, int total, int page, int pages})> getTickets({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'limit': limit,
      };

      final response = await _apiClient.get(
        ApiEndpoints.supportTickets,
        queryParameters: query,
      );

      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final dataMap = data['data'] as Map;
        final rawTickets = dataMap['tickets'];
        final rawPagination = dataMap['pagination'] as Map?;

        final List<SupportTicketModel> tickets = [];
        if (rawTickets is List) {
          for (final item in rawTickets) {
            if (item is Map) {
              tickets.add(SupportTicketModel.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }

        final int total = (rawPagination?['total'] as num?)?.toInt() ?? tickets.length;
        final int effPage = (rawPagination?['page'] as num?)?.toInt() ?? page;
        final int pages = (rawPagination?['pages'] as num?)?.toInt() ?? 1;

        return (tickets: tickets, total: total, page: effPage, pages: pages);
      } else if (data is Map && data['data'] is List) {
        final list = (data['data'] as List)
            .whereType<Map>()
            .map((m) => SupportTicketModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        return (tickets: list, total: list.length, page: page, pages: 1);
      }

      return (tickets: <SupportTicketModel>[], total: 0, page: page, pages: 0);
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e, 'Failed to load support tickets'));
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<({SupportTicketModel ticket, List<SupportMessageModel> messages})> getTicketDetails(
    String ticketId,
  ) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.supportTicketDetails(ticketId));
      final data = response.data;

      if (data is Map && data['data'] is Map) {
        final dataMap = data['data'] as Map;
        final rawTicket = dataMap['ticket'] is Map ? dataMap['ticket'] as Map : dataMap;
        final rawMessages = dataMap['messages'];

        final ticket = SupportTicketModel.fromJson(Map<String, dynamic>.from(rawTicket));
        final List<SupportMessageModel> messages = [];

        if (rawMessages is List) {
          for (final m in rawMessages) {
            if (m is Map) {
              final model = SupportMessageModel.fromJson(Map<String, dynamic>.from(m));
              // Section 4.4 Rule: User-facing endpoints must not expose internal support notes.
              if (!model.isInternalNote) {
                messages.add(model);
              }
            }
          }
        }

        return (ticket: ticket, messages: messages);
      }

      throw const ServerException(message: 'Invalid ticket response format');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e, 'Failed to load ticket details'));
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<SupportTicketModel> createTicket({
    required String app,
    required String category,
    required String subject,
    required String description,
    String? relatedOrderId,
    List<String>? attachments,
  }) async {
    try {
      final String? trimmedOrderId = relatedOrderId?.trim();
      final bool isMongoObjectId = trimmedOrderId != null &&
          RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(trimmedOrderId);

      // If user provided an order ID that isn't a 24-char hex Mongo ObjectId,
      // append it to description so support agents see it without triggering a Mongoose CastError (500).
      final String finalDescription = (trimmedOrderId != null &&
              trimmedOrderId.isNotEmpty &&
              !isMongoObjectId)
          ? '$description\n\n[Related Order: $trimmedOrderId]'
          : description;

      final payload = {
        'app': app.toLowerCase(),
        'category': category,
        'subject': subject,
        'description': finalDescription,
        if (isMongoObjectId) 'relatedOrderId': trimmedOrderId,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments.map((url) => {'url': url, 'name': 'attachment'}).toList(),
      };

      final response = await _apiClient.post(
        ApiEndpoints.supportTickets,
        data: payload,
      );

      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return SupportTicketModel.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      } else if (data is Map) {
        return SupportTicketModel.fromJson(Map<String, dynamic>.from(data));
      }

      throw const ServerException(message: 'Failed to create support ticket');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e, 'Failed to create support ticket'));
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<SupportMessageModel> replyTicket({
    required String ticketId,
    required String body,
    List<String>? attachments,
  }) async {
    try {
      final payload = {
        'body': body,
        'attachments': attachments ?? [],
      };

      final response = await _apiClient.post(
        ApiEndpoints.supportTicketMessages(ticketId),
        data: payload,
      );

      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return SupportMessageModel.fromJson(Map<String, dynamic>.from(data['data'] as Map));
      } else if (data is Map) {
        return SupportMessageModel.fromJson(Map<String, dynamic>.from(data));
      }

      throw const ServerException(message: 'Failed to post ticket message');
    } on DioException catch (e) {
      throw ServerException(message: _extractErrorMessage(e, 'Failed to send reply'));
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  String _extractErrorMessage(DioException e, String fallback) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      if (data['error'] is Map && data['error']['message'] != null) {
        return data['error']['message'].toString();
      }
      if (data['error'] is String && (data['error'] as String).isNotEmpty) {
        return data['error'] as String;
      }
      if (data['message'] != null && data['message'].toString().isNotEmpty) {
        return data['message'].toString();
      }
    }
    return e.message ?? fallback;
  }
}
