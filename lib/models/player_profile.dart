import 'app_theme_mode.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.displayName,
    required this.soundEnabled,
    required this.clickSoundsEnabled,
    required this.turnSoundsEnabled,
    required this.themeMode,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
  });

  factory PlayerProfile.initial() => const PlayerProfile(
        displayName: 'Player',
        soundEnabled: true,
        clickSoundsEnabled: true,
        turnSoundsEnabled: true,
        themeMode: AppThemeMode.system,
        gamesPlayed: 0,
        wins: 0,
        losses: 0,
      );

  final String displayName;
  final bool soundEnabled;
  final bool clickSoundsEnabled;
  final bool turnSoundsEnabled;
  final AppThemeMode themeMode;
  final int gamesPlayed;
  final int wins;
  final int losses;

  PlayerProfile copyWith({
    String? displayName,
    bool? soundEnabled,
    bool? clickSoundsEnabled,
    bool? turnSoundsEnabled,
    AppThemeMode? themeMode,
    int? gamesPlayed,
    int? wins,
    int? losses,
  }) {
    return PlayerProfile(
      displayName: displayName ?? this.displayName,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      clickSoundsEnabled: clickSoundsEnabled ?? this.clickSoundsEnabled,
      turnSoundsEnabled: turnSoundsEnabled ?? this.turnSoundsEnabled,
      themeMode: themeMode ?? this.themeMode,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
    );
  }

  PlayerProfile recordAiResult({required bool won}) {
    return copyWith(
      gamesPlayed: gamesPlayed + 1,
      wins: wins + (won ? 1 : 0),
      losses: losses + (won ? 0 : 1),
    );
  }

  PlayerProfile recordMultiplayerResult({required bool won}) => copyWith(
        gamesPlayed: gamesPlayed + 1,
        wins: wins + (won ? 1 : 0),
        losses: losses + (won ? 0 : 1),
      );
}
