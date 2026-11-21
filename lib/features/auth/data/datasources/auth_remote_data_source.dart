import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/error/user_suspended_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/user_entity.dart';
import '../models/check_mobile_response_model.dart';

class AuthResponseModel {
  final UserEntity user;
  final String accessToken;
  final String refreshToken;

  const AuthResponseModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final userMap = data['user'] as Map<String, dynamic>? ?? data;
    final tokensMap = data['tokens'] as Map<String, dynamic>? ?? {};

    final roleStr = userMap['role']?.toString() ?? 'customer';
    final role = UserRole.fromString(roleStr);
    final statusStr = userMap['status']?.toString() ?? 'ACTIVE';
    final lastLogoutStr = userMap['lastLogoutAt']?.toString();
    final lastLogout = lastLogoutStr != null ? DateTime.tryParse(lastLogoutStr) : null;

    final user = UserEntity(
      id: userMap['id'] ?? userMap['_id'] ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: userMap['name']?.toString() ?? 'Customer',
      phone: userMap['mobile']?.toString() ?? userMap['phone']?.toString() ?? '',
      email: userMap['email']?.toString(),
      role: role,
      storeName: userMap['storeName']?.toString(),
      isApproved: userMap['isVerified'] ?? userMap['isActive'] ?? true,
      status: statusStr,
      lastLogoutAt: lastLogout,
    );

    final token = data['accessToken']?.toString() ?? tokensMap['accessToken']?.toString() ?? '';
    final refresh = data['refreshToken']?.toString() ?? tokensMap['refreshToken']?.toString() ?? '';

    return AuthResponseModel(
      user: user,
      accessToken: token,
      refreshToken: refresh,
    );
  }
}

class SendOtpResponseModel {
  final bool success;
  final String message;
  final int expiresIn;
  final String? otp;
  final String? devOtp;
  final String? challengeId;

  const SendOtpResponseModel({
    required this.success,
    required this.message,
    required this.expiresIn,
    this.otp,
    this.devOtp,
    this.challengeId,
  });

  factory SendOtpResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map : {};
    final resolvedDevOtp = json['devOpt']?.toString() ??
        json['devOtp']?.toString() ??
        data['devOpt']?.toString() ??
        data['devOtp']?.toString();
    final resolvedOtp = resolvedDevOtp ?? json['otp']?.toString() ?? data['otp']?.toString();

    return SendOtpResponseModel(
      success: json['success'] == true || json['status'] == 'success',
      message: json['message']?.toString() ?? 'OTP sent successfully',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 300,
      otp: resolvedOtp,
      devOtp: resolvedDevOtp,
      challengeId: data['challenged']?.toString() ??
          data['challengeId']?.toString() ??
          json['challenged']?.toString() ??
          json['challengeId']?.toString(),
    );
  }
}

abstract class IAuthRemoteDataSource {
  Future<CheckMobileResponseModel> checkMobile(String phone);
  Future<SendOtpResponseModel> sendOtp(String phone, {String? name, String? email});
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? challengeId,
  });
  Future<AuthResponseModel> signInWithGoogle({
    required String idToken,
    required String role,
  });
  Future<SendOtpResponseModel> sendEmailOtp(String email);
  Future<AuthResponseModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String otp,
    String? phone,
    required String role,
  });
  Future<AuthResponseModel> loginWithEmail({
    required String email,
    required String password,
    required String role,
  });
  Future<Map<String, String>> refreshToken(String refreshToken);
  Future<bool> logout({String? deviceId, String? fcmToken});
  Future<UserEntity> getMe();
  Future<UserEntity> updateProfile({
    required String name,
    String? email,
    String? phone,
    String? avatarUrl,
  });
}

class AuthRemoteDataSourceImpl implements IAuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  /// Robust phone sanitization: extracts last 10 digits for Indian standard numbers
  static String sanitizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  @override
  Future<CheckMobileResponseModel> checkMobile(String phone) async {
    final cleanPhone = sanitizePhone(phone);
    final formattedMobile = cleanPhone.startsWith('+') ? cleanPhone : '+91$cleanPhone';

    try {
      // 1. Primary check with 10-digit clean phone (standard for web registration & backend DB)
      final response = await _apiClient.post(
        ApiEndpoints.checkMobile,
        data: {
          'mobile': cleanPhone,
        },
      );

      final data = response.data;
      CheckMobileResponseModel? model;
      if (data is Map<String, dynamic>) {
        model = CheckMobileResponseModel.fromJson(data);
      } else if (data is Map) {
        model = CheckMobileResponseModel.fromJson(Map<String, dynamic>.from(data));
      }

      if (model != null && model.exists) {
        return model;
      }

      // 2. Fallback check with '+91' prefix (in case user was registered with prefix)
      try {
        final fbRes = await _apiClient.post(
          ApiEndpoints.checkMobile,
          data: {
            'mobile': formattedMobile,
          },
        );
        final fbData = fbRes.data;
        if (fbData is Map) {
          final fbModel = CheckMobileResponseModel.fromJson(Map<String, dynamic>.from(fbData));
          if (fbModel.exists) return fbModel;
        }
      } catch (_) {}

      return model ?? const CheckMobileResponseModel(success: true, exists: false);
    } on Failure catch (e) {
      if (e.statusCode == 404) {
        return const CheckMobileResponseModel(
          success: true,
          exists: false,
          role: null,
          status: null,
        );
      }
      return const CheckMobileResponseModel(success: true, exists: true, status: 'ACTIVE');
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map) {
        final innerData = resData['data'];
        if (innerData is Map && (innerData['exists'] == false || innerData['exists'] == true)) {
          return CheckMobileResponseModel.fromJson(Map<String, dynamic>.from(resData));
        }
        if (resData['exists'] == false || resData['exists'] == true) {
          return CheckMobileResponseModel.fromJson(Map<String, dynamic>.from(resData));
        }
      }
      if (e.response?.statusCode == 404) {
        return const CheckMobileResponseModel(
          success: true,
          exists: false,
          role: null,
          status: null,
        );
      }
      // Never block legitimate offline demo or temporary 5xx server glitches
      return const CheckMobileResponseModel(success: true, exists: true, status: 'ACTIVE');
    } catch (_) {
      return const CheckMobileResponseModel(success: true, exists: true, status: 'ACTIVE');
    }
  }

  @override
  Future<SendOtpResponseModel> sendOtp(String phone, {String? name, String? email}) async {
    final cleanPhone = sanitizePhone(phone);

    final response = await _apiClient.post(
      ApiEndpoints.sendOtp,
      data: {
        'mobile': cleanPhone,
        'phone': cleanPhone,
        'purpose': 'LOGIN',
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return SendOtpResponseModel.fromJson(data);
    } else if (data is Map) {
      return SendOtpResponseModel.fromJson(Map<String, dynamic>.from(data));
    }

    return const SendOtpResponseModel(
      success: true,
      message: 'OTP sent successfully',
      expiresIn: 300,
    );
  }

  @override
  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
    String? challengeId,
  }) async {
    final cleanPhone = sanitizePhone(phone);

    try {
      final response = await _apiClient.post(
        ApiEndpoints.verifyOtp,
        data: {
          'mobile': cleanPhone,
          'phone': cleanPhone,
          'otp': otp.trim(),
          'purpose': 'LOGIN',
          'role': role,
          if (challengeId != null && challengeId.isNotEmpty) 'challengeId': challengeId,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AuthResponseModel.fromJson(data);
      } else if (data is Map) {
        return AuthResponseModel.fromJson(Map<String, dynamic>.from(data));
      }

      throw Exception('Invalid verify OTP response from server');
    } on DioException catch (e) {
      _handleAuthDioError(e, fallback: 'Verification failed');
    }
  }

  Never _handleAuthDioError(DioException e, {String fallback = 'Authentication failed'}) {
    final resData = e.response?.data;
    if (resData is Map) {
      final err = resData['error'] is Map ? resData['error'] as Map : resData;
      final code = err['code']?.toString() ?? '';
      final msg = err['message']?.toString() ?? fallback;
      if (code == 'USER_SUSPENDED' || (e.response?.statusCode == 403 && msg.toLowerCase().contains('suspend'))) {
        throw UserSuspendedException(msg);
      }
      throw Exception(msg);
    }
    throw e;
  }

  @override
  Future<AuthResponseModel> signInWithGoogle({
    required String idToken,
    required String role,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.googleAuth,
        data: {
          'idToken': idToken,
          'role': role.toUpperCase(),
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AuthResponseModel.fromJson(data);
      } else if (data is Map) {
        return AuthResponseModel.fromJson(Map<String, dynamic>.from(data));
      }

      throw Exception('Invalid Google authentication response from server');
    } on DioException catch (e) {
      _handleAuthDioError(e, fallback: 'Google authentication failed');
    }
  }

  @override
  Future<SendOtpResponseModel> sendEmailOtp(String email) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.sendEmailOtp,
        data: {
          'email': email.trim(),
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SendOtpResponseModel.fromJson(data);
      } else if (data is Map) {
        return SendOtpResponseModel.fromJson(Map<String, dynamic>.from(data));
      }

      return const SendOtpResponseModel(
        success: true,
        message: 'Verification OTP sent to your email',
        expiresIn: 300,
      );
    } on DioException catch (e) {
      _handleAuthDioError(e, fallback: 'Failed to send email OTP');
    }
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
    try {
      final cleanPhone = phone != null ? sanitizePhone(phone) : '';
      final response = await _apiClient.post(
        ApiEndpoints.registerWithEmail,
        data: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          'otp': otp.trim(),
          'role': role.toUpperCase(),
          if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
          if (cleanPhone.isNotEmpty) 'mobile': cleanPhone,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AuthResponseModel.fromJson(data);
      } else if (data is Map) {
        return AuthResponseModel.fromJson(Map<String, dynamic>.from(data));
      }

      throw Exception('Invalid email registration response from server');
    } on DioException catch (e) {
      _handleAuthDioError(e, fallback: 'Email registration failed');
    }
  }

  @override
  Future<AuthResponseModel> loginWithEmail({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.loginWithEmail,
        data: {
          'email': email.trim(),
          'password': password,
          'role': role.toUpperCase(),
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AuthResponseModel.fromJson(data);
      } else if (data is Map) {
        return AuthResponseModel.fromJson(Map<String, dynamic>.from(data));
      }

      throw Exception('Invalid email login response from server');
    } on DioException catch (e) {
      _handleAuthDioError(e, fallback: 'Email login failed');
    }
  }

  @override
  Future<Map<String, String>> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final tokenData = (data['data']['tokens'] is Map)
            ? data['data']['tokens'] as Map
            : data['data'] as Map;
        return {
          'accessToken': tokenData['accessToken']?.toString() ?? '',
          'refreshToken': tokenData['refreshToken']?.toString() ?? '',
        };
      }

      return {};
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map) {
        final err = resData['error'] is Map ? resData['error'] as Map : resData;
        final code = err['code']?.toString() ?? '';
        final msg = err['message']?.toString() ?? 'Session expired';
        if (code == 'USER_SUSPENDED' || (e.response?.statusCode == 403 && msg.toLowerCase().contains('suspend'))) {
          throw UserSuspendedException(msg);
        }
      }
      rethrow;
    }
  }

  @override
  Future<bool> logout({String? deviceId, String? fcmToken}) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.logout,
        data: {},
      );
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (_) {
      return true; // Still allow local logout if server call fails
    }
  }

  @override
  Future<UserEntity> getMe() async {
    final response = await _apiClient.get(ApiEndpoints.userMe);
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      final userMap = data['data']['user'] as Map<String, dynamic>? ?? data['data'] as Map<String, dynamic>;
      final roleStr = userMap['role']?.toString() ?? 'customer';
      final statusStr = userMap['status']?.toString() ?? 'ACTIVE';
      final lastLogoutStr = userMap['lastLogoutAt']?.toString();
      final lastLogout = lastLogoutStr != null ? DateTime.tryParse(lastLogoutStr) : null;
      return UserEntity(
        id: userMap['_id'] ?? userMap['id'] ?? '',
        name: userMap['name']?.toString() ?? 'Customer',
        phone: userMap['mobile']?.toString() ?? userMap['phone']?.toString() ?? '',
        email: userMap['email']?.toString(),
        role: UserRole.fromString(roleStr),
        isApproved: userMap['isVerified'] ?? userMap['isActive'] ?? true,
        status: statusStr,
        lastLogoutAt: lastLogout,
      );
    }
    throw Exception('Invalid /users/me response');
  }

  @override
  Future<UserEntity> updateProfile({
    required String name,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    final cleanPhone = phone != null ? sanitizePhone(phone) : null;
    final formattedPhone = (cleanPhone != null && cleanPhone.isNotEmpty)
        ? (cleanPhone.startsWith('+') ? cleanPhone : '+91$cleanPhone')
        : null;

    final response = await _apiClient.put(
      ApiEndpoints.userMe,
      data: {
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (formattedPhone != null && formattedPhone.isNotEmpty) 'phone': formattedPhone,
        if (formattedPhone != null && formattedPhone.isNotEmpty) 'mobile': formattedPhone,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      },
    );
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      final userMap = data['data']['user'] as Map<String, dynamic>? ?? data['data'] as Map<String, dynamic>;
      final roleStr = userMap['role']?.toString() ?? 'customer';
      return UserEntity(
        id: userMap['_id'] ?? userMap['id'] ?? '',
        name: userMap['name']?.toString() ?? name,
        phone: userMap['mobile']?.toString() ?? userMap['phone']?.toString() ?? formattedPhone ?? '',
        email: userMap['email']?.toString() ?? email,
        role: UserRole.fromString(roleStr),
        isApproved: userMap['isVerified'] ?? userMap['isActive'] ?? true,
      );
    }
    return UserEntity(
      id: '',
      name: name,
      phone: formattedPhone ?? '',
      email: email,
      role: UserRole.customer,
    );
  }
}
