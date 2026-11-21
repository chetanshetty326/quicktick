import 'package:equatable/equatable.dart';

enum FailureType {
  none,
  noInternet,
  serverDown,
  timeout,
  auth,
  validation,
  generic,
}

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  bool get isNetworkOffline => this is NetworkFailure;
  bool get isServerDown => this is ServerFailure && (statusCode == null || statusCode! >= 500);

  FailureType get failureType {
    if (this is NetworkFailure) return FailureType.noInternet;
    if (isServerDown) return FailureType.serverDown;
    if (this is AuthFailure) return FailureType.auth;
    if (this is ValidationFailure) return FailureType.validation;
    return FailureType.generic;
  }

  @override
  List<Object?> get props => [message, statusCode];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No Internet connection. Please check your network.', super.statusCode});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.statusCode});
}

class UserSuspendedFailure extends Failure {
  const UserSuspendedFailure({super.message = 'Account suspended. Contact support.', super.statusCode = 403});
}

class SecurityFailure extends Failure {
  const SecurityFailure({required super.message, super.statusCode});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.statusCode});
}

class DuplicateResourceFailure extends Failure {
  final String? code;
  const DuplicateResourceFailure({required super.message, this.code, super.statusCode = 409});

  @override
  List<Object?> get props => [message, code, statusCode];
}

class OrderCancelNotAllowedFailure extends Failure {
  final String code;
  const OrderCancelNotAllowedFailure({
    super.message = 'Cannot cancel order after it has been assigned to a delivery partner.',
    this.code = 'ORDER_CANCEL_NOT_ALLOWED',
    super.statusCode = 409,
  });

  @override
  List<Object?> get props => [message, code, statusCode];
}

class OutOfStockFailure extends Failure {
  final String code;
  const OutOfStockFailure({
    super.message = 'An item in your cart is now out of stock. Please update your cart to proceed.',
    this.code = 'OUT_OF_STOCK',
    super.statusCode = 409,
  });

  @override
  List<Object?> get props => [message, code, statusCode];
}

class JobTakenFailure extends Failure {
  final String code;
  const JobTakenFailure({
    super.message = "Offer expired. You'll get the next one.",
    this.code = 'JOB_TAKEN',
    super.statusCode = 409,
  });

  @override
  List<Object?> get props => [message, code, statusCode];
}

