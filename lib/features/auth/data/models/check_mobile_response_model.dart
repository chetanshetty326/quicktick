import 'package:equatable/equatable.dart';

class CheckMobileResponseModel extends Equatable {
  final bool success;
  final bool exists;
  final String? role;
  final String? status;
  final String? message;
  final String? userId;
  final String? name;
  final String? deliveryPartnerId;
  final String? deliveryPartnerStatus;
  final int? deliveryPartnerDocs;

  const CheckMobileResponseModel({
    required this.success,
    required this.exists,
    this.role,
    this.status,
    this.message,
    this.userId,
    this.name,
    this.deliveryPartnerId,
    this.deliveryPartnerStatus,
    this.deliveryPartnerDocs,
  });

  bool get isActive => status?.toUpperCase() == 'ACTIVE';
  bool get isInactive => status?.toUpperCase() == 'INACTIVE';
  bool get isRetailer => role?.toUpperCase() == 'RETAILER';
  bool get isCustomer => role?.toUpperCase() == 'CUSTOMER';
  bool get isDeliveryApproved => deliveryPartnerStatus?.toUpperCase() == 'APPROVED';
  bool get isDeliveryPending => deliveryPartnerStatus?.toUpperCase() == 'PENDING';

  factory CheckMobileResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json);

    final rawExists = data['exists'] ?? json['exists'];
    final bool exists = rawExists == true || rawExists == 1 || rawExists == 'true';

    final String? role = data['role']?.toString() ?? json['role']?.toString();
    final String? status = data['status']?.toString() ?? json['status']?.toString();
    final String? message = json['message']?.toString() ?? data['message']?.toString();

    final String? userId = data['userId']?.toString() ?? json['userId']?.toString() ?? data['_id']?.toString() ?? json['_id']?.toString();
    final String? name = data['name']?.toString() ?? json['name']?.toString();
    final String? deliveryPartnerId = data['deliveryPartnerId']?.toString() ?? json['deliveryPartnerId']?.toString();
    final String? deliveryPartnerStatus = data['deliveryPartnerStatus']?.toString() ?? json['deliveryPartnerStatus']?.toString();
    final int? deliveryPartnerDocs = (data['deliveryPartnerDocs'] as num?)?.toInt() ?? (json['deliveryPartnerDocs'] as num?)?.toInt();

    return CheckMobileResponseModel(
      success: json['success'] == true,
      exists: exists,
      role: role,
      status: status,
      message: message,
      userId: userId,
      name: name,
      deliveryPartnerId: deliveryPartnerId,
      deliveryPartnerStatus: deliveryPartnerStatus,
      deliveryPartnerDocs: deliveryPartnerDocs,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'data': {
          'exists': exists,
          if (role != null) 'role': role,
          if (status != null) 'status': status,
          if (userId != null) 'userId': userId,
          if (name != null) 'name': name,
          if (deliveryPartnerId != null) 'deliveryPartnerId': deliveryPartnerId,
          if (deliveryPartnerStatus != null) 'deliveryPartnerStatus': deliveryPartnerStatus,
          if (deliveryPartnerDocs != null) 'deliveryPartnerDocs': deliveryPartnerDocs,
        },
        if (message != null) 'message': message,
      };

  @override
  List<Object?> get props => [
        success,
        exists,
        role,
        status,
        message,
        userId,
        name,
        deliveryPartnerId,
        deliveryPartnerStatus,
        deliveryPartnerDocs,
      ];
}
