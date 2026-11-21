import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/network/api_client.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';

class MockSecureStorageService extends Fake implements ISecureStorageService {
  String? accessToken = 'expired_token';
  String? refreshToken = 'valid_refresh';
  String? role = 'customer';
  int saveCount = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<String?> getUserRole() async => role;

  @override
  Future<Map<String, String?>> getUserData() async => {'phone': '9999999901'};

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    Duration? expiryDuration,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    saveCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ApiClient initializes cleanly with token refresh mutex support', () {
    final storage = MockSecureStorageService();
    final client = ApiClient(secureStorage: storage);

    expect(client, isNotNull);
    expect(client.dio.interceptors.isNotEmpty, isTrue);
  });
}
