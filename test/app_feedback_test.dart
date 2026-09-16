import 'package:bingo/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a new toast replaces the previous message with neutral text',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showAppToast(
                context,
                'Enter the six-character room code.',
              ),
              child: const Text('Show toast'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    final firstToast = tester.widget<Text>(
      find.text('Enter the six-character room code.'),
    );
    expect(firstToast.style?.color, isNot(Colors.red));
    expect(firstToast.style?.decoration, TextDecoration.none);
    expect(firstToast.style?.inherit, isFalse);

    final context = tester.element(find.byType(FilledButton));
    showAppToast(context, 'Room code copied');
    await tester.pump();

    expect(find.text('Enter the six-character room code.'), findsNothing);
    expect(find.text('Room code copied'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
