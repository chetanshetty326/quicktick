import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/error/user_suspended_exception.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/core/services/google_auth_service.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';

class MockGoogleAuthService implements IGoogleAuthService {
  GoogleAuthResult? mockResult;
  bool shouldThrow = false;
  String errorMessage = 'Google Sign-In failed';
  bool signOutCalled = false;

  @override
  bool get isSignedIn => mockResult != null;

  @override
  Future<GoogleAuthResult?> signIn() async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return mockResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class MockAuthRemoteDataSource implements IAuthRemoteDataSource {
  AuthResponseModel? googleAuthResponse;
  bool throwSuspended = false;
  String? lastIdToken;
  String? lastRole;
  String? lastSentEmail;
  String? lastRegisteredEmail;
  String? lastUpdatedPhone;

  @override
  Future<SendOtpResponseModel> sendEmailOtp(String email) async {
    lastSentEmail = email;
    return const SendOtpResponseModel(
      success: true,
      message: 'OTP sent to email',
      expiresIn: 300,
      devOtp: '654321',
    );
  }

  @override
  Future<AuthResponseModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String otp,
    String? phone,
    required String role,
  }) async {
    lastRegisteredEmail = email;
    return AuthResponseModel(
      user: UserEntity(
        id: 'email_user_01',
        name: name,
        phone: '', // Simulate backend register returning empty phone so updateProfile fallback triggers
        email: email,
        role: UserRole.customer,
      ),
      accessToken: 'email_access_token',
      refreshToken: 'email_refresh_token',
    );
  }

  @override
  Future<AuthResponseModel> loginWithEmail({
    required String email,
    required String password,
    required String role,
  }) async {
    return AuthResponseModel(
      user: UserEntity(
        id: 'email_user_01',
        name: 'Chetan',
        phone: '9876543210',
        email: email,
        role: UserRole.customer,
      ),
      accessToken: 'email_login_token',
      refreshToken: 'email_login_refresh',
    );
  }

  @override
  Future<UserEntity> updateProfile({
    required String name,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    lastUpdatedPhone = phone;
    return UserEntity(
      id: 'email_user_01',
      name: name,
      phone: phone ?? '',
      email: email,
      role: UserRole.customer,
    );
  }

  @override
  Future<AuthResponseModel> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    lastIdToken = idToken;
    lastRole = role;
    if (throwSuspended) {
      throw const UserSuspendedException('Account suspended for compliance violation');
    }
    return googleAuthResponse ??
        const AuthResponseModel(
          user: UserEntity(
            id: 'google_user_01',
            name: 'Google User',
            phone: '9876543210',
            email: 'google@quicktick.shop',
            role: UserRole.customer,
          ),
          accessToken: 'mock_jwt_access',
          refreshToken: 'mock_jwt_refresh',
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSecureStorageService implements ISecureStorageService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Duration? expiryDuration,
  }) async {
    _storage['accessToken'] = accessToken;
    _storage['refreshToken'] = refreshToken;
  }

  @override
  Future<void> saveUserData({
    required String userId,
    required String role,
    String? name,
    String? phone,
    String? email,
    Duration? expiryDuration,
  }) async {
    _storage['userId'] = userId;
    _storage['role'] = role;
    _storage['name'] = name;
    _storage['phone'] = phone;
    _storage['email'] = email;
  }

  @override
  Future<void> clearAuthData() async {
    _storage.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Google Authentication Clean Architecture & BLoC Tests', () {
    late MockGoogleAuthService mockGoogleAuth;
    late MockAuthRemoteDataSource mockRemoteDataSource;
    late MockSecureStorageService mockSecureStorage;
    late AuthBloc authBloc;

    setUp(() {
      mockGoogleAuth = MockGoogleAuthService();
      mockRemoteDataSource = MockAuthRemoteDataSource();
      mockSecureStorage = MockSecureStorageService();
      authBloc = AuthBloc(
        mockSecureStorage,
        mockRemoteDataSource,
        null, // pushNotificationService
        null, // localCache
        mockGoogleAuth,
      );
    });

    tearDown(() {
      authBloc.close();
    });

    test('1. Successful Google Sign-In emits [AuthLoading, AuthenticatedState] and saves tokens', () async {
      mockGoogleAuth.mockResult = const GoogleAuthResult(
        idToken: 'valid_google_id_token_123',
        email: 'customer@quicktick.shop',
        displayName: 'Aarav Patel',
      );

      final expectedStates = [
        isA<AuthLoading>(),
        isA<AuthenticatedState>().having(
          (s) => s.user.email,
          'user email',
          'google@quicktick.shop',
        ),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const SignInWithGoogleEvent(role: UserRole.customer));
      await pumpEventQueue();

      expect(mockRemoteDataSource.lastIdToken, 'valid_google_id_token_123');
      expect(mockRemoteDataSource.lastRole, 'customer');
      expect(mockSecureStorage._storage['accessToken'], 'mock_jwt_access');
    });

    test('2. User dismisses Google prompt emits [AuthLoading, UnauthenticatedState]', () async {
      mockGoogleAuth.mockResult = null; // User cancelled

      final expectedStates = [
        isA<AuthLoading>(),
        isA<UnauthenticatedState>(),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const SignInWithGoogleEvent(role: UserRole.customer));
    });

    test('3. Google Sign-In exception emits [AuthLoading, AuthErrorState]', () async {
      mockGoogleAuth.shouldThrow = true;
      mockGoogleAuth.errorMessage = 'Google network connection failed';

      final expectedStates = [
        isA<AuthLoading>(),
        isA<AuthErrorState>().having(
          (s) => s.message,
          'error message',
          contains('Google network connection failed'),
        ),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const SignInWithGoogleEvent(role: UserRole.customer));
    });

    test('4. Suspended account during Google Sign-In emits [AuthLoading, UserSuspendedState]', () async {
      mockGoogleAuth.mockResult = const GoogleAuthResult(
        idToken: 'suspended_user_token',
        email: 'suspended@quicktick.shop',
      );
      mockRemoteDataSource.throwSuspended = true;

      final expectedStates = [
        isA<AuthLoading>(),
        isA<UserSuspendedState>().having(
          (s) => s.message,
          'suspension message',
          contains('Account suspended for compliance violation'),
        ),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const SignInWithGoogleEvent(role: UserRole.customer));
    });

    test('5. LogoutEvent triggers Google sign out', () async {
      authBloc.add(LogoutEvent());
      await pumpEventQueue();

      expect(mockGoogleAuth.signOutCalled, isTrue);
    });

    test('6. SendEmailOtpEvent emits [AuthLoading, EmailOtpSentState]', () async {
      final expectedStates = [
        isA<AuthLoading>(),
        isA<EmailOtpSentState>()
            .having((s) => s.email, 'email', 'chetan@gmail.com')
            .having((s) => s.otp, 'dev otp', '654321'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const SendEmailOtpEvent('chetan@gmail.com'));
      await pumpEventQueue();

      expect(mockRemoteDataSource.lastSentEmail, 'chetan@gmail.com');
    });

    test('7. RegisterWithEmailEvent registers with OTP and links phone to profile', () async {
      final expectedStates = [
        isA<AuthLoading>(),
        isA<AuthenticatedState>()
            .having((s) => s.user.email, 'email', 'chetan@gmail.com')
            .having((s) => s.user.phone, 'phone', '9876543210'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const RegisterWithEmailEvent(
        name: 'Chetan',
        email: 'chetan@gmail.com',
        password: 'password123',
        otp: '654321',
        phone: '9876543210',
        role: UserRole.customer,
      ));
      await pumpEventQueue();

      expect(mockRemoteDataSource.lastRegisteredEmail, 'chetan@gmail.com');
      expect(mockRemoteDataSource.lastUpdatedPhone, '9876543210');
      expect(mockSecureStorage._storage['accessToken'], 'email_access_token');
    });

    test('8. LoginWithEmailEvent logs in user and saves tokens', () async {
      final expectedStates = [
        isA<AuthLoading>(),
        isA<AuthenticatedState>()
            .having((s) => s.user.email, 'email', 'chetan@gmail.com')
            .having((s) => s.user.name, 'name', 'Chetan'),
      ];

      expectLater(authBloc.stream, emitsInOrder(expectedStates));

      authBloc.add(const LoginWithEmailEvent(
        email: 'chetan@gmail.com',
        password: 'password123',
        role: UserRole.customer,
      ));
      await pumpEventQueue();

      expect(mockSecureStorage._storage['accessToken'], 'email_login_token');
    });
  });
}

