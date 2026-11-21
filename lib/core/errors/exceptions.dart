class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({required this.message, this.statusCode});

  @override
  String toString() => 'ServerException: $message (code: $statusCode)';
}

class CacheException implements Exception {
  final String message;
  const CacheException({required this.message});

  @override
  String toString() => 'CacheException: $message';
}

class NetworkException implements Exception {
  final String message;
  const NetworkException({this.message = 'Network connection failure'});

  @override
  String toString() => 'NetworkException: $message';
}

class AuthException implements Exception {
  final String message;
  const AuthException({required this.message});

  @override
  String toString() => 'AuthException: $message';
}

class SecurityException implements Exception {
  final String message;
  const SecurityException({required this.message});

  @override
  String toString() => 'SecurityException: $message';
}

class DuplicateResourceException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const DuplicateResourceException({
    required this.message,
    this.code,
    this.statusCode = 409,
  });

  @override
  String toString() => 'DuplicateResourceException: $message (code: $code)';
}

class OrderCancelNotAllowedException implements Exception {
  final String message;
  final String code;
  final int statusCode;

  const OrderCancelNotAllowedException({
    this.message = 'Cancel attempted after order has been assigned',
    this.code = 'ORDER_CANCEL_NOT_ALLOWED',
    this.statusCode = 409,
  });

  @override
  String toString() => 'OrderCancelNotAllowedException: $message ($code)';
}

class OutOfStockException implements Exception {
  final String message;
  final String code;
  final int statusCode;

  const OutOfStockException({
    this.message = 'Stock changed during checkout. Please review your cart.',
    this.code = 'OUT_OF_STOCK',
    this.statusCode = 409,
  });

  @override
  String toString() => 'OutOfStockException: $message ($code)';
}

