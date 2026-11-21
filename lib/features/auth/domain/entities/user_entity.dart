import 'package:equatable/equatable.dart';

enum UserRole {
  customer,
  retailer,
  deliveryPartner,
  admin;

  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.retailer:
        return 'Store Retailer';
      case UserRole.deliveryPartner:
        return 'Delivery Partner';
      case UserRole.admin:
        return 'Administrator';
    }
  }

  static UserRole fromString(String? role) {
    final normalized = (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (normalized == 'retailer') {
      return UserRole.retailer;
    }
    if (normalized == 'deliverypartner' || normalized == 'delivery') {
      return UserRole.deliveryPartner;
    }
    if (normalized == 'admin') {
      return UserRole.admin;
    }
    return UserRole.customer;
  }
}

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final UserRole role;
  final String? storeName;
  final String? vehicleType;
  final bool isApproved;
  final String status;
  final DateTime? lastLogoutAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.storeName,
    this.vehicleType,
    this.isApproved = true,
    this.status = 'ACTIVE',
    this.lastLogoutAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isInactive => status.toUpperCase() == 'INACTIVE';
  String get mobile => phone;

  UserEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    UserRole? role,
    String? storeName,
    String? vehicleType,
    bool? isApproved,
    String? status,
    DateTime? lastLogoutAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      storeName: storeName ?? this.storeName,
      vehicleType: vehicleType ?? this.vehicleType,
      isApproved: isApproved ?? this.isApproved,
      status: status ?? this.status,
      lastLogoutAt: lastLogoutAt ?? this.lastLogoutAt,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, email, role, storeName, vehicleType, isApproved, status, lastLogoutAt];
}
