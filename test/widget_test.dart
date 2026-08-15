import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniride_app/shared/widgets/app_button.dart';
import 'package:uniride_app/shared/widgets/uni_loader.dart';

void main() {
  testWidgets('AppButton shows label and fires onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Log in',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Log in'), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    expect(tapped, isTrue);
  });

  testWidgets('AppButton shows spinner and is disabled while loading',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Log in',
            loading: true,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(UniLoader), findsOneWidget);
    expect(find.text('Log in'), findsNothing);
    await tester.tap(find.byType(AppButton));
    expect(tapped, isFalse);
  });

  testWidgets('AppButton ignores taps when onPressed is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppButton(label: 'Continue', onPressed: null)),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    await tester.pump();
  });
}
