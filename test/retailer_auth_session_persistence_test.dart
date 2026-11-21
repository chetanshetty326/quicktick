import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quicklink/core/security/secure_storage_service.dart';
import 'package:quicklink/core/di/service_locator.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_event.dart';
import 'package:quicklink/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:quicklink/features/retailer/presentation/bloc/retailer_bloc.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_splash_screen.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_auth_screen.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_main_screen.dart';
import 'package:quicklink/features/retailer/domain/repositories/retailer_repository.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_entities.dart';
import 'package:quicklink/features/retailer/domain/entities/retailer_registration_status_entity.dart';
import 'package:dartz/dartz.dart';
import 'package:quicklink/core/errors/failures.dart';
import 'package:quicklink/features/order/domain/repositories/order_repository.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';
import 'package:quicklink/features/customer/domain/repositories/catalog_repository.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

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
  }) async => _map[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _map.remove(key);

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _map.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOrderRepo implements IOrderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  Future<Either<Failure, List<OrderEntity>>> getRetailerOrders(String storeId) async => const Right([]);
}

class _FakeCatalogRepo implements ICatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();

  @override
  Stream<List<StoreEntity>> get storesStream => const Stream.empty();

  @override
  Future<Either<Failure, List<ProductEntity>>> getStoreProducts(String storeId) async => const Right([]);

  @override
  Future<Either<Failure, List<StoreEntity>>> getNearbyStores({double? lat, double? lng}) async => const Right([]);
}

class FakeRetailerRepo implements IRetailerRepository {
  @override
  Future<Either<Failure, RetailerCheckRegisteredEntity>> checkRetailerRegistration() async {
    return const Right(RetailerCheckRegisteredEntity(
      registered: true,
      status: 'APPROVED',
      shopName: 'Green Grocers Mart',
    ));
  }

  @override
  Future<Either<Failure, RetailerStoreProfileEntity>> getStoreProfile() async {
    return const Right(RetailerStoreProfileEntity(
      id: 'store_101',
      storeName: 'Green Grocers Mart',
      ownerName: 'Ramesh Patel',
      email: 'ramesh@greengrocers.com',
      phone: '9876543210',
      fssaiNumber: '11223344556677',
      gstin: '29ABCDE1234F1Z5',
      address: 'Shop #12, MG Road, Bengaluru',
      isOpen: true,
      isVerified: true,
      status: 'APPROVED',
    ));
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getLiveOrders() async => const Right([]);

  @override
  Future<Either<Failure, List<ProductEntity>>> getInventory() async => const Right([]);

  @override
  Stream<List<RetailerStoreProfileEntity>> get storesStream => const Stream.empty();

  @override
  Stream<List<OrderEntity>> get ordersStream => const Stream.empty();

  @override
  Stream<List<ProductEntity>> get productsStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeStorage;
  late SharedPreferences prefs;
  late SecureStorageService secureStorageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeStorage = FakeSecureStorage();
    secureStorageService = SecureStorageService(
      storage: fakeStorage,
      prefs: prefs,
    );

    if (sl.isRegistered<ISecureStorageService>()) {
      sl.unregister<ISecureStorageService>();
    }
    sl.registerSingleton<ISecureStorageService>(secureStorageService);
  });

  tearDown(() {
    if (sl.isRegistered<ISecureStorageService>()) {
      sl.unregister<ISecureStorageService>();
    }
    if (sl.isRegistered<AuthBloc>()) {
      sl.unregister<AuthBloc>();
    }
    if (sl.isRegistered<RetailerBloc>()) {
      sl.unregister<RetailerBloc>();
    }
  });

  group('Retailer App - Persistent Login & Session Tests', () {
    test('1. Once logged in, tokens and user role are preserved and isSessionValid returns true', () async {
      await secureStorageService.saveTokens(
        accessToken: 'valid_jwt_access_token_retailer_123',
        refreshToken: 'valid_refresh_token_retailer_456',
        expiryDuration: const Duration(days: 30),
      );

      await secureStorageService.saveUserData(
        userId: 'retailer_user_789',
        role: 'retailer',
        name: 'Ramesh Store',
        phone: '9876543210',
        expiryDuration: const Duration(days: 30),
      );

      final isValid = await secureStorageService.isSessionValid();
      expect(isValid, isTrue);

      final token = await secureStorageService.getAccessToken();
      expect(token, equals('valid_jwt_access_token_retailer_123'));

      final userData = await secureStorageService.getUserData();
      expect(userData['role'], equals('retailer'));
      expect(userData['name'], equals('Ramesh Store'));
    });

    test('2. Logout clears all session tokens and makes isSessionValid return false', () async {
      // First save login session
      await secureStorageService.saveTokens(
        accessToken: 'temp_token',
        refreshToken: 'temp_refresh',
      );
      await secureStorageService.saveUserData(
        userId: 'temp_id',
        role: 'retailer',
        name: 'Temp Store',
        phone: '9876543210',
      );

      expect(await secureStorageService.isSessionValid(), isTrue);

      // Perform logout
      await secureStorageService.clearAuthData();

      // Now session is invalid and tokens are null
      expect(await secureStorageService.isSessionValid(), isFalse);
      expect(await secureStorageService.getAccessToken(), isNull);
      final userData = await secureStorageService.getUserData();
      expect(userData['userId'], isNull);
      expect(userData['role'], isNull);
    });

    testWidgets('3. On reopen, RetailerSplashScreen detects existing session and navigates to RetailerMainScreen without asking for login', (tester) async {
      // Pre-populate active logged-in retailer session
      await secureStorageService.saveTokens(
        accessToken: 'active_token_999',
        refreshToken: 'active_refresh_999',
        expiryDuration: const Duration(days: 14),
      );
      await secureStorageService.saveUserData(
        userId: 'user_merchant_1',
        role: 'retailer',
        name: 'Green Grocers Mart',
        phone: '9876543210',
        expiryDuration: const Duration(days: 14),
      );

      final authBloc = AuthBloc(secureStorageService);
      authBloc.add(CheckAuthSessionEvent());

      final retailerBloc = RetailerBloc(
        orderRepo: _FakeOrderRepo(),
        catalogRepo: _FakeCatalogRepo(),
        enablePeriodicPolling: false,
      );

      if (sl.isRegistered<AuthBloc>()) sl.unregister<AuthBloc>();
      sl.registerSingleton<AuthBloc>(authBloc);

      if (sl.isRegistered<RetailerBloc>()) sl.unregister<RetailerBloc>();
      sl.registerSingleton<RetailerBloc>(retailerBloc);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<RetailerBloc>.value(value: retailerBloc),
          ],
          child: const MaterialApp(
            home: RetailerSplashScreen(),
          ),
        ),
      );

      // Verify splash screen displays initially
      expect(find.byType(RetailerSplashScreen), findsOneWidget);

      // Advance time through animation and session check
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Verify it navigated straight to RetailerMainScreen, NEVER to RetailerAuthScreen
      expect(find.byType(RetailerAuthScreen), findsNothing);
      expect(find.byType(RetailerMainScreen), findsOneWidget);
      expect(find.text('Live Orders'), findsOneWidget);
    });

    testWidgets('4. If logged out, RetailerSplashScreen routes to RetailerAuthScreen and prompts for login', (tester) async {
      // Ensure empty/cleared storage (user logged out)
      await secureStorageService.clearAuthData();

      final authBloc = AuthBloc(secureStorageService);
      authBloc.add(CheckAuthSessionEvent());

      final retailerBloc = RetailerBloc(
        orderRepo: _FakeOrderRepo(),
        catalogRepo: _FakeCatalogRepo(),
        enablePeriodicPolling: false,
      );

      if (sl.isRegistered<AuthBloc>()) sl.unregister<AuthBloc>();
      sl.registerSingleton<AuthBloc>(authBloc);

      if (sl.isRegistered<RetailerBloc>()) sl.unregister<RetailerBloc>();
      sl.registerSingleton<RetailerBloc>(retailerBloc);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<RetailerBloc>.value(value: retailerBloc),
          ],
          child: const MaterialApp(
            home: RetailerSplashScreen(),
          ),
        ),
      );

      expect(find.byType(RetailerSplashScreen), findsOneWidget);

      // Advance time through splash
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Since logged out, it properly asks for login/OTP
      expect(find.byType(RetailerAuthScreen), findsOneWidget);
      expect(find.byType(RetailerMainScreen), findsNothing);
      expect(find.text('Send Verification OTP'), findsOneWidget);
    });

    testWidgets('5. RetailerAuthScreen auto-bypasses if session is active and forwards to dashboard', (tester) async {
      // Setup active retailer session
      await secureStorageService.saveTokens(
        accessToken: 'active_token_555',
        refreshToken: 'active_refresh_555',
      );
      await secureStorageService.saveUserData(
        userId: 'merchant_555',
        role: 'retailer',
        name: 'Auto-Forward Mart',
        phone: '9876543210',
      );

      final authBloc = AuthBloc(secureStorageService);
      authBloc.emit(const AuthenticatedState(UserEntity(
        id: 'merchant_555',
        name: 'Auto-Forward Mart',
        phone: '9876543210',
        role: UserRole.retailer,
      )));

      final retailerBloc = RetailerBloc(
        orderRepo: _FakeOrderRepo(),
        catalogRepo: _FakeCatalogRepo(),
        enablePeriodicPolling: false,
      );

      if (sl.isRegistered<AuthBloc>()) sl.unregister<AuthBloc>();
      sl.registerSingleton<AuthBloc>(authBloc);

      if (sl.isRegistered<RetailerBloc>()) sl.unregister<RetailerBloc>();
      sl.registerSingleton<RetailerBloc>(retailerBloc);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<RetailerBloc>.value(value: retailerBloc),
          ],
          child: const MaterialApp(
            home: RetailerAuthScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // RetailerAuthScreen automatically forwards to RetailerMainScreen without asking to login again
      expect(find.byType(RetailerMainScreen), findsOneWidget);
      expect(find.text('Get OTP Code'), findsNothing);
    });
  });
}
