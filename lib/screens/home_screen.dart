import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/ai_difficulty.dart';
import '../models/app_theme_mode.dart';
import '../models/player_profile.dart';
import '../services/audio_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import 'multiplayer_screen.dart';
import 'single_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key, required this.profile, required this.onProfileChanged});

  final PlayerProfile profile;
  final ValueChanged<PlayerProfile> onProfileChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PlayerProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  void _updateProfile(PlayerProfile profile) {
    setState(() => _profile = profile);
    widget.onProfileChanged(profile);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) _profile = widget.profile;
  }

  Future<void> _openSinglePlayer() async {
    final difficulty = await _pickDifficulty();
    if (!mounted || difficulty == null) return;
    await AudioService().playButtonClick();
    if (!mounted) return;
    final updated = await Navigator.of(context).push<PlayerProfile>(
      _gameRoute(SinglePlayerScreen(profile: _profile, difficulty: difficulty)),
    );
    if (updated != null && mounted) _updateProfile(updated);
  }

  Future<void> _openMultiplayer() async {
    await AudioService().playButtonClick();
    if (!mounted) return;
    final updated = await Navigator.of(context).push<PlayerProfile>(
      _gameRoute(MultiplayerScreen(profile: _profile)),
    );
    if (updated != null && mounted) _updateProfile(updated);
  }

  PageRoute<T> _gameRoute<T>(Widget child) => PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => child,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, __, routeChild) {
          final offset =
              Tween<Offset>(begin: const Offset(0, .025), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic))
                  .animate(animation);
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(position: offset, child: routeChild),
          );
        },
      );

  Future<AiDifficulty?> _pickDifficulty() {
    return showModalBottomSheet<AiDifficulty>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose AI level',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (final difficulty in AiDifficulty.values)
                _DifficultyTile(
                  difficulty: difficulty,
                  onTap: () => Navigator.pop(sheetContext, difficulty),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSettings() async {
    final result = await showModalBottomSheet<PlayerProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _SettingsSheet(profile: _profile),
    );
    if (result == null) return;
    await ProfileService.instance.save(result);
    AudioService().setSoundEnabled(result.soundEnabled);
    AudioService().setClickSoundsEnabled(result.clickSoundsEnabled);
    AudioService().setTurnSoundsEnabled(result.turnSoundsEnabled);
    if (mounted) _updateProfile(result);
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.screenGradientFor(Theme.of(context).brightness);
    return Scaffold(
      backgroundColor:
          AppColors.screenBottomColorFor(Theme.of(context).brightness),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Bingo Game',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _showSettings,
            icon: const Icon(CupertinoIcons.settings_solid),
          ),
          const SizedBox(width: 6),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            const Positioned.fill(
                child: IgnorePointer(
                    child: CustomPaint(painter: _BingoBackdrop()))),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Bingo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 48,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Welcome, ${_profile.displayName}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .88),
                              fontSize: 16),
                        ),
                        const SizedBox(height: 38),
                        ElevatedButton.icon(
                          onPressed: _openSinglePlayer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.ink,
                            minimumSize: const Size.fromHeight(64),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: const Icon(Icons.smart_toy_outlined),
                          label: const Text('Play with AI'),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _openMultiplayer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mint,
                            foregroundColor: AppColors.ink,
                            minimumSize: const Size.fromHeight(64),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: const Icon(Icons.people_outline),
                          label: const Text('Play with Friends'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.profile});

  final PlayerProfile profile;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final TextEditingController _nameController;
  late bool _soundEnabled;
  late bool _clickSoundsEnabled;
  late bool _turnSoundsEnabled;
  late AppThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _soundEnabled = widget.profile.soundEnabled;
    _clickSoundsEnabled = widget.profile.clickSoundsEnabled;
    _turnSoundsEnabled = widget.profile.turnSoundsEnabled;
    _themeMode = widget.profile.themeMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final displayName = _nameController.text.trim();
    Navigator.of(context).pop(
      widget.profile.copyWith(
        displayName: displayName.isEmpty ? 'Player' : displayName,
        soundEnabled: _soundEnabled,
        clickSoundsEnabled: _clickSoundsEnabled,
        turnSoundsEnabled: _turnSoundsEnabled,
        themeMode: _themeMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Settings',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                maxLength: 20,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Player name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SegmentedButton<AppThemeMode>(
                segments: [
                  for (final mode in AppThemeMode.values)
                    ButtonSegment(
                      value: mode,
                      icon: Icon(mode.icon),
                      label: Text(mode.label),
                    ),
                ],
                selected: {_themeMode},
                onSelectionChanged: (selected) =>
                    setState(() => _themeMode = selected.first),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _soundEnabled,
                onChanged: (value) => setState(() => _soundEnabled = value),
                title: const Text('Game sounds'),
                subtitle: const Text('Round start and results'),
                secondary: Icon(_soundEnabled
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _soundEnabled && _clickSoundsEnabled,
                onChanged: _soundEnabled
                    ? (value) => setState(() => _clickSoundsEnabled = value)
                    : null,
                title: const Text('Click sounds'),
                subtitle: const Text('Buttons and board selections'),
                secondary: const Icon(Icons.touch_app_outlined),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _soundEnabled && _turnSoundsEnabled,
                onChanged: _soundEnabled
                    ? (value) => setState(() => _turnSoundsEnabled = value)
                    : null,
                title: const Text('Turn sounds'),
                subtitle: const Text('Alerts when it is your turn'),
                secondary: const Icon(Icons.notifications_active_outlined),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: const Text('Save settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({required this.difficulty, required this.onTap});

  final AiDifficulty difficulty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(_difficultyIcon(difficulty),
              color: colorScheme.onPrimaryContainer),
        ),
        title: Text('${difficulty.label} AI',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(difficulty.description),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

IconData _difficultyIcon(AiDifficulty difficulty) => switch (difficulty) {
      AiDifficulty.easy => Icons.sentiment_satisfied_outlined,
      AiDifficulty.medium => Icons.psychology_outlined,
      AiDifficulty.hard => Icons.bolt_outlined,
    };

class _BingoBackdrop extends CustomPainter {
  const _BingoBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: .07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()..color = Colors.white.withValues(alpha: .055);
    final cell = size.shortestSide / 5.5;
    canvas.save();
    canvas.translate(size.width * .05, size.height * .18);
    canvas.rotate(-.15);
    for (var row = 0; row < 5; row++) {
      for (var column = 0; column < 5; column++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(column * (cell + 8), row * (cell + 8), cell, cell),
          const Radius.circular(10),
        );
        canvas.drawRRect(rect, fill);
        canvas.drawRRect(rect, stroke);
      }
    }
    canvas.restore();
    for (var index = 0; index < 5; index++) {
      final text = TextPainter(
        text: TextSpan(
            text: 'BINGO'[index],
            style: TextStyle(
                color: Colors.white.withValues(alpha: .07),
                fontSize: 62,
                fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas,
          Offset(size.width - text.width - 18, size.height * .62 + index * 55));
    }
  }

  @override
  bool shouldRepaint(covariant _BingoBackdrop oldDelegate) => false;
}
