import 'package:bingo/models/ai_difficulty.dart';
import 'package:bingo/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all AI levels are immediately selectable', () {
    expect(AiDifficulty.values.map((level) => level.label),
        ['Easy', 'Medium', 'Hard']);

    final profile = PlayerProfile.initial().recordAiResult(won: true);
    expect(profile.gamesPlayed, 1);
    expect(profile.wins, 1);
    expect(profile.losses, 0);
  });
}
