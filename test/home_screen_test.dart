import 'package:bingo/models/player_profile.dart';
import 'package:bingo/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('saving settings keeps the text field valid while it closes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PlayerProfile? savedProfile;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          profile: PlayerProfile.initial(),
          onProfileChanged: (profile) => savedProfile = profile,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Aayush');
    await tester.tap(find.text('Save settings'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(savedProfile?.displayName, 'Aayush');
  });
}
