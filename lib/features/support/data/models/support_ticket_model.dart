import '../../domain/entities/support_ticket_entity.dart';

class SupportMessageModel extends SupportMessageEntity {
  const SupportMessageModel({
    required super.id,
    required super.body,
    required super.senderRole,
    super.isInternalNote = false,
    super.attachments = const [],
    required super.createdAt,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      if (v != null) {
        final parsed = DateTime.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final rawAttachments = json['attachments'];
    final List<String> atts = [];
    if (rawAttachments is List) {
      for (final a in rawAttachments) {
        if (a is Map && a['url'] != null) {
          atts.add(a['url'].toString());
        } else if (a != null) {
          atts.add(a.toString());
        }
      }
    }

    return SupportMessageModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? 'user',
      isInternalNote: json['isInternalNote'] == true,
      attachments: atts,
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'body': body,
      'senderRole': senderRole,
      'isInternalNote': isInternalNote,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class SupportTicketModel extends SupportTicketEntity {
  const SupportTicketModel({
    required super.id,
    required super.ticketNumber,
    required super.userId,
    required super.app,
    required super.category,
    required super.subject,
    required super.description,
    super.status = 'open',
    super.priority = 'medium',
    super.relatedOrderId,
    super.attachments = const [],
    super.createdAt,
    super.updatedAt,
    super.lastMessageAt,
    super.resolvedAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    String parseUserId(dynamic v) {
      if (v is Map) {
        return v['_id']?.toString() ?? v['id']?.toString() ?? '';
      }
      return v?.toString() ?? '';
    }

    final rawAttachments = json['attachments'];
    final List<String> atts = [];
    if (rawAttachments is List) {
      for (final a in rawAttachments) {
        if (a is Map && a['url'] != null) {
          atts.add(a['url'].toString());
        } else if (a != null) {
          atts.add(a.toString());
        }
      }
    }

    return SupportTicketModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      ticketNumber: json['ticketNumber']?.toString() ??
          '#${json['_id']?.toString().substring(0, 6).toUpperCase() ?? "TKT"}',
      userId: parseUserId(json['userId']),
      app: json['app']?.toString() ?? 'customer',
      category: json['category']?.toString() ?? 'other',
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'medium',
      relatedOrderId: json['relatedOrderId']?.toString(),
      attachments: atts,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      lastMessageAt: parseDate(json['lastMessageAt']),
      resolvedAt: parseDate(json['resolvedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'ticketNumber': ticketNumber,
      'userId': userId,
      'app': app,
      'category': category,
      'subject': subject,
      'description': description,
      'status': status,
      'priority': priority,
      if (relatedOrderId != null) 'relatedOrderId': relatedOrderId,
      'attachments': attachments,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lastMessageAt != null) 'lastMessageAt': lastMessageAt!.toIso8601String(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
    };
  }
}
