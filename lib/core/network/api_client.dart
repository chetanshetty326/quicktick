import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../errors/failures.dart';
import '../security/secure_storage_service.dart';
import 'api_endpoints.dart';

class ApiClient {
  final Dio _dio;
  final ISecureStorageService _secureStorage;
  Completer<String?>? _refreshCompleter;

  ApiClient({
    required ISecureStorageService secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiEndpoints.baseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 10),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getAccessToken();

          if (options.path.startsWith('/auth/check-mobile') ||
              options.path.startsWith('/auth/send-otp') ||
              options.path.startsWith('/auth/verify-otp') ||
              options.path.startsWith('/auth/email') ||
              options.path.startsWith('/auth/google') ||
              options.path.startsWith('/hero-banners')) {
            options.headers.remove('Authorization');
          } else if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            debugPrint('🌐 [API REQ] ${options.method} ${options.baseUrl}${options.path}');
            if (options.queryParameters.isNotEmpty) {
              debugPrint('   Query: ${options.queryParameters}');
            }
            if (options.data != null) {
              debugPrint('   Body: ${options.data}');
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('📥 [API RES ${response.statusCode}] ${response.requestOptions.path}');
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          final statusCode = error.response?.statusCode;
          if ((statusCode == 401 || statusCode == 403) && !error.requestOptions.path.startsWith('/auth/')) {
            try {
              String? newToken;

              // Orderly Line (Mutex): If another request is currently refreshing the token, wait for it!
              if (_refreshCompleter != null) {
                newToken = await _refreshCompleter!.future;
              } else {
                final completer = Completer<String?>();
                _refreshCompleter = completer;
                try {
                  newToken = await _performTokenRefresh(error.requestOptions);
                  completer.complete(newToken);
                } catch (e) {
                  completer.complete(null);
                  rethrow;
                } finally {
                  _refreshCompleter = null;
                }
              }

              if (newToken != null && newToken.isNotEmpty) {
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newToken';
                final cloneReq = await _dio.fetch(opts);
                return handler.resolve(cloneReq);
              } else {
                // If refresh token is expired or invalid, clear auth tokens to prevent zombie session state
                await _secureStorage.clearAuthData();
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('⚠️ [API REAUTH RETRY FAILED] ${error.requestOptions.path}: $e');
              }
              await _secureStorage.clearAuthData();
            }
          }
          if (kDebugMode) {
            debugPrint('❌ [API ERR ${error.response?.statusCode}] ${error.requestOptions.path}: ${error.message}');
          }
          return handler.next(error);
        },
      ),
    );

    // Sentry interceptor must be added last so it captures all outgoing requests & transformations
    _dio.addSentry(
      captureFailedRequests: true,
      failedRequestStatusCodes: [
        SentryStatusCode.range(400, 599),
      ],
    );
  }

  Future<String?> _performTokenRefresh(RequestOptions requestOptions) async {
    try {
      final storedRefresh = await _secureStorage.getRefreshToken();
      if (storedRefresh == null || storedRefresh.isEmpty) {
        return null;
      }

      final dioAuth = Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        headers: {'Content-Type': 'application/json'},
      ));

      String? newToken;
      String? newRefreshToken;

      // Legitimate token refresh using cryptographically verified refreshToken
      final refreshRes = await dioAuth.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': storedRefresh},
      );
      if (refreshRes.data is Map && refreshRes.data['data'] is Map) {
        final tokens = refreshRes.data['data']['tokens'] ?? refreshRes.data['data'];
        newToken = tokens['accessToken']?.toString();
        newRefreshToken = tokens['refreshToken']?.toString();
      }

      if (newToken != null && newToken.isNotEmpty) {
        final resolvedRefreshToken = (newRefreshToken != null && newRefreshToken.isNotEmpty)
            ? newRefreshToken
            : storedRefresh;
        await _secureStorage.saveTokens(
          accessToken: newToken,
          refreshToken: resolvedRefreshToken,
          expiryDuration: const Duration(days: 7),
        );
        return newToken;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [API REAUTH FAILED] ${requestOptions.path}: $e');
      }
    }
    return null;
  }

  Dio get dio => _dio;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Failure _handleDioError(DioException error) {
    if (error.error is SocketException ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const NetworkFailure(
        message: 'Unable to reach the server. Please check your internet connection.',
      );
    }

    final response = error.response;
    final statusCode = response?.statusCode;

    // Extract message and error details from backend response
    String? backendMessage;
    String? errorCode;

    dynamic responseData = response?.data;
    if (responseData is List<int> && responseData.isNotEmpty) {
      try {
        final decoded = utf8.decode(responseData, allowMalformed: true).trim();
        if (decoded.startsWith('{') || decoded.startsWith('[')) {
          responseData = jsonDecode(decoded);
        }
      } catch (_) {}
    }

    if (responseData is Map) {
      final map = responseData;
      if (map['error'] is Map) {
        final errMap = map['error'] as Map;
        errorCode = errMap['code']?.toString();
        if (errMap['details'] is Map) {
          final details = errMap['details'] as Map;
          final detailMessages = <String>[];
          for (final entry in details.entries) {
            if (entry.value is Map && entry.value['message'] != null) {
              detailMessages.add(entry.value['message'].toString());
            }
          }
          if (detailMessages.isNotEmpty) {
            backendMessage = detailMessages.join(', ');
          }
        }
        backendMessage ??= errMap['message']?.toString() ?? errMap['code']?.toString();
      } else if (map['errors'] is List && (map['errors'] as List).isNotEmpty) {
        final firstErr = (map['errors'] as List).first;
        if (firstErr is Map && firstErr['message'] != null) {
          backendMessage = firstErr['message'].toString();
        } else {
          backendMessage = firstErr.toString();
        }
      } else if (map['message'] != null) {
        backendMessage = map['message'].toString();
      } else if (map['error'] != null) {
        backendMessage = map['error'].toString();
      }
    }

    if (statusCode == 401) {
      return AuthFailure(
        message: backendMessage ?? 'Authentication session expired. Please log in again.',
        statusCode: 401,
      );
    }

    if (statusCode == 403) {
      final msg = errorCode == 'USER_SUSPENDED'
          ? 'Your account has been suspended. Please contact customer support.'
          : errorCode == 'RETAILER_NOT_APPROVED'
              ? 'Your store account is pending admin approval.'
              : (backendMessage ?? 'Access forbidden. You do not have permission for this action.');
      return AuthFailure(
        message: msg,
        statusCode: 403,
      );
    }

    if (statusCode == 400) {
      if (errorCode == 'OUT_OF_SERVICE_AREA') {
        return const ValidationFailure(
          message: 'Your shop or service location is outside our operational service area.',
          statusCode: 400,
        );
      }
      if (errorCode == 'LOCATION_REQUIRED') {
        return const ValidationFailure(
          message: 'Location coordinates are required to proceed.',
          statusCode: 400,
        );
      }
      if (errorCode == 'DELIVERY_ALREADY_REGISTERED' ||
          (backendMessage?.toLowerCase().contains('already has a profile') == true)) {
        return DuplicateResourceFailure(
          message: 'A delivery partner profile is already registered with this mobile number.',
          code: 'DELIVERY_ALREADY_REGISTERED',
          statusCode: 409,
        );
      }
      return ValidationFailure(
        message: backendMessage ?? 'Invalid request parameters. Please verify entered details.',
        statusCode: 400,
      );
    }

    if (statusCode == 409) {
      if (errorCode == 'RESOURCE_ALREADY_EXISTS' ||
          (backendMessage?.toLowerCase().contains('shop name') == true)) {
        return DuplicateResourceFailure(
          message: backendMessage ?? 'Shop name already taken. Please choose another shop name.',
          code: errorCode ?? 'RESOURCE_ALREADY_EXISTS',
          statusCode: 409,
        );
      }
      if (backendMessage?.toLowerCase().contains('already registered') == true) {
        return DuplicateResourceFailure(
          message: backendMessage ?? 'Partner already registered with this account.',
          code: errorCode ?? 'PARTNER_ALREADY_REGISTERED',
          statusCode: 409,
        );
      }
      return ValidationFailure(
        message: backendMessage ?? 'Resource conflict or item already exists.',
        statusCode: 409,
      );
    }

    if (statusCode == 422) {
      return ValidationFailure(
        message: backendMessage ?? 'Invalid state transition for this order.',
        statusCode: 422,
      );
    }

    if (statusCode == 404) {
      return ServerFailure(
        message: backendMessage ?? 'The requested resource or endpoint was not found.',
        statusCode: 404,
      );
    }

    if (statusCode == 429) {
      return const NetworkFailure(
        message: 'Too many requests. Please wait a moment before trying again.',
        statusCode: 429,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      String userFriendly5xx;
      if (statusCode == 502) {
        userFriendly5xx = 'Server is temporarily unreachable. Please try again in a few moments.';
      } else if (statusCode == 503) {
        userFriendly5xx = 'Server is currently undergoing maintenance. Please try again shortly.';
      } else if (statusCode == 504) {
        userFriendly5xx = 'Server response timed out. Please check your internet connection and try again.';
      } else {
        userFriendly5xx = 'Something went wrong on our server. Please try again shortly.';
      }

      final isCleanMsg = backendMessage != null &&
          backendMessage.isNotEmpty &&
          !backendMessage.contains('Exception') &&
          !backendMessage.contains('Error:') &&
          !backendMessage.toLowerCase().contains('sequelize') &&
          !backendMessage.toLowerCase().contains('internal server error');

      return ServerFailure(
        message: isCleanMsg ? backendMessage : userFriendly5xx,
        statusCode: statusCode,
      );
    }

    final fallbackMsg = backendMessage ??
        ((error.message != null && !error.message!.contains('DioException'))
            ? error.message!
            : 'A server error occurred. Please try again later.');

    return ServerFailure(message: fallbackMsg, statusCode: statusCode);
  }
}
