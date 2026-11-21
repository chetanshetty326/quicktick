import 'package:equatable/equatable.dart';

class DeliveryNotificationEntity extends Equatable {
  final String id;
  final String title;
  final String body;
  final String type; // e.g. 'DELIVERY_ASSIGNED', 'KYC_APPROVED', 'PAYMENT_CREDITED', 'SYSTEM'
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const DeliveryNotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.data,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}';
  }

  DeliveryNotificationEntity copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return DeliveryNotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }

  @override
  List<Object?> get props => [id, title, body, type, isRead, createdAt, data];
}
