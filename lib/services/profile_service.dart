import '../models/app_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';

class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  static const _nameKey = 'profile.name';
  static const _soundKey = 'profile.soundEnabled';
  static const _clickSoundsKey = 'profile.clickSoundsEnabled';
  static const _turnSoundsKey = 'profile.turnSoundsEnabled';
  static const _themeKey = 'profile.themeMode';
  static const _playedKey = 'profile.gamesPlayed';
  static const _winsKey = 'profile.wins';
  static const _lossesKey = 'profile.losses';

  Future<PlayerProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerProfile(
      displayName: (prefs.getString(_nameKey) ?? 'Player').trim().isEmpty
          ? 'Player'
          : (prefs.getString(_nameKey) ?? 'Player').trim(),
      soundEnabled: prefs.getBool(_soundKey) ?? true,
      clickSoundsEnabled: prefs.getBool(_clickSoundsKey) ?? true,
      turnSoundsEnabled: prefs.getBool(_turnSoundsKey) ?? true,
      themeMode: AppThemeMode.fromStorage(prefs.getString(_themeKey)),
      gamesPlayed: prefs.getInt(_playedKey) ?? 0,
      wins: prefs.getInt(_winsKey) ?? 0,
      losses: prefs.getInt(_lossesKey) ?? 0,
    );
  }

  Future<void> save(PlayerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(
          _nameKey,
          profile.displayName.trim().isEmpty
              ? 'Player'
              : profile.displayName.trim()),
      prefs.setBool(_soundKey, profile.soundEnabled),
      prefs.setBool(_clickSoundsKey, profile.clickSoundsEnabled),
      prefs.setBool(_turnSoundsKey, profile.turnSoundsEnabled),
      prefs.setString(_themeKey, profile.themeMode.name),
      prefs.setInt(_playedKey, profile.gamesPlayed),
      prefs.setInt(_winsKey, profile.wins),
      prefs.setInt(_lossesKey, profile.losses),
    ]);
  }

  Future<PlayerProfile> recordAiResult(
    PlayerProfile profile, {
    required bool won,
  }) async {
    final updated = profile.recordAiResult(won: won);
    await save(updated);
    return updated;
  }

  Future<PlayerProfile> recordMultiplayerResult(
    PlayerProfile profile, {
    required bool won,
  }) async {
    final updated = profile.recordMultiplayerResult(won: won);
    await save(updated);
    return updated;
  }
}
