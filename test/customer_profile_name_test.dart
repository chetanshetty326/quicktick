import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_event.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_state.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/data/models/check_mobile_response_model.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';

class MockTestSecureStorage implements ISecureStorageService {
  final Map<String, dynamic> _data = {};

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
    if (email != null) _data['email'] = email;
  }

  @override
  Future<Map<String, String?>> getUserData() async {
    return {
      'userId': _data['userId'] as String?,
      'role': _data['role'] as String?,
      'name': _data['name'] as String?,
      'phone': _data['phone'] as String?,
      'email': _data['email'] as String?,
    };
  }

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

class MockAuthRemoteDataSource implements IAuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  String currentName = 'Test 9309';

  @override
  Future<CheckMobileResponseModel> checkMobile(String phone) async {
    return const CheckMobileResponseModel(
      success: true,
      exists: true,
      role: 'customer',
    );
  }

  @override
  Future<SendOtpResponseModel> sendOtp(String phone, {String? email, String? name}) async {
    return const SendOtpResponseModel(
      success: true,
      message: 'OTP sent successfully',
      expiresIn: 300,
      otp: '123456',
    );
  }

  @override
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? challengeId,
  }) async {
    return AuthResponseModel(
      accessToken: 'token_123',
      refreshToken: 'refresh_123',
      user: UserEntity(
        id: 'cust_01',
        name: currentName,
        phone: phone,
        role: UserRole.customer,
      ),
    );
  }

  @override
  Future<AuthResponseModel> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    return AuthResponseModel(
      accessToken: 'token_123',
      refreshToken: 'refresh_123',
      user: UserEntity(
        id: 'cust_01',
        name: currentName,
        phone: '9876543210',
        role: UserRole.customer,
      ),
    );
  }

  @override
  Future<UserEntity> getMe() async {
    return UserEntity(
      id: 'cust_01',
      name: currentName,
      phone: '9876543210',
      role: UserRole.customer,
    );
  }

  @override
  Future<UserEntity> updateProfile({
    required String name,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    currentName = name;
    return UserEntity(
      id: 'cust_01',
      name: currentName,
      phone: phone ?? '9876543210',
      email: email,
      role: UserRole.customer,
    );
  }

  @override
  Future<Map<String, String>> refreshToken(String refreshToken) async {
    return {'accessToken': 'new_access', 'refreshToken': 'new_refresh'};
  }

  @override
  Future<bool> logout({String? deviceId, String? fcmToken}) async => true;
}

void main() {
  group('Customer Profile Name Update & Persistence Tests', () {
    late MockTestSecureStorage secureStorage;
    late MockAuthRemoteDataSource remoteDataSource;
    late AuthBloc authBloc;

    setUp(() {
      secureStorage = MockTestSecureStorage();
      remoteDataSource = MockAuthRemoteDataSource();
      authBloc = AuthBloc(secureStorage, remoteDataSource);
    });

    tearDown(() {
      authBloc.close();
    });

    test('Entering name during LoginWithOtpEvent updates profile name and syncs to backend', () async {
      authBloc.add(const LoginWithOtpEvent(
        name: 'Chetan Shetty',
        phone: '9876543210',
        otp: '123456',
        role: UserRole.customer,
      ));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthenticatedState>((state) {
            return state.user.name == 'Chetan Shetty';
          }),
        ]),
      );

      // Verify stored in secure storage
      final userData = await secureStorage.getUserData();
      expect(userData['name'], 'Chetan Shetty');

      // Verify synced to backend remote data source
      expect(remoteDataSource.currentName, 'Chetan Shetty');
    });

    test('CheckAuthSessionEvent preserves custom name and does not discard Chetan Shetty', () async {
      await secureStorage.saveTokens(accessToken: 'token_123', refreshToken: 'refresh_123');
      await secureStorage.saveUserData(
        userId: 'cust_01',
        role: 'customer',
        name: 'Chetan Shetty',
        phone: '9876543210',
      );

      // Remote backend might return stale placeholder
      remoteDataSource.currentName = 'Test 9309';

      authBloc.add(CheckAuthSessionEvent());

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthenticatedState>((state) => state.user.name == 'Chetan Shetty'),
        ]),
      );
    });
  });
}
