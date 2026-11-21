import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class OtpSentState extends AuthState {
  final String phone;
  final String message;
  final int expiresIn;
  final String? otp;
  final String? userStatus;

  const OtpSentState({
    required this.phone,
    required this.message,
    this.expiresIn = 300,
    this.otp,
    this.userStatus,
  });

  bool get isReturningInactive => userStatus?.toUpperCase() == 'INACTIVE';

  @override
  List<Object?> get props => [phone, message, expiresIn, otp, userStatus];
}

class EmailOtpSentState extends AuthState {
  final String email;
  final String message;
  final int expiresIn;
  final String? otp;

  const EmailOtpSentState({
    required this.email,
    required this.message,
    this.expiresIn = 300,
    this.otp,
  });

  @override
  List<Object?> get props => [email, message, expiresIn, otp];
}

class CheckMobileCompletedState extends AuthState {
  final String phone;
  final bool exists;
  final String? role;
  final String? status;
  final String? message;
  final String? userId;
  final String? name;
  final String? deliveryPartnerId;
  final String? deliveryPartnerStatus;
  final int? deliveryPartnerDocs;

  const CheckMobileCompletedState({
    required this.phone,
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

  @override
  List<Object?> get props => [
        phone,
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

class AuthenticatedState extends AuthState {
  final UserEntity user;
  const AuthenticatedState(this.user);

  @override
  List<Object?> get props => [user];
}

class UnauthenticatedState extends AuthState {}

class AuthErrorState extends AuthState {
  final String message;
  final bool isNotRegistered;

  const AuthErrorState(this.message, {this.isNotRegistered = false});

  @override
  List<Object?> get props => [message, isNotRegistered];
}

class UserSuspendedState extends AuthState {
  final String message;
  const UserSuspendedState({this.message = 'Account suspended. Contact support.'});

  @override
  List<Object?> get props => [message];
}
