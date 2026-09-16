import 'package:bingo/models/player_profile.dart';
import 'package:bingo/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists the separate turn-sound preference', () async {
    SharedPreferences.setMockInitialValues({});
    final profile = PlayerProfile.initial().copyWith(turnSoundsEnabled: false);

    await ProfileService.instance.save(profile);
    final restored = await ProfileService.instance.load();

    expect(restored.turnSoundsEnabled, isFalse);
  });
}
