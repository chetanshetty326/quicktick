import '../../domain/entities/customer_notification_entity.dart';

class CustomerNotificationModel extends CustomerNotificationEntity {
  const CustomerNotificationModel({
    required super.id,
    super.userId = '',
    required super.title,
    required super.body,
    super.type = 'ORDER_UPDATE',
    super.isRead = false,
    super.priority = 'MEDIUM',
    super.sentAt,
    super.createdAt,
    super.orderId,
  });

  factory CustomerNotificationModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final rawTitle = json['title']?.toString() ?? 'Notification';
    final rawBody = json['body']?.toString() ?? json['message']?.toString() ?? '';
    final rawType = json['type']?.toString().toUpperCase() ?? 'ORDER_UPDATE';
    final isRead = json['read'] == true || json['isRead'] == true;
    final priority = json['priority']?.toString().toUpperCase() ?? 'MEDIUM';
    final userId = json['userId']?.toString() ?? '';

    DateTime? sentAt;
    if (json['sentAt'] != null) {
      sentAt = DateTime.tryParse(json['sentAt'].toString());
    }

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      createdAt = DateTime.tryParse(json['createdAt'].toString());
    }

    // Smart order ID extraction:
    // 1. direct key 'orderId'
    // 2. nested data.orderId
    // 3. regex match 'QC-XXXXXX-XXXX' inside message body or title
    String? orderId = json['orderId']?.toString();
    if (orderId == null && json['data'] is Map) {
      orderId = (json['data'] as Map)['orderId']?.toString();
    }
    if (orderId == null || orderId.isEmpty) {
      final regMatch = RegExp(r'QC-\d{6}-\d{4}').firstMatch('$rawTitle $rawBody');
      if (regMatch != null) {
        orderId = regMatch.group(0);
      }
    }

    return CustomerNotificationModel(
      id: rawId,
      userId: userId,
      title: rawTitle,
      body: rawBody,
      type: rawType,
      isRead: isRead,
      priority: priority,
      sentAt: sentAt,
      createdAt: createdAt,
      orderId: orderId,
    );
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
      'orderId': ?orderId,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
