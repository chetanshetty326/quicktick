import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/services/error_reporting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase Crashlytics & ErrorReportingService Integration Tests', () {
    test('ErrorReportingService initializes safely without throwing', () async {
      final service = ErrorReportingService.instance;
      await service.initialize();
      expect(service, isNotNull);
    });

    test('captureException handles manual exceptions without crashing', () {
      final service = ErrorReportingService.instance;
      expect(
        () => service.captureException(
          Exception('Simulated non-fatal test error'),
          stackTrace: StackTrace.current,
          hint: 'unit-test-hint',
        ),
        returnsNormally,
      );
    });

    test('setUserContext and logBreadcrumb execute safely without crashing', () async {
      final service = ErrorReportingService.instance;
      await service.setUserContext(
        userId: 'usr_customer_123',
        role: 'customer',
        phone: '+919876543210',
      );
      expect(() => service.logBreadcrumb('Navigated to Cart Screen'), returnsNormally);
    });

    testWidgets('AppErrorBoundary renders child widget properly in test/debug mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppErrorBoundary(
            child: Scaffold(
              body: Text('Protected App Content'),
            ),
          ),
        ),
      );

      expect(find.text('Protected App Content'), findsOneWidget);
    });
  });
}
