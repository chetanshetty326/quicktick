import 'package:equatable/equatable.dart';

/// Clean Architecture Entity for support ticket conversation messages.
class SupportMessageEntity extends Equatable {
  final String id;
  final String body;
  final String senderRole; // 'user', 'agent', 'system', 'admin'
  final bool isInternalNote;
  final List<String> attachments;
  final DateTime createdAt;

  const SupportMessageEntity({
    required this.id,
    required this.body,
    required this.senderRole,
    this.isInternalNote = false,
    this.attachments = const [],
    required this.createdAt,
  });

  bool get isFromUser => senderRole == 'user';

  @override
  List<Object?> get props => [id, body, senderRole, isInternalNote, attachments, createdAt];
}

/// Clean Architecture Entity representing a Customer / Partner Support Ticket.
class SupportTicketEntity extends Equatable {
  final String id;
  final String ticketNumber;
  final String userId;
  final String app; // 'customer', 'rider', 'retailer'
  final String category; // 'order_issue', 'refund', 'payment', 'delivery', 'account', 'technical', 'other'
  final String subject;
  final String description;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final String priority; // 'low', 'medium', 'high'
  final String? relatedOrderId;
  final List<String> attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final DateTime? resolvedAt;

  const SupportTicketEntity({
    required this.id,
    required this.ticketNumber,
    required this.userId,
    required this.app,
    required this.category,
    required this.subject,
    required this.description,
    this.status = 'open',
    this.priority = 'medium',
    this.relatedOrderId,
    this.attachments = const [],
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.resolvedAt,
  });

  bool get isOpen => status == 'open' || status == 'in_progress';
  bool get isResolved => status == 'resolved';
  bool get isClosed => status == 'closed';

  SupportTicketEntity copyWith({
    String? id,
    String? ticketNumber,
    String? userId,
    String? app,
    String? category,
    String? subject,
    String? description,
    String? status,
    String? priority,
    String? relatedOrderId,
    List<String>? attachments,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    DateTime? resolvedAt,
  }) {
    return SupportTicketEntity(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      userId: userId ?? this.userId,
      app: app ?? this.app,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      relatedOrderId: relatedOrderId ?? this.relatedOrderId,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        ticketNumber,
        userId,
        app,
        category,
        subject,
        description,
        status,
        priority,
        relatedOrderId,
        attachments,
        createdAt,
        updatedAt,
        lastMessageAt,
        resolvedAt,
      ];
}
