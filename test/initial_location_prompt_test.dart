import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quicklink/features/customer/presentation/bloc/customer_bloc.dart';
import 'package:quicklink/features/customer/presentation/widgets/initial_location_prompt_sheet.dart';

class _FakeCustomerBloc extends Bloc<CustomerEvent, CustomerState> implements CustomerBloc {
  _FakeCustomerBloc() : super(const CustomerState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('InitialLocationPromptSheet renders all options responsively without overflow', (tester) async {
    final bloc = _FakeCustomerBloc();

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<CustomerBloc>.value(
            value: bloc,
            child: const InitialLocationPromptSheet(animate: false),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and subtitle
    expect(find.text('Where should we deliver?'), findsOneWidget);
    expect(find.textContaining('Enable location access'), findsOneWidget);

    // Verify primary GPS CTA button
    expect(find.text('Use Current Location (GPS)'), findsOneWidget);

    // Verify secondary map picker CTA button
    expect(find.text('Select Location on Map'), findsOneWidget);

    // Verify manual entry and skip buttons
    expect(find.text('Enter manually'), findsOneWidget);
    expect(find.text('Explore without location'), findsOneWidget);

    expect(tester.takeException(), isNull);

    await bloc.close();
  });
}
