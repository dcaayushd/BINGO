import 'package:flutter/material.dart';

import 'models/player_profile.dart';
import 'screens/home_screen.dart';
import 'services/audio_service.dart';
import 'services/profile_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final profile = await ProfileService.instance.load();
  AudioService().setSoundEnabled(profile.soundEnabled);
  AudioService().setClickSoundsEnabled(profile.clickSoundsEnabled);
  AudioService().setTurnSoundsEnabled(profile.turnSoundsEnabled);
  runApp(MyApp(initialProfile: profile));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.initialProfile});

  final PlayerProfile initialProfile;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late PlayerProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
  }

  void _applyProfile(PlayerProfile profile) {
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bingo',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: _profile.themeMode.materialThemeMode,
      home: HomeScreen(profile: _profile, onProfileChanged: _applyProfile),
    );
  }
}
