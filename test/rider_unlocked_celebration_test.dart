import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/core/theme/app_theme.dart';
import 'package:uniride_app/features/rider/presentation/widgets/rider_unlocked_celebration.dart';

/// A screen with a button that opens the celebration and records its result.
Widget _host(void Function(bool?) onResult) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async =>
                onResult(await RiderUnlockedCelebration.open(context)),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the sequence settles into its copy and its two choices', (
    tester,
  ) async {
    bool? result;
    var called = false;
    await tester.pumpWidget(_host((r) {
      result = r;
      called = true;
    }));

    await tester.tap(find.text('go'));
    await tester.pump();

    // Mid-sequence the buttons are not pressable yet — a tap here is a skip.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('You’re a rider now'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('Start riding'), findsOneWidget);
    expect(find.text('Stay here'), findsOneWidget);

    await tester.tap(find.text('Start riding'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(result, isTrue);
  });

  testWidgets('staying resolves false, so the caller leaves them put', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(_host((r) => result = r));

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3600));

    await tester.tap(find.text('Stay here'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('mid-sequence a tap skips rather than pressing what is under it', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(_host((_) => called = true));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The button is on screen but faded out and inert — this tap is a skip.
    await tester.tap(find.text('Start riding'), warnIfMissed: false);
    await tester.pump();
    expect(called, isFalse, reason: 'the celebration should not have closed');

    // ...and the skip has run the sequence out, so the same tap now works.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Start riding'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
  });

  testWidgets('reduced motion lands on the end state with no travel', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host((_) => called = true),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump();

    // No sequence to wait out — it is all there on the first frame, and the
    // buttons are live immediately.
    expect(find.text('You’re a rider now'), findsOneWidget);
    await tester.tap(find.text('Start riding'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
  });

  testWidgets('it fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host((_) {}));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3600));

    expect(tester.takeException(), isNull);
    expect(find.text('Start riding'), findsOneWidget);
  });
}
