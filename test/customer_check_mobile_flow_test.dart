import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:quicklink/features/auth/data/models/check_mobile_response_model.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';

class MockSecureStorageService implements ISecureStorageService {
  final Map<String, String> _store = {};
  final Map<String, String?> _userData = {};

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
    required String name,
    required String phone,
    String? email,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    _userData['userId'] = userId;
    _userData['role'] = role;
    _userData['name'] = name;
    _userData['phone'] = phone;
    _userData['email'] = email;
  }

  @override
  Future<Map<String, String?>> getUserData() async => Map.from(_userData);

  @override
  Future<bool> isSessionValid() async => _store.containsKey('accessToken');

  @override
  Future<void> clearAuthData() async {
    _store.clear();
    _userData.clear();
  }

  @override
  Future<void> saveRiderKycData(String kycJson, {String? phoneSuffix}) async => _store['rider_kyc_${phoneSuffix ?? 'default'}'] = kycJson;

  @override
  Future<String?> getRiderKycData({String? phoneSuffix}) async => _store['rider_kyc_${phoneSuffix ?? 'default'}'];

  @override
  Future<void> clearRiderKycData({String? phoneSuffix}) async => _store.remove('rider_kyc_${phoneSuffix ?? 'default'}');
}

class FakeAuthRemoteDataSource implements IAuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final Map<String, CheckMobileResponseModel> registeredNumbers = {};
  bool logoutCalled = false;

  @override
  Future<CheckMobileResponseModel> checkMobile(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (registeredNumbers.containsKey(clean)) {
      return registeredNumbers[clean]!;
    }
    return const CheckMobileResponseModel(
      success: true,
      exists: false,
      message: 'Mobile number not registered. Please register first.',
    );
  }

  @override
  Future<SendOtpResponseModel> sendOtp(String phone, {String? name, String? email}) async {
    return const SendOtpResponseModel(
      success: true,
      message: 'OTP sent successfully',
      expiresIn: 300,
      otp: '123456',
      devOtp: '123456',
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
      user: UserEntity(
        id: 'user_1',
        name: 'Honey',
        phone: phone,
        role: UserRole.customer,
        status: 'ACTIVE',
      ),
      accessToken: 'token_123',
      refreshToken: 'refresh_123',
    );
  }

  @override
  Future<AuthResponseModel> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    return const AuthResponseModel(
      user: UserEntity(
        id: 'user_1',
        name: 'Honey',
        phone: '9876543210',
        role: UserRole.customer,
        status: 'ACTIVE',
      ),
      accessToken: 'token_123',
      refreshToken: 'refresh_123',
    );
  }

  @override
  Future<bool> logout({String? deviceId, String? fcmToken}) async {
    logoutCalled = true;
    return true;
  }

  @override
  Future<UserEntity> getMe() async {
    return UserEntity(
      id: 'user_1',
      name: 'Honey',
      phone: '9999999901',
      role: UserRole.customer,
      status: 'ACTIVE',
      lastLogoutAt: DateTime.parse('2026-09-15T16:30:00.000Z'),
    );
  }

  @override
  Future<Map<String, String>> refreshToken(String refreshToken) async => {};

  @override
  Future<UserEntity> updateProfile({required String name, String? email, String? phone, String? avatarUrl}) async =>
      throw UnimplementedError();
}

void main() {
  group('Customer App - Check Mobile & Status Flow Tests', () {
    late MockSecureStorageService storageService;
    late FakeAuthRemoteDataSource remoteDataSource;
    late AuthBloc authBloc;

    setUp(() {
      storageService = MockSecureStorageService();
      remoteDataSource = FakeAuthRemoteDataSource();
      authBloc = AuthBloc(storageService, remoteDataSource);
    });

    tearDown(() {
      authBloc.close();
    });

    test('1. Unregistered number blocks OTP and emits required message', () async {
      // 9888888888 is not in registeredNumbers (exists: false)
      final states = <AuthState>[];
      final sub = authBloc.stream.listen(states.add);

      authBloc.add(const SendOtpEvent('9888888888', isRegistration: false));

      await Future.delayed(const Duration(milliseconds: 100));
      sub.cancel();

      expect(states.any((s) => s is AuthErrorState), true);
      final errorState = states.firstWhere((s) => s is AuthErrorState) as AuthErrorState;
      expect(errorState.message, 'Mobile number not registered. Please register first.');
      expect(errorState.isNotRegistered, true);
      expect(states.any((s) => s is OtpSentState), false);
    });

    test('2. Registered ACTIVE number passes check and sends OTP', () async {
      remoteDataSource.registeredNumbers['9999999901'] = const CheckMobileResponseModel(
        success: true,
        exists: true,
        role: 'CUSTOMER',
        status: 'ACTIVE',
      );

      final states = <AuthState>[];
      final sub = authBloc.stream.listen(states.add);

      authBloc.add(const SendOtpEvent('9999999901', isRegistration: false));

      await Future.delayed(const Duration(milliseconds: 100));
      sub.cancel();

      expect(states.any((s) => s is OtpSentState), true);
      final otpState = states.firstWhere((s) => s is OtpSentState) as OtpSentState;
      expect(otpState.userStatus, 'ACTIVE');
      expect(otpState.isReturningInactive, false);
      expect(otpState.otp, '123456');
    });

    test('3. Registered INACTIVE (previously logged out) number sends OTP with returning user status', () async {
      remoteDataSource.registeredNumbers['9999999902'] = const CheckMobileResponseModel(
        success: true,
        exists: true,
        role: 'CUSTOMER',
        status: 'INACTIVE',
      );

      final states = <AuthState>[];
      final sub = authBloc.stream.listen(states.add);

      authBloc.add(const SendOtpEvent('9999999902', isRegistration: false));

      await Future.delayed(const Duration(milliseconds: 100));
      sub.cancel();

      expect(states.any((s) => s is OtpSentState), true);
      final otpState = states.firstWhere((s) => s is OtpSentState) as OtpSentState;
      expect(otpState.userStatus, 'INACTIVE');
      expect(otpState.isReturningInactive, true);
      expect(otpState.message.contains('Welcome back'), true);
    });

    test('4. Sign Up registration flow allows OTP without existing user check', () async {
      final states = <AuthState>[];
      final sub = authBloc.stream.listen(states.add);

      authBloc.add(const SendOtpEvent(
        '9777777777',
        name: 'New Customer',
        email: 'new@example.com',
        isRegistration: true,
      ));

      await Future.delayed(const Duration(milliseconds: 100));
      sub.cancel();

      expect(states.any((s) => s is OtpSentState), true);
      expect(states.any((s) => s is AuthErrorState), false);
    });

    test('5. Logout calls backend API and clears local session tokens', () async {
      await storageService.saveTokens(accessToken: 'token_abc', refreshToken: 'ref_abc');
      expect(await storageService.isSessionValid(), true);

      final states = <AuthState>[];
      final sub = authBloc.stream.listen(states.add);

      authBloc.add(LogoutEvent());

      await Future.delayed(const Duration(milliseconds: 100));
      sub.cancel();

      expect(remoteDataSource.logoutCalled, true);
      expect(await storageService.isSessionValid(), false);
      expect(states.any((s) => s is UnauthenticatedState), true);
    });

    test('6. UserEntity correctly represents status and lastLogoutAt', () {
      final logoutTime = DateTime.parse('2026-09-15T16:30:00.000Z');
      final user = UserEntity(
        id: 'user_1',
        name: 'Honey',
        phone: '+919999999901',
        role: UserRole.customer,
        status: 'ACTIVE',
        lastLogoutAt: logoutTime,
      );

      expect(user.isActive, true);
      expect(user.isInactive, false);
      expect(user.lastLogoutAt, logoutTime);

      final loggedOutUser = user.copyWith(status: 'INACTIVE');
      expect(loggedOutUser.isActive, false);
      expect(loggedOutUser.isInactive, true);
    });
  });
}
