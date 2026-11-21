import 'package:equatable/equatable.dart';

class RetailerNotificationEntity extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String priority;
  final DateTime? sentAt;
  final DateTime? createdAt;
  final String? orderId;

  const RetailerNotificationEntity({
    required this.id,
    this.userId = '',
    required this.title,
    required this.body,
    this.type = 'ORDER_UPDATE',
    this.isRead = false,
    this.priority = 'MEDIUM',
    this.sentAt,
    this.createdAt,
    this.orderId,
  });

  String get timeAgo {
    final date = createdAt ?? sentAt;
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  RetailerNotificationEntity copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    String? priority,
    DateTime? sentAt,
    DateTime? createdAt,
    String? orderId,
  }) {
    return RetailerNotificationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
    );
  }

  dynamic operator [](String key) {
    switch (key) {
      case 'id':
      case '_id':
        return id;
      case 'userId':
        return userId;
      case 'title':
        return title;
      case 'body':
      case 'message':
        return body;
      case 'type':
        return type;
      case 'read':
      case 'isRead':
        return isRead;
      case 'priority':
        return priority;
      case 'time':
        return timeAgo;
      case 'sentAt':
        return sentAt?.toIso8601String();
      case 'createdAt':
        return createdAt?.toIso8601String();
      case 'orderId':
        return orderId;
      default:
        return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      '_id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'message': body,
      'type': type,
      'read': isRead,
      'isRead': isRead,
      'priority': priority,
      'time': timeAgo,
      'sentAt': sentAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'orderId': orderId,
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        body,
        type,
        isRead,
        priority,
        sentAt,
        createdAt,
        orderId,
      ];
}
