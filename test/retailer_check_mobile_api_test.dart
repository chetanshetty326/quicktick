import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:quicklink/core/network/api_client.dart';
import 'package:quicklink/core/network/api_endpoints.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:quicklink/features/auth/data/models/check_mobile_response_model.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';

class MockStorageForCheckMobile implements ISecureStorageService {
  final Map<String, dynamic> _data = {
    'accessToken': 'test_existing_token_xyz',
    'refreshToken': 'test_refresh_token_xyz',
    'role': 'retailer',
  };

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Duration? expiryDuration,
  }) async {
    _data['accessToken'] = accessToken;
    _data['refreshToken'] = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _data['accessToken'] as String?;

  @override
  Future<String?> getRefreshToken() async => _data['refreshToken'] as String?;

  @override
  Future<void> saveUserData({
    required String userId,
    required String role,
    required String name,
    required String phone,
    String? email,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    _data['userId'] = userId;
    _data['role'] = role;
    _data['name'] = name;
    _data['phone'] = phone;
  }

  @override
  Future<Map<String, String?>> getUserData() async => {
        'userId': _data['userId'] as String?,
        'role': _data['role'] as String?,
        'name': _data['name'] as String?,
        'phone': _data['phone'] as String?,
      };

  @override
  Future<void> saveUserId(String userId) async => _data['userId'] = userId;

  @override
  Future<String?> getUserId() async => _data['userId'] as String?;

  @override
  Future<DateTime?> getSessionExpiry() async => DateTime.now().add(const Duration(days: 7));

  @override
  Future<Duration?> getSessionRemainingTime() async => const Duration(days: 7);

  @override
  Future<void> saveUserRole(String role) async => _data['role'] = role;

  @override
  Future<String?> getUserRole() async => _data['role'] as String?;

  @override
  Future<bool> isSessionValid() async => true;

  @override
  Future<void> clearAuthData() async => _data.clear();
}

void main() {
  group('Check Mobile API Specification Tests (POST /auth/check-mobile)', () {
    test('1. Parses Response — User Exists (role: RETAILER, status: ACTIVE, userId, name)', () {
      final userExistsJson = {
        'success': true,
        'data': {
          'exists': true,
          'role': 'RETAILER',
          'status': 'ACTIVE',
          'userId': '6aad88d53b3d42358b36f846',
          'name': 'Hemanth'
        }
      };

      final model = CheckMobileResponseModel.fromJson(userExistsJson);

      expect(model.success, isTrue);
      expect(model.exists, isTrue);
      expect(model.role, 'RETAILER');
      expect(model.status, 'ACTIVE');
      expect(model.userId, '6aad88d53b3d42358b36f846');
      expect(model.name, 'Hemanth');
      expect(model.isActive, isTrue);
      expect(model.isInactive, isFalse);
      expect(model.isRetailer, isTrue);
    });

    test('2. Parses Response — User Does Not Exist (exists: false, role: null, status: null)', () {
      final userNotExistJson = {
        'success': true,
        'data': {
          'exists': false,
          'role': null,
          'status': null
        }
      };

      final model = CheckMobileResponseModel.fromJson(userNotExistJson);

      expect(model.success, isTrue);
      expect(model.exists, isFalse);
      expect(model.role, isNull);
      expect(model.status, isNull);
      expect(model.userId, isNull);
      expect(model.name, isNull);
      expect(model.isActive, isFalse);
      expect(model.isInactive, isFalse);
      expect(model.isRetailer, isFalse);
    });

    test('3. CheckMobileCompletedState reflects exact user exists and does not exist data', () {
      const stateExists = CheckMobileCompletedState(
        phone: '7777777702',
        exists: true,
        role: 'RETAILER',
        status: 'ACTIVE',
        userId: '6aad88d53b3d42358b36f846',
        name: 'Hemanth',
      );

      expect(stateExists.exists, isTrue);
      expect(stateExists.role, 'RETAILER');
      expect(stateExists.status, 'ACTIVE');
      expect(stateExists.userId, '6aad88d53b3d42358b36f846');
      expect(stateExists.name, 'Hemanth');
      expect(stateExists.isActive, isTrue);
      expect(stateExists.isRetailer, isTrue);

      const stateNotExists = CheckMobileCompletedState(
        phone: '7777777702',
        exists: false,
        role: null,
        status: null,
      );

      expect(stateNotExists.exists, isFalse);
      expect(stateNotExists.role, isNull);
      expect(stateNotExists.status, isNull);
      expect(stateNotExists.isActive, isFalse);
      expect(stateNotExists.isRetailer, isFalse);
    });

    test('4. ApiClient strips Authorization header for POST /auth/check-mobile', () async {
      final storage = MockStorageForCheckMobile();
      final dio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));

      RequestOptions? capturedOptions;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedOptions = options;
          return handler.resolve(Response(
            requestOptions: options,
            data: {
              'success': true,
              'data': {
                'exists': true,
                'role': 'RETAILER',
                'status': 'ACTIVE',
                'userId': '6aad88d53b3d42358b36f846',
                'name': 'Hemanth'
              }
            },
            statusCode: 200,
          ));
        },
      ));

      final apiClient = ApiClient(secureStorage: storage, dio: dio);
      final remoteDataSource = AuthRemoteDataSourceImpl(apiClient);

      final result = await remoteDataSource.checkMobile('+917777777702');

      expect(result.exists, isTrue);
      expect(result.role, 'RETAILER');
      expect(result.name, 'Hemanth');
      expect(result.userId, '6aad88d53b3d42358b36f846');

      // Verify request payload only contains 'mobile' formatted as +91...
      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.path, ApiEndpoints.checkMobile);
      expect(capturedOptions!.data, isA<Map<String, dynamic>>());
      final reqBody = capturedOptions!.data as Map<String, dynamic>;
      expect(reqBody['mobile'], '+917777777702');
      expect(reqBody.containsKey('phone'), isFalse);

      // Verify NO Authorization header is sent (Authentication: No auth required)
      expect(capturedOptions!.headers.containsKey('Authorization'), isFalse);
    });

    test('5. AuthRemoteDataSource handles User Does Not Exist 200 response', () async {
      final storage = MockStorageForCheckMobile();
      final dio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.resolve(Response(
            requestOptions: options,
            data: {
              'success': true,
              'data': {
                'exists': false,
                'role': null,
                'status': null
              }
            },
            statusCode: 200,
          ));
        },
      ));

      final apiClient = ApiClient(secureStorage: storage, dio: dio);
      final remoteDataSource = AuthRemoteDataSourceImpl(apiClient);

      final result = await remoteDataSource.checkMobile('7777777702');

      expect(result.exists, isFalse);
      expect(result.role, isNull);
      expect(result.status, isNull);
    });

    test('6. AuthRemoteDataSource handles 404 User Not Found as exists: false', () async {
      final storage = MockStorageForCheckMobile();
      final dio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 404,
              data: {
                'success': false,
                'message': 'User not found',
              },
            ),
            type: DioExceptionType.badResponse,
          ));
        },
      ));

      final apiClient = ApiClient(secureStorage: storage, dio: dio);
      final remoteDataSource = AuthRemoteDataSourceImpl(apiClient);

      final result = await remoteDataSource.checkMobile('7777777702');

      expect(result.exists, isFalse);
      expect(result.role, isNull);
      expect(result.status, isNull);
    });
  });
}
