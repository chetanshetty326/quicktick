import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quicklink/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/auth/domain/entities/user_entity.dart';
import 'package:quicklink/features/customer/presentation/screens/customer_main_screen.dart';
import 'package:quicklink/core/services/network_connectivity_service.dart';
import 'package:quicklink/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthBloc extends Cubit<AuthState> implements AuthBloc {
  FakeAuthBloc(super.initialState);

  @override
  void add(AuthEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCustomerBloc extends Cubit<CustomerState> implements CustomerBloc {
  FakeCustomerBloc(super.initialState);

  @override
  void add(CustomerEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNetworkConnectivityService implements INetworkConnectivityService {
  @override
  Future<bool> checkConnection() async => true;

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);

  @override
  void dispose() {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    if (!sl.isRegistered<INetworkConnectivityService>()) {
      sl.registerSingleton<INetworkConnectivityService>(FakeNetworkConnectivityService());
    }
  });

  tearDown(() {
    if (sl.isRegistered<INetworkConnectivityService>()) {
      sl.unregister<INetworkConnectivityService>();
    }
  });

  testWidgets('Customer Profile section removes Security & Session Storage and Payment Modes, and adapts responsively', (tester) async {
    final user = const UserEntity(
      id: 'cust_101',
      name: 'John Doe',
      phone: '9876543210',
      role: UserRole.customer,
      email: 'john@example.com',
    );

    final fakeAuthBloc = FakeAuthBloc(AuthenticatedState(user));
    final fakeCustomerBloc = FakeCustomerBloc(const CustomerState());

    // Test on small screen (360x640)
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: fakeAuthBloc),
            BlocProvider<CustomerBloc>.value(value: fakeCustomerBloc),
          ],
          child: const CustomerMainScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Profile Tab (destination index 2)
    final profileTab = find.text('Profile');
    expect(profileTab, findsOneWidget);
    await tester.tap(profileTab);
    await tester.pumpAndSettle();

    // Verify User details exist
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Saved Delivery Addresses'), findsOneWidget);
    expect(find.text('Notification Center'), findsOneWidget);

    // Verify "Payment Modes" is REMOVED
    expect(find.text('Payment Modes'), findsNothing);

    // Verify "SECURITY & SESSION STORAGE" section is REMOVED
    expect(find.text('SECURITY & SESSION STORAGE'), findsNothing);
    expect(find.text('Session Token Expiry'), findsNothing);
    expect(find.text('Hardware Keystore Security'), findsNothing);
    expect(find.text('Device Privacy (FLAG_SECURE)'), findsNothing);

    // Verify Support & Legal exists
    expect(find.text('SUPPORT & LEGAL'), findsOneWidget);

    // Scroll to see Logout and Account Deletion
    await tester.scrollUntilVisible(find.text('Log Out of Account'), 200);
    expect(find.text('Log Out of Account'), findsOneWidget);
    expect(find.text('Delete Account & Data'), findsOneWidget);

    // Test on wide tablet / desktop screen (1024x768)
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();

    // Still renders cleanly with responsive max width constraints without error
    expect(find.text('Payment Modes'), findsNothing);
    expect(find.text('SECURITY & SESSION STORAGE'), findsNothing);
    expect(find.text('Log Out of Account'), findsOneWidget);

    // Scroll back to top to verify top header on tablet
    await tester.scrollUntilVisible(find.text('Saved Delivery Addresses'), -200);
    expect(find.text('Saved Delivery Addresses'), findsOneWidget);
    expect(find.text('SUPPORT & LEGAL'), findsOneWidget);
  });
}
