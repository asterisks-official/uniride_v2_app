import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/features/rider/presentation/widgets/rider_form_widgets.dart';

/// The box the vehicle grid hands each tile: two columns on a narrow phone,
/// with the fixed row height from `SliverGridDelegateWithFixedCrossAxisCount`.
Widget _inGridCell({
  required Widget child,
  double width = 150,
  double height = 92,
  double textScale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a vehicle tile fits its grid cell', (tester) async {
    await tester.pumpWidget(
      _inGridCell(
        child: VehicleTypeTile(
          icon: Icons.two_wheeler,
          label: 'Motorcycle',
          selected: true,
          onTap: () {},
        ),
      ),
    );

    // Overflow is reported as an exception rather than a failed expectation.
    expect(tester.takeException(), isNull);
  });

  testWidgets('a disabled tile fits too — it carries an extra line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _inGridCell(
        child: VehicleTypeTile(
          icon: Icons.local_taxi_outlined,
          label: 'CNG / Auto',
          selected: false,
          enabled: false,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Soon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it survives a large system text size', (tester) async {
    // The original tile derived its height from the screen width, so a big
    // text setting on a narrow phone was guaranteed to overflow it.
    await tester.pumpWidget(
      _inGridCell(
        width: 130,
        textScale: 1.8,
        child: VehicleTypeTile(
          icon: Icons.local_taxi_outlined,
          label: 'CNG / Auto',
          selected: false,
          enabled: false,
          onTap: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('a disabled tile cannot be selected', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _inGridCell(
        child: VehicleTypeTile(
          icon: Icons.directions_car_outlined,
          label: 'Car',
          selected: false,
          enabled: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(VehicleTypeTile));
    await tester.pump();

    expect(tapped, isFalse);
  });
}
