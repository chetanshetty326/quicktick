import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/core/storage/local_cache_service.dart';
import 'package:quicklink/core/network/api_client.dart';
import 'package:quicklink/core/network/api_endpoints.dart';
import 'package:quicklink/features/retailer/data/datasources/retailer_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:hive/hive.dart';

class Mock401Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"success": false, "message": "Unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeBox<E> implements Box<E> {
  final Map<dynamic, E> _storage = {};

  @override
  Future<void> put(dynamic key, E value) async {
    _storage[key] = value;
  }

  @override
  E? get(dynamic key, {E? defaultValue}) {
    return _storage[key] ?? defaultValue;
  }

  @override
  Future<void> delete(dynamic key) async {
    _storage.remove(key);
  }

  @override
  Future<int> clear() async {
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _map = {};

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
      _map[key] = value;
    } else {
      _map.remove(key);
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
  }) async {
    return _map[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _map.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _map.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Retailer Security Hardening Tests (Clean Architecture & Data Protection)', () {
    late FakeSecureStorage fakeStorage;
    late SharedPreferences prefs;
    late SecureStorageService secureStorageService;
    late FakeBox<String> fakeOrdersBox;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeStorage = FakeSecureStorage();
      fakeOrdersBox = FakeBox<String>();
      secureStorageService = SecureStorageService(
        storage: fakeStorage,
        prefs: prefs,
      );
    });

    test('SECURITY-01: saveUserData stores PII exclusively in SecureStorage and NOT in SharedPreferences', () async {
      await secureStorageService.saveUserData(
        userId: 'ret_secure_999',
        role: 'retailer',
        name: 'Suresh Store Owner',
        phone: '9876543210',
        email: 'suresh@store.com',
      );

      // Verify data is safely in FlutterSecureStorage
      expect(await fakeStorage.read(key: 'sec_user_id'), 'ret_secure_999');
      expect(await fakeStorage.read(key: 'sec_user_role'), 'retailer');
      expect(await fakeStorage.read(key: 'sec_user_name'), 'Suresh Store Owner');
      expect(await fakeStorage.read(key: 'sec_user_phone'), '9876543210');
      expect(await fakeStorage.read(key: 'sec_user_email'), 'suresh@store.com');

      // Verify unencrypted SharedPreferences XML contains NO plaintext PII
      expect(prefs.getString('sec_user_id'), isNull);
      expect(prefs.getString('sec_user_role'), isNull);
      expect(prefs.getString('sec_user_name'), isNull);
      expect(prefs.getString('sec_user_phone'), isNull);
      expect(prefs.getString('sec_user_email'), isNull);
    });

    test('SECURITY-02: saveUserData and getUserData actively purge legacy plaintext PII from SharedPreferences', () async {
      // Simulate legacy install with leaked plaintext PII in SharedPreferences
      await prefs.setString('sec_user_id', 'legacy_ret_123');
      await prefs.setString('sec_user_phone', '9111122222');
      await prefs.setString('sec_user_name', 'Old Retailer');

      // getUserData should read, migrate to SecureStorage, and delete from SharedPreferences
      final userData = await secureStorageService.getUserData();
      expect(userData['userId'], 'legacy_ret_123');
      expect(userData['phone'], '9111122222');

      // Verify SharedPreferences has been purged
      expect(prefs.getString('sec_user_id'), isNull);
      expect(prefs.getString('sec_user_phone'), isNull);
      expect(prefs.getString('sec_user_name'), isNull);
    });

    test('SECURITY-03: LocalCacheService does NOT serialize full orders to unencrypted SharedPreferences', () async {
      final cacheService = LocalCacheService(prefs, ordersBox: fakeOrdersBox);

      final mockOrders = [
        {
          'id': 'ord_12345',
          'customerName': 'Aarav Sharma',
          'customerPhone': '+919876543210',
          'deliveryAddress': 'Flat 402, Sunshine Apartments, Indiranagar',
          'deliveryOtp': '884219', // Sensitive Customer OTP
          'grandTotal': 450.0,
        }
      ];

      await cacheService.cacheActiveOrders(mockOrders);

      // Verify unencrypted SharedPreferences does NOT have the orders
      expect(prefs.getString('pref_shared_orders_sync'), isNull);
    });

    test('SECURITY-04: LocalCacheService strips sensitive deliveryOtp before caching to disk', () async {
      final cacheService = LocalCacheService(prefs, ordersBox: fakeOrdersBox);

      final mockOrders = [
        {
          'id': 'ord_12345',
          'customerName': 'Aarav Sharma',
          'deliveryOtp': '884219', // Sensitive Customer OTP
        }
      ];

      // Sanitization step should scrub deliveryOtp
      await cacheService.cacheActiveOrders(mockOrders);

      // Verify cached orders in Hive do not contain deliveryOtp
      final cached = cacheService.getCachedActiveOrders();
      expect(cached.isNotEmpty, isTrue);
      expect(cached.first['deliveryOtp'], equals(''));
    });

    test('SECURITY-05: ApiClient token refresh fails cleanly without hardcoded 123456 fallback and clears auth data', () async {
      // Setup SecureStorage with an expired refresh token
      await fakeStorage.write(key: 'sec_access_token', value: 'expired_access_token');
      await fakeStorage.write(key: 'sec_refresh_token', value: 'invalid_refresh_token');

      // Mock Dio that returns 401 Unauthorized via HttpClientAdapter
      final testDio = Dio();
      testDio.httpClientAdapter = Mock401Adapter();

      final apiClient = ApiClient(
        secureStorage: secureStorageService,
        dio: testDio,
      );

      // Making a protected request that fails with 401 should trigger reauth,
      // which will fail cleanly and clear auth data without attempting silent 123456 OTP verify
      try {
        await apiClient.get('/retailer/orders');
      } catch (_) {}

      // Verify auth data was cleared to prevent zombie sessions
      expect(await fakeStorage.read(key: 'sec_access_token'), isNull);
      expect(await fakeStorage.read(key: 'sec_refresh_token'), isNull);
    });
  });
}
