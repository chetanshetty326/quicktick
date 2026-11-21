import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: In integration tests, initialize service locator first.
    expect(LocalDailyEssentialsApp, isNotNull);
  });
}
