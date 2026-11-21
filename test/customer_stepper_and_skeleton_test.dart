import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicklink/core/widgets/skeleton_loading.dart';
import 'package:quicklink/features/customer/domain/entities/catalog_entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Customer UI Stepper & Skeletons Tests', () {
    testWidgets('1. SkeletonProductCard and SkeletonStoreCard render cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 220,
                  width: 180,
                  child: SkeletonShimmer(child: SkeletonProductCard()),
                ),
                SizedBox(
                  height: 170,
                  width: 220,
                  child: SkeletonShimmer(child: SkeletonStoreCard()),
                ),
                SkeletonShimmer(child: SkeletonCategoryItem()),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonShimmer), findsNWidgets(3));
      expect(find.byType(SkeletonProductCard), findsOneWidget);
      expect(find.byType(SkeletonStoreCard), findsOneWidget);
      expect(find.byType(SkeletonCategoryItem), findsOneWidget);
    });

    testWidgets('2. CustomerHomeScreenSkeleton renders cleanly within viewport', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerHomeScreenSkeleton(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomerHomeScreenSkeleton), findsOneWidget);
      expect(find.byType(SkeletonShimmer), findsOneWidget);
      expect(find.byType(SkeletonCategoryItem), findsWidgets);
      expect(find.byType(SkeletonStoreCard), findsWidgets);
    });
  });
}
