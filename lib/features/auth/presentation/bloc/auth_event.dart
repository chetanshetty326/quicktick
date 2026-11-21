import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class CheckAuthSessionEvent extends AuthEvent {}

class CheckMobileEvent extends AuthEvent {
  final String phone;
  const CheckMobileEvent(this.phone);

  @override
  List<Object?> get props => [phone];
}

class SendOtpEvent extends AuthEvent {
  final String phone;
  final String? name;
  final String? email;
  final bool isRegistration;
  /// When true, the check-mobile validation was already done by the caller
  /// (via [CheckMobileEvent]). Skips the redundant internal check.
  final bool preChecked;

  const SendOtpEvent(this.phone,
      {this.name, this.email, this.isRegistration = false, this.preChecked = false});

  @override
  List<Object?> get props => [phone, name, email, isRegistration, preChecked];
}

class SwitchRoleEvent extends AuthEvent {
  final UserRole newRole;
  const SwitchRoleEvent(this.newRole);

  @override
  List<Object?> get props => [newRole];
}

class LoginWithOtpEvent extends AuthEvent {
  final String phone;
  final String otp;
  final String? name;
  final String? email;
  final UserRole role;

  const LoginWithOtpEvent({
    required this.phone,
    required this.otp,
    this.name,
    this.email,
    this.role = UserRole.customer,
  });

  @override
  List<Object?> get props => [phone, otp, name, email, role];
}

class RestoreUserSessionEvent extends AuthEvent {
  final UserEntity user;
  const RestoreUserSessionEvent(this.user);

  @override
  List<Object?> get props => [user];
}

class LogoutEvent extends AuthEvent {}

class SignInWithGoogleEvent extends AuthEvent {
  final UserRole role;

  const SignInWithGoogleEvent({this.role = UserRole.customer});

  @override
  List<Object?> get props => [role];
}

class UpdateProfileEvent extends AuthEvent {
  final String name;
  final String? email;
  final String? phone;

  const UpdateProfileEvent({required this.name, this.email, this.phone});

  @override
  List<Object?> get props => [name, email, phone];
}

class SendEmailOtpEvent extends AuthEvent {
  final String email;

  const SendEmailOtpEvent(this.email);

  @override
  List<Object?> get props => [email];
}

class RegisterWithEmailEvent extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String otp;
  final String? phone;
  final UserRole role;

  const RegisterWithEmailEvent({
    required this.name,
    required this.email,
    required this.password,
    required this.otp,
    this.phone,
    this.role = UserRole.customer,
  });

  @override
  List<Object?> get props => [name, email, password, otp, phone, role];
}

class LoginWithEmailEvent extends AuthEvent {
  final String email;
  final String password;
  final UserRole role;

  const LoginWithEmailEvent({
    required this.email,
    required this.password,
    this.role = UserRole.customer,
  });

  @override
  List<Object?> get props => [email, password, role];
}
