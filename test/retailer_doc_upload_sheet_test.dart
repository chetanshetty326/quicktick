import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/retailer/presentation/screens/retailer_registration_screen.dart';

void main() {
  testWidgets('Retailer doc upload and preview bottom sheets render responsively without overflow', (WidgetTester tester) async {
    // 1. Small compact screen width (320x640)
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RetailerRegistrationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap CONTINUE to move to Step 2 (Documents)
    final continueBtn = find.text('CONTINUE');
    expect(continueBtn, findsOneWidget);
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // Verify we are on Step 2
    expect(find.textContaining('FSSAI'), findsWidgets);

    // Find VIEW button (for pre-filled sample document)
    final viewBtn = find.text('VIEW').first;
    expect(viewBtn, findsOneWidget);

    // Scroll until viewBtn is visible
    await tester.ensureVisible(viewBtn);
    await tester.pumpAndSettle();

    // Tap VIEW to open preview modal
    await tester.tap(viewBtn);
    await tester.pumpAndSettle();

    // Verify preview modal renders with VERIFIED tag and Replace/Remove buttons
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tap Replace to open the doc upload bottom sheet
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    // Verify upload picker bottom sheet options
    expect(find.textContaining('Upload'), findsWidgets);
    expect(find.text('FAST & RECOMMENDED'), findsOneWidget);
    expect(find.text('Upload PDF from Device'), findsOneWidget);
    expect(find.text('Scan with Camera'), findsOneWidget);
    expect(find.text('Choose from Photo Gallery'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Dismiss bottom sheet via close button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 2. Tablet / Large screen width (800x1200)
    tester.view.physicalSize = const Size(800, 1200);
    await tester.pumpAndSettle();

    await tester.tap(viewBtn);
    await tester.pumpAndSettle();

    expect(find.text('VERIFIED'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(find.text('FAST & RECOMMENDED'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });
}
