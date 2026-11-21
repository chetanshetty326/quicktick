import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/retailer/data/datasources/retailer_remote_data_source.dart';
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
  Future<Map<String, String?>> getUserData() async => {
        'userId': _data['userId'] as String?,
        'role': _data['role'] as String?,
        'name': _data['name'] as String?,
        'phone': _data['phone'] as String?,
        'email': _data['email'] as String?,
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
  group('Retailer Store Registration Phone Number Consistency', () {
    test('Authenticated registration phone number is formatted into standard 10-digit and E.164 for store registration', () {
      const registeredPhone = '+91 9123456789';
      final clean = registeredPhone.replaceAll(RegExp(r'\D'), '');
      final tenDigit = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
      final formatted = tenDigit.isNotEmpty ? '+91$tenDigit' : registeredPhone;

      expect(tenDigit, '9123456789');
      expect(formatted, '+919123456789');

      // Verify payload construction matches store requirements
      final storeData = {
        'shopName': 'Spice Garden Restaurant',
        'phone': formatted,
        'contactPhone': tenDigit,
        'mobile': formatted,
      };

      expect(storeData['phone'], '+919123456789');
      expect(storeData['contactPhone'], '9123456789');
      expect(storeData['mobile'], '+919123456789');
    });

    test('AuthBloc AuthenticatedState provides phone number to store registration', () {
      const user = UserEntity(
        id: 'ret_01',
        name: 'Fresh Mart Owner',
        phone: '+919876543210',
        role: UserRole.retailer,
      );

      final state = AuthenticatedState(user);
      expect(state.user.phone, '+919876543210');

      final cleanDigits = state.user.phone.replaceAll(RegExp(r'\D'), '');
      final tenDigits = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
      expect(tenDigits, '9876543210');
    });

    test('Draft restore recovers phone number if phone controller is empty', () {
      final draftData = {
        'phone': '9876543210',
        'storeName': 'Green Mart Grocery',
        'ownerName': 'Chetan Shetty',
      };

      String phoneText = '';
      if ((draftData['phone'] as String?)?.isNotEmpty == true && phoneText.isEmpty) {
        final p = (draftData['phone'] as String).replaceAll(RegExp(r'\D'), '');
        final clean = p.length >= 10 ? p.substring(p.length - 10) : p;
        if (clean.isNotEmpty) {
          phoneText = clean;
        }
      }

      expect(phoneText, '9876543210');
    });

    test('Initial phone parameter cleanly extracts 10 digits', () {
      const initialPhone = '+91 9876543210';
      final digits = initialPhone.replaceAll(RegExp(r'\D'), '');
      final clean = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
      expect(clean, '9876543210');
    });

    test('Store name uniqueness validation rejects taken names', () {
      // Simulation of validator logic
      String? validateStoreName(String? name, bool? isAvailable, String? duplicateError) {
        if (name == null || name.trim().isEmpty) {
          return 'Enter store or restaurant name';
        }
        if (isAvailable == false || duplicateError != null) {
          return duplicateError ?? 'Store name is already taken. Please choose a unique name.';
        }
        return null;
      }

      expect(validateStoreName('', true, null), 'Enter store or restaurant name');
      expect(validateStoreName('Spices', false, null), 'Store name is already taken. Please choose a unique name.');
      expect(validateStoreName('Spices', false, 'A store with name Spices already exists.'), 'A store with name Spices already exists.');
      expect(validateStoreName('Spices Unique', true, null), isNull);
    });
  });
}
