import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:quicklink/core/network/api_client.dart';
import 'package:quicklink/core/network/api_endpoints.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data.remove(key);

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('Live Backend Connectivity & Retailer Architecture Verification', () {
    late Dio realDio;
    late MockSecureStorage mockSecureStorage;
    late SharedPreferences prefs;
    late SecureStorageService secureStorage;
    late ApiClient apiClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockSecureStorage = MockSecureStorage();
      secureStorage = SecureStorageService(
        storage: mockSecureStorage,
        prefs: prefs,
      );

      realDio = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      apiClient = ApiClient(
        secureStorage: secureStorage,
        dio: realDio,
      );
    });

    test('1. LIVE BACKEND: ApiEndpoints baseUrl is online and responds to public product catalog query', () async {
      final response = await realDio.get('/products');
      expect(response.statusCode, equals(200));
      expect(response.data, isNotNull);
      expect(response.data, isA<Map<String, dynamic>>());
      final map = response.data as Map<String, dynamic>;
      expect(map.containsKey('data') || map.containsKey('success'), isTrue);
    });

    test('2. LIVE BACKEND: Featured products endpoint returns healthy catalog items', () async {
      final response = await realDio.get('/products/featured');
      expect(response.statusCode, equals(200));
      final map = response.data as Map<String, dynamic>;
      expect(map['success'], isTrue);
      expect(map['data'], isA<List>());
    });

    test('3. LIVE BACKEND: Send-OTP endpoint reaches authentication microservice', () async {
      int? statusCode;
      try {
        final response = await realDio.post(
          '/auth/send-otp',
          data: {
            'phone': '9999999999',
            'role': 'retailer',
          },
        );
        statusCode = response.statusCode;
      } on DioException catch (e) {
        statusCode = e.response?.statusCode;
      }
      // Status code 200, 400 (validation/test number), or 429 confirms microservice handled request
      expect(statusCode, isIn([200, 400, 429]));
    });

    test('4. LIVE BACKEND: Protected retailer endpoint without authentication responds with 401 without crashing', () async {
      dynamic thrownError;
      try {
        await apiClient.get('/retailer/orders');
      } catch (e) {
        thrownError = e;
      }
      expect(thrownError, isNotNull);
      // Clean Architecture Failure must be thrown with 401
      expect(thrownError.toString(), contains('401'));
    });

    test('5. CLEAN ARCHITECTURE: SecureStorageService encapsulates token management cleanly', () async {
      await secureStorage.saveTokens(
        accessToken: 'live_test_jwt_access',
        refreshToken: 'live_test_jwt_refresh',
      );

      expect(await secureStorage.getAccessToken(), 'live_test_jwt_access');
      expect(await secureStorage.getRefreshToken(), 'live_test_jwt_refresh');

      // Purge on logout
      await secureStorage.clearAuthData();
      expect(await secureStorage.getAccessToken(), isNull);
      expect(await secureStorage.getRefreshToken(), isNull);
    });
  });
}
