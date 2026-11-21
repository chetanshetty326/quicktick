import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:quicklink/features/auth/data/models/check_mobile_response_model.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';

class MockSecureStorageService implements ISecureStorageService {
  final Map<String, String> _store = {};
  final Map<String, String?> _userData = {};
  bool throwOnIsSessionValid = false;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    _store['accessToken'] = accessToken;
    _store['refreshToken'] = refreshToken;
    _store['sessionExpiry'] = DateTime.now().add(expiryDuration).toIso8601String();
  }

  @override
  Future<String?> getAccessToken() async => _store['accessToken'];

  @override
  Future<String?> getRefreshToken() async => _store['refreshToken'];

  @override
  Future<DateTime?> getSessionExpiry() async {
    final str = _store['sessionExpiry'];
    return str != null ? DateTime.tryParse(str) : null;
  }

  @override
  Future<Duration?> getSessionRemainingTime() async => const Duration(days: 7);

  @override
  Future<void> saveUserRole(String role) async => _store['role'] = role;

  @override
  Future<String?> getUserRole() async => _store['role'];

  @override
  Future<void> saveUserId(String userId) async => _store['userId'] = userId;

  @override
  Future<String?> getUserId() async => _store['userId'];

  @override
  Future<void> saveUserData({
    required String userId,
    required String role,
    String? name,
    String? phone,
    String? email,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    _userData['userId'] = userId;
    _userData['role'] = role;
    _userData['name'] = name;
    _userData['phone'] = phone;
    _userData['email'] = email;
    _store['sessionExpiry'] = DateTime.now().add(expiryDuration).toIso8601String();
  }

  @override
  Future<Map<String, String?>> getUserData() async => Map.from(_userData);

  @override
  Future<bool> isSessionValid() async {
    if (throwOnIsSessionValid) {
      throw Exception('Hardware Keystore timeout simulation');
    }
    return _store.containsKey('accessToken') && _store['accessToken']!.isNotEmpty;
  }

  @override
  Future<void> clearAuthData() async {
    _store.clear();
    _userData.clear();
  }
}

class MockAuthRemoteDataSource implements IAuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool throwNetworkErrorOnGetMe = false;
  bool throw401Unauthorized = false;
  bool throw404NotFound = false;

  @override
  Future<UserEntity> getMe() async {
    if (throwNetworkErrorOnGetMe) {
      throw Exception('SocketException: Failed host lookup: api.quicklink.in');
    }
    if (throw401Unauthorized) {
      throw Exception('DioException [bad response]: 401 Unauthorized invalid_token');
    }
    if (throw404NotFound) {
      throw Exception('DioException [bad response]: 404 Route Not Found');
    }
    return const UserEntity(
      id: 'cust_101',
      name: 'John Doe',
      phone: '9876543210',
      email: 'john@example.com',
      role: UserRole.customer,
    );
  }

  @override
  Future<CheckMobileResponseModel> checkMobile(String mobile) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponseModel> loginWithOtp({
    required String phone,
    required String otp,
    required String role,
    String? name,
    String? challengeId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<SendOtpResponseModel> sendOtp(String phone, {String? name, String? email}) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? challengeId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponseModel> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> logout({String? deviceId, String? fcmToken}) async {
    return true;
  }

  @override
  Future<UserEntity> updateProfile({
    required String name,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, String>> refreshToken(String refreshToken) async {
    return {'accessToken': 'new_token', 'refreshToken': 'new_refresh'};
  }
}

void main() {
  group('Customer App Session Persistence & OEM Keystore Resilience Tests', () {
    late MockSecureStorageService mockStorage;
    late MockAuthRemoteDataSource mockRemoteDataSource;

    setUp(() {
      mockStorage = MockSecureStorageService();
      mockRemoteDataSource = MockAuthRemoteDataSource();
    });

    test('1. Re-opening app emits AuthenticatedState immediately from cached session', () async {
      await mockStorage.saveTokens(
        accessToken: 'jwt_valid_access_token_123',
        refreshToken: 'jwt_valid_refresh_token_456',
      );
      await mockStorage.saveUserData(
        userId: 'cust_101',
        role: 'customer',
        name: 'John Doe',
        phone: '9876543210',
        email: 'john@example.com',
      );

      final bloc = AuthBloc(mockStorage, mockRemoteDataSource);

      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthenticatedState>().having(
            (s) => s.user.phone,
            'user phone',
            '9876543210',
          ),
        ]),
      );

      bloc.add(CheckAuthSessionEvent());
    });

    test('2. Transient network drop or offline cold start maintains AuthenticatedState (does not kick user to Login)', () async {
      await mockStorage.saveTokens(
        accessToken: 'jwt_valid_access_token_123',
        refreshToken: 'jwt_valid_refresh_token_456',
      );
      await mockStorage.saveUserData(
        userId: 'cust_101',
        role: 'customer',
        name: 'John Doe',
        phone: '9876543210',
        email: 'john@example.com',
      );

      // Simulate network socket timeout on cellular or wifi drop
      mockRemoteDataSource.throwNetworkErrorOnGetMe = true;

      final bloc = AuthBloc(mockStorage, mockRemoteDataSource);

      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthenticatedState>().having(
            (s) => s.user.name,
            'persisted user name',
            'John Doe',
          ),
        ]),
      );

      bloc.add(CheckAuthSessionEvent());

      // Ensure storage was NOT wiped
      await Future.delayed(const Duration(milliseconds: 50));
      expect(await mockStorage.getAccessToken(), 'jwt_valid_access_token_123');
    });

    test('3. Transient 404 endpoint or route rewrite does NOT wipe auth data', () async {
      await mockStorage.saveTokens(
        accessToken: 'jwt_valid_access_token_123',
        refreshToken: 'jwt_valid_refresh_token_456',
      );
      await mockStorage.saveUserData(
        userId: 'cust_101',
        role: 'customer',
        name: 'John Doe',
        phone: '9876543210',
        email: 'john@example.com',
      );

      mockRemoteDataSource.throw404NotFound = true;

      final bloc = AuthBloc(mockStorage, mockRemoteDataSource);

      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthenticatedState>(),
        ]),
      );

      bloc.add(CheckAuthSessionEvent());

      await Future.delayed(const Duration(milliseconds: 50));
      expect(await mockStorage.getAccessToken(), 'jwt_valid_access_token_123');
    });

    test('4. OEM Keystore hardware delay/exception falls back to stored user data', () async {
      await mockStorage.saveUserData(
        userId: 'cust_101',
        role: 'customer',
        name: 'John Doe',
        phone: '9876543210',
        email: 'john@example.com',
      );
      mockStorage.throwOnIsSessionValid = true;

      final bloc = AuthBloc(mockStorage, mockRemoteDataSource);

      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthenticatedState>().having(
            (s) => s.user.id,
            'user ID recovered',
            'cust_101',
          ),
        ]),
      );

      bloc.add(CheckAuthSessionEvent());
    });

    test('5. Explicit 401 Unauthorized correctly clears auth data and emits UnauthenticatedState', () async {
      await mockStorage.saveTokens(
        accessToken: 'jwt_revoked_token',
        refreshToken: 'jwt_revoked_refresh',
      );
      await mockStorage.saveUserData(
        userId: 'cust_101',
        role: 'customer',
        name: 'John Doe',
        phone: '9876543210',
      );

      mockRemoteDataSource.throw401Unauthorized = true;

      final bloc = AuthBloc(mockStorage, mockRemoteDataSource);

      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthenticatedState>(), // Optimistic cached
          isA<UnauthenticatedState>(), // Cleared after explicit 401 rejection
        ]),
      );

      bloc.add(CheckAuthSessionEvent());

      await Future.delayed(const Duration(milliseconds: 50));
      expect(await mockStorage.getAccessToken(), isNull);
    });
  });
}
