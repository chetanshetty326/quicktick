import '../../domain/entities/delivery_notification_entity.dart';

class DeliveryNotificationModel extends DeliveryNotificationEntity {
  const DeliveryNotificationModel({
    required super.id,
    required super.title,
    required super.body,
    required super.type,
    super.isRead,
    required super.createdAt,
    super.data,
  });

  factory DeliveryNotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? extraData;
    if (json['data'] is Map<String, dynamic>) {
      extraData = json['data'] as Map<String, dynamic>;
    } else if (json['data'] is Map) {
      extraData = Map<String, dynamic>.from(json['data'] as Map);
    }

    final rawCreatedAt = json['createdAt']?.toString();
    final parsedDate = rawCreatedAt != null
        ? DateTime.tryParse(rawCreatedAt) ?? DateTime.now()
        : DateTime.now();

    return DeliveryNotificationModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'SYSTEM',
      isRead: json['isRead'] == true || json['read'] == true,
      createdAt: parsedDate,
      data: extraData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      if (data != null) 'data': data,
    };
  }
}
