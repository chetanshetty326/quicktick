import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ISecureStorageService {
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Duration expiryDuration = const Duration(days: 7),
  });
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<DateTime?> getSessionExpiry();
  Future<bool> isSessionValid();
  Future<Duration?> getSessionRemainingTime();
  Future<void> saveUserRole(String role);
  Future<String?> getUserRole();
  Future<void> saveUserId(String userId);
  Future<String?> getUserId();
  Future<void> saveUserData({
    required String userId,
    required String role,
    required String name,
    required String phone,
    String? email,
    Duration expiryDuration = const Duration(days: 7),
  });
  Future<Map<String, String?>> getUserData();
  Future<void> clearAuthData();
  Future<void> saveRiderKycData(String kycJson, {String? phoneSuffix});
  Future<String?> getRiderKycData({String? phoneSuffix});
  Future<void> clearRiderKycData({String? phoneSuffix});
}

class SecureStorageService implements ISecureStorageService {
  final FlutterSecureStorage _storage;
  final SharedPreferences? _prefs;

  SecureStorageService({
    FlutterSecureStorage? storage,
    SharedPreferences? prefs,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true, // Auto-recover from Keystore corruption
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            ),
        _prefs = prefs;

  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs != null) return _prefs;
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static const String _keyAccessToken = 'sec_access_token';
  static const String _keyRefreshToken = 'sec_refresh_token';
  static const String _keySessionExpiry = 'sec_session_expiry_timestamp';
  static const String _keyUserRole = 'sec_user_role';
  static const String _keyUserId = 'sec_user_id';
  static const String _keyUserName = 'sec_user_name';
  static const String _keyUserPhone = 'sec_user_phone';
  static const String _keyUserEmail = 'sec_user_email';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    final expiryTime = DateTime.now().add(expiryDuration).toIso8601String();
    try {
      await _storage.write(key: _keyAccessToken, value: accessToken);
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
      await _storage.write(key: _keySessionExpiry, value: expiryTime);
    } catch (e) {
      debugPrint('⚠️ SecureStorage write tokens notice: $e');
    }

    // Security Fix: Plaintext tokens must NEVER be mirrored to unencrypted SharedPreferences.
    // Sanitize any legacy plaintext tokens from SharedPreferences.
    try {
      final p = await _getPrefs();
      if (p != null) {
        await p.remove(_keyAccessToken);
        await p.remove(_keyRefreshToken);
      }
    } catch (_) {}
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      final valid = await isSessionValid().timeout(const Duration(seconds: 2), onTimeout: () => false);
      if (!valid) return null;

      final token = await _storage.read(key: _keyAccessToken).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('⚠️ SecureStorage getAccessToken notice: $e');
    }
    return null;
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _keyRefreshToken).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('⚠️ SecureStorage getRefreshToken notice: $e');
    }
    return null;
  }

  @override
  Future<DateTime?> getSessionExpiry() async {
    try {
      final expiryStr = await _storage.read(key: _keySessionExpiry).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (expiryStr != null) {
        final parsed = DateTime.tryParse(expiryStr);
        if (parsed != null) return parsed;
      }
    } catch (_) {}

    try {
      final p = await _getPrefs();
      final expiryStr = p?.getString(_keySessionExpiry);
      if (expiryStr != null) return DateTime.tryParse(expiryStr);
    } catch (_) {}

    return null;
  }

  @override
  Future<bool> isSessionValid() async {
    String? token;
    try {
      token = await _storage.read(key: _keyAccessToken).timeout(const Duration(seconds: 2), onTimeout: () => null);
    } catch (_) {}

    if (token == null || token.isEmpty) {
      try {
        final p = await _getPrefs();
        token = p?.getString(_keyAccessToken);
      } catch (_) {}
    }

    if (token == null || token.isEmpty) return false;

    final expiry = await getSessionExpiry().timeout(const Duration(seconds: 2), onTimeout: () => null);
    if (expiry == null) {
      // If token exists but expiry timestamp was temporarily unreadable, grant valid session
      return true;
    }

    // Check if current time is before the expiry timestamp
    return DateTime.now().isBefore(expiry);
  }

  @override
  Future<Duration?> getSessionRemainingTime() async {
    final expiry = await getSessionExpiry();
    if (expiry == null) return null;
    final diff = expiry.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Future<void> saveUserRole(String role) async {
    try {
      await _storage.write(key: _keyUserRole, value: role);
    } catch (_) {}
    // Sanitize any legacy plaintext role from SharedPreferences
    try {
      final p = await _getPrefs();
      await p?.remove(_keyUserRole);
    } catch (_) {}
  }

  @override
  Future<String?> getUserRole() async {
    try {
      final role = await _storage.read(key: _keyUserRole);
      if (role != null && role.isNotEmpty) return role;
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveUserId(String userId) async {
    try {
      await _storage.write(key: _keyUserId, value: userId);
    } catch (_) {}
    // Sanitize any legacy plaintext userId from SharedPreferences
    try {
      final p = await _getPrefs();
      await p?.remove(_keyUserId);
    } catch (_) {}
  }

  @override
  Future<String?> getUserId() async {
    try {
      final id = await _storage.read(key: _keyUserId);
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}
    return null;
  }

  @override
  Future<void> saveUserData({
    required String userId,
    required String role,
    required String name,
    required String phone,
    String? email,
    Duration expiryDuration = const Duration(days: 7),
  }) async {
    final expiryTime = DateTime.now().add(expiryDuration).toIso8601String();
    try {
      await _storage.write(key: _keyUserId, value: userId);
      await _storage.write(key: _keyUserRole, value: role);
      await _storage.write(key: _keyUserName, value: name);
      await _storage.write(key: _keyUserPhone, value: phone);
      if (email != null && email.isNotEmpty) {
        await _storage.write(key: _keyUserEmail, value: email);
      }
      await _storage.write(key: _keySessionExpiry, value: expiryTime);
    } catch (e) {
      debugPrint('⚠️ SecureStorage saveUserData notice: $e');
    }

    // Security Hardening: Personal Identifiable Information (PII) must NEVER be written to unencrypted SharedPreferences.
    // Proactively clean up any legacy plaintext keys from SharedPreferences.
    try {
      final p = await _getPrefs();
      if (p != null) {
        await p.remove(_keyUserId);
        await p.remove(_keyUserRole);
        await p.remove(_keyUserName);
        await p.remove(_keyUserPhone);
        await p.remove(_keyUserEmail);
        await p.remove(_keySessionExpiry);
      }
    } catch (_) {}
  }

  @override
  Future<Map<String, String?>> getUserData() async {
    String? userId;
    String? role;
    String? name;
    String? phone;
    String? email;
    String? expiry;

    try {
      userId = await _storage.read(key: _keyUserId);
      role = await _storage.read(key: _keyUserRole);
      name = await _storage.read(key: _keyUserName);
      phone = await _storage.read(key: _keyUserPhone);
      email = await _storage.read(key: _keyUserEmail);
      expiry = await _storage.read(key: _keySessionExpiry);
    } catch (e) {
      debugPrint('⚠️ SecureStorage getUserData notice: $e');
    }

    // Security Hardening: If legacy plaintext entries exist, migrate to secure storage and purge plaintext copy
    try {
      final p = await _getPrefs();
      if (p != null) {
        if (userId == null && p.containsKey(_keyUserId)) {
          userId = p.getString(_keyUserId);
          if (userId != null) await _storage.write(key: _keyUserId, value: userId);
        }
        if (role == null && p.containsKey(_keyUserRole)) {
          role = p.getString(_keyUserRole);
          if (role != null) await _storage.write(key: _keyUserRole, value: role);
        }
        if (name == null && p.containsKey(_keyUserName)) {
          name = p.getString(_keyUserName);
          if (name != null) await _storage.write(key: _keyUserName, value: name);
        }
        if (phone == null && p.containsKey(_keyUserPhone)) {
          phone = p.getString(_keyUserPhone);
          if (phone != null) await _storage.write(key: _keyUserPhone, value: phone);
        }
        if (email == null && p.containsKey(_keyUserEmail)) {
          email = p.getString(_keyUserEmail);
          if (email != null) await _storage.write(key: _keyUserEmail, value: email);
        }
        await p.remove(_keyUserId);
        await p.remove(_keyUserRole);
        await p.remove(_keyUserName);
        await p.remove(_keyUserPhone);
        await p.remove(_keyUserEmail);
        await p.remove(_keySessionExpiry);
      }
    } catch (_) {}

    return {
      'userId': userId,
      'role': role,
      'name': name,
      'phone': phone,
      'email': email,
      'expiry': expiry,
    };
  }

  static const String _keyRiderKycData = 'sec_rider_kyc_data';
  static const String _legacyKeyRiderKyc = 'delivery_partner_kyc_data';

  @override
  Future<void> saveRiderKycData(String kycJson, {String? phoneSuffix}) async {
    final key = (phoneSuffix != null && phoneSuffix.isNotEmpty)
        ? '${_keyRiderKycData}_$phoneSuffix'
        : _keyRiderKycData;
    await _storage.write(key: key, value: kycJson);

    // Actively purge legacy plaintext SharedPreferences records
    try {
      final p = await _getPrefs();
      if (p != null) {
        final legacyKey = (phoneSuffix != null && phoneSuffix.isNotEmpty)
            ? '${_legacyKeyRiderKyc}_$phoneSuffix'
            : _legacyKeyRiderKyc;
        await p.remove(legacyKey);
        await p.remove(_legacyKeyRiderKyc);
      }
    } catch (_) {}
  }

  @override
  Future<String?> getRiderKycData({String? phoneSuffix}) async {
    final key = (phoneSuffix != null && phoneSuffix.isNotEmpty)
        ? '${_keyRiderKycData}_$phoneSuffix'
        : _keyRiderKycData;
    String? data = await _storage.read(key: key);
    if (data == null && phoneSuffix != null && phoneSuffix.isNotEmpty) {
      data = await _storage.read(key: _keyRiderKycData);
    }

    // Auto-migrate from legacy plaintext SharedPreferences if found
    if (data == null) {
      try {
        final p = await _getPrefs();
        if (p != null) {
          final legacyKey = (phoneSuffix != null && phoneSuffix.isNotEmpty)
              ? '${_legacyKeyRiderKyc}_$phoneSuffix'
              : _legacyKeyRiderKyc;
          data = p.getString(legacyKey) ?? p.getString(_legacyKeyRiderKyc);
          if (data != null && data.isNotEmpty) {
            await saveRiderKycData(data, phoneSuffix: phoneSuffix);
            await p.remove(legacyKey);
            await p.remove(_legacyKeyRiderKyc);
          }
        }
      } catch (_) {}
    }
    return data;
  }

  @override
  Future<void> clearRiderKycData({String? phoneSuffix}) async {
    final key = (phoneSuffix != null && phoneSuffix.isNotEmpty)
        ? '${_keyRiderKycData}_$phoneSuffix'
        : _keyRiderKycData;
    try {
      await _storage.delete(key: key);
      await _storage.delete(key: _keyRiderKycData);
    } catch (_) {}

    try {
      final p = await _getPrefs();
      if (p != null) {
        final legacyKey = (phoneSuffix != null && phoneSuffix.isNotEmpty)
            ? '${_legacyKeyRiderKyc}_$phoneSuffix'
            : _legacyKeyRiderKyc;
        await p.remove(legacyKey);
        await p.remove(_legacyKeyRiderKyc);
      }
    } catch (_) {}
  }

  @override
  Future<void> clearAuthData() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keySessionExpiry);
      await _storage.delete(key: _keyUserId);
      await _storage.delete(key: _keyUserRole);
      await _storage.delete(key: _keyUserName);
      await _storage.delete(key: _keyUserPhone);
      await _storage.delete(key: _keyUserEmail);
      await clearRiderKycData();
    } catch (_) {}

    try {
      final p = await _getPrefs();
      if (p != null) {
        await p.remove(_keyAccessToken);
        await p.remove(_keyRefreshToken);
        await p.remove(_keySessionExpiry);
        await p.remove(_keyUserId);
        await p.remove(_keyUserRole);
        await p.remove(_keyUserName);
        await p.remove(_keyUserPhone);
        await p.remove(_keyUserEmail);
        await p.remove(_legacyKeyRiderKyc);
      }
    } catch (_) {}
  }
}
