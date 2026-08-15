import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/shared/widgets/uni_loader.dart';
import 'package:uniride_app/shared/screens/splash_screen.dart';

void main() {
  testWidgets('UniLoader paints at every size it is used at', (tester) async {
    for (final size in [20.0, 22.0, 44.0, 108.0]) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: UniLoader(size: size)))),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
  });

  testWidgets('UniDots paints', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: UniDots()))));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash builds and animates', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('UniRide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
