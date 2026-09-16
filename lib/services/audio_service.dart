import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;
  bool _clickSoundsEnabled = true;
  bool _turnSoundsEnabled = true;

  factory AudioService() {
    return _instance;
  }

  AudioService._internal();

  bool get isMuted => !_soundEnabled;

  void setSoundEnabled(bool value) => _soundEnabled = value;
  void setClickSoundsEnabled(bool value) => _clickSoundsEnabled = value;
  void setTurnSoundsEnabled(bool value) => _turnSoundsEnabled = value;

  /// Play sound effect for button click
  Future<void> playButtonClick() =>
      _playSound('assets/sounds/button_click.wav', isClick: true);

  /// Play sound effect for cell selection
  Future<void> playCellSelect() =>
      _playSound('assets/sounds/cell_select.wav', isClick: true);

  /// Play sound effect for winning
  Future<void> playWinSound() async {
    await _playSound('assets/sounds/win_sound.wav');
  }

  /// Play sound effect for game start
  Future<void> playGameStart() async {
    await _playSound('assets/sounds/game_start.wav');
  }

  /// Play notification sound
  Future<void> playNotification() async {
    await _playSound('assets/sounds/notification.wav');
  }

  /// Play the player's-turn notification, if it is enabled in Settings.
  Future<void> playTurnSound() =>
      _playSound('assets/sounds/notification.wav', isTurn: true);

  Future<void> _playSound(
    String assetPath, {
    bool isClick = false,
    bool isTurn = false,
  }) async {
    if (!_soundEnabled ||
        (isClick && !_clickSoundsEnabled) ||
        (isTurn && !_turnSoundsEnabled)) {
      return;
    }
    try {
      await _player.stop();
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (e) {
      debugPrint('Could not play $assetPath: $e');
    }
  }

  /// Toggle mute
  void toggleMute() {
    _soundEnabled = !_soundEnabled;
  }

  /// Dispose all audio players
  void dispose() {
    _player.dispose();
  }
}
