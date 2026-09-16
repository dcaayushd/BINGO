import 'package:bingo/models/player_profile.dart';
import 'package:bingo/screens/multiplayer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an unconfigured build shows a calm multiplayer state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MultiplayerScreen(profile: PlayerProfile.initial())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Multiplayer is not available yet'), findsOneWidget);
    expect(find.textContaining('--dart-define'), findsNothing);
  });
}
