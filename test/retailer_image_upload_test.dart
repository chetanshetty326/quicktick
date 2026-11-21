import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/features/retailer/presentation/widgets/retailer_product_image_picker.dart';

void main() {
  group('Retailer Product Image Upload UI Widget Tests', () {
    testWidgets('Displays upload placeholder when no image is selected', (tester) async {
      String selectedImage = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: RetailerProductImagePicker(
                initialImageUrl: null,
                onImageChanged: (url) => selectedImage = url,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Product / Dish Image'), findsOneWidget);
      expect(find.text('Upload Product Image'), findsOneWidget);
      expect(find.text('Camera • Gallery • Web URL'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });

    testWidgets('Tapping upload opens modal sheet with Camera, Gallery, and Web URL options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: RetailerProductImagePicker(
                initialImageUrl: null,
                onImageChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap on the upload container
      await tester.tap(find.text('Upload Product Image'));
      await tester.pumpAndSettle();

      expect(find.text('Select Image Source'), findsOneWidget);
      expect(find.text('Take Photo with Camera'), findsOneWidget);
      expect(find.text('Upload from Gallery'), findsOneWidget);
      expect(find.text('Enter Web Image URL'), findsOneWidget);
    });

    testWidgets('Displays active image preview card when initialImageUrl is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: RetailerProductImagePicker(
                initialImageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
                onImageChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Change Image'), findsOneWidget);
      expect(find.text('Live Image Link Attached'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
