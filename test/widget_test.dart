import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniride_app/shared/widgets/app_button.dart';

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

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(tapped, isFalse);
  });
}
