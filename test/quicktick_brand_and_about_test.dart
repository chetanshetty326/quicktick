import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quicklink/features/customer/presentation/widgets/quicktick_brand_footer.dart';
import 'package:quicklink/features/customer/presentation/widgets/about_quicktick_sheet.dart';
import 'package:quicklink/features/customer/presentation/widgets/order_rating_feedback_sheet.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/order/domain/entities/order_entity.dart';

class _FakeCustomerBloc extends Bloc<CustomerEvent, CustomerState> implements CustomerBloc {
  _FakeCustomerBloc() : super(const CustomerState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testOrder = OrderEntity(
    id: 'test_order_1',
    orderNumber: 'ORD-98765',
    customerId: 'cust_1',
    customerName: 'Customer Test',
    customerPhone: '+919876543210',
    deliveryAddress: 'Indiranagar 100ft Road, Bengaluru',
    storeId: 'store_1',
    storeName: 'Bengaluru Fresh Mart & Organic Provisions Supermarket',
    storeAddress: 'Indiranagar, Bengaluru',
    items: const [
      OrderItemEntity(
        productId: 'p1',
        nameSnapshot: 'Fresh Milk',
        priceSnapshot: 30.0,
        unit: 'packet',
        quantity: 2,
      ),
      OrderItemEntity(
        productId: 'p2',
        nameSnapshot: 'Artisan Bread',
        priceSnapshot: 45.0,
        unit: 'loaf',
        quantity: 1,
      ),
    ],
    subtotal: 105.0,
    deliveryFee: 15.0,
    platformFee: 5.0,
    grandTotal: 125.0,
    status: OrderStatus.delivered,
    deliveryOtp: '1234',
    createdAt: DateTime(2025, 1, 1),
  );

  final viewports = [
    const Size(320, 568), // Narrow 320px (iPhone SE 1st gen)
    const Size(360, 640), // Standard compact Android
    const Size(390, 844), // iPhone 12/13/14
    const Size(414, 896), // iPhone Plus / Max
    const Size(600, 960), // Foldable / Small tablet
    const Size(768, 1024), // iPad / Tablet
  ];

  group('QuickTick Responsive UI & Branding Tests Across Viewports', () {
    testWidgets('1. QuickTickBrandFooter renders text and handles tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickTickBrandFooter(),
          ),
        ),
      );

      expect(find.text('QUICKTICK'), findsOneWidget);
      expect(find.text('A product from Prajnan Softwares'), findsOneWidget);
      expect(find.text('Crafted with pride in Karnataka'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
    });

    for (final size in viewports) {
      testWidgets('2. QuickTickBrandFooter responsive on ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: QuickTickBrandFooter(compact: true),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('QUICKTICK'), findsOneWidget);
        expect(find.text('A product from Prajnan Softwares'), findsOneWidget);
      });

      testWidgets('3. AboutQuickTickSheet responsive on ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => AboutQuickTickSheet.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('QUICKTICK'), findsOneWidget);
        expect(find.text('A product from Karnataka,\nfrom Prajnan Softwares'), findsOneWidget);
        expect(find.text('Visit Website'), findsOneWidget);
      });

      testWidgets('4. OrderRatingFeedbackSheet responsive on ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final bloc = _FakeCustomerBloc();

        await tester.pumpWidget(
          BlocProvider<CustomerBloc>.value(
            value: bloc,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => OrderRatingFeedbackSheet.show(context, order: testOrder),
                    child: const Text('Rate'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Rate'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Order Delivered!'), findsOneWidget);
        expect(find.text('SUBMIT FEEDBACK'), findsOneWidget);
        expect(find.text('Maybe Later'), findsOneWidget);

        await bloc.close();
      });
    }
  });
}
