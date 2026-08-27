import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/shared/widgets/slide_action.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onConfirm,
    bool busy = false,
    bool enabled = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SlideAction(
                label: 'Slide to request',
                busyLabel: 'Sending request',
                busy: busy,
                enabled: enabled,
                onConfirm: onConfirm,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a full slide confirms', (tester) async {
    var fired = 0;
    await pump(tester, onConfirm: () => fired++);

    await tester.drag(find.byIcon(Icons.arrow_forward_rounded), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(fired, 1);
  });

  testWidgets('a short slide does not — the point of the control', (tester) async {
    var fired = 0;
    await pump(tester, onConfirm: () => fired++);

    await tester.drag(find.byIcon(Icons.arrow_forward_rounded), const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(fired, 0);
  });

  testWidgets('a request in flight cannot be sent twice', (tester) async {
    var fired = 0;
    // busy is how the caller says "already sending" — dragging again while it
    // lands must not post a second request.
    await pump(tester, onConfirm: () => fired++, busy: true);

    await tester.drag(find.byType(SlideAction), const Offset(300, 0));
    // Not pumpAndSettle: the busy spinner animates forever and never settles.
    await tester.pump(const Duration(milliseconds: 400));

    expect(fired, 0);
  });

  testWidgets('busy shows the busy label and a spinner', (tester) async {
    await pump(tester, onConfirm: () {}, busy: true);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sending request'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('disabled ignores the gesture', (tester) async {
    var fired = 0;
    await pump(tester, onConfirm: () => fired++, enabled: false);

    await tester.drag(find.byIcon(Icons.arrow_forward_rounded), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(fired, 0);
  });
}
