import 'package:flutter/material.dart';

import '../screens/multiplayer_screen.dart';
import '../screens/single_player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bingo")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SinglePlayerScreen())),
              child: Text("Play with AI"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => MultiplayerScreen())),
              child: Text("Play with Friends"),
            ),
          ],
        ),
      ),
    );
  }
}
