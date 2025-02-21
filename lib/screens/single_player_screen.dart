import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../widgets/bingo_board.dart';

class SinglePlayerScreen extends StatefulWidget {
  const SinglePlayerScreen({super.key});

  @override
  SinglePlayerScreenState createState() => SinglePlayerScreenState();
}

class SinglePlayerScreenState extends State<SinglePlayerScreen> {
  final GameService gameService = GameService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Single Player")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: BingoBoard(
                gameState: gameService.playerState,
                onNumberSelected: (number) {
                  setState(() {
                    if (gameService.playerState.markNumber(number)) {
                      if (gameService.playerState.bingoStatus == "BINGO") {
                        _showWinDialog("You won!");
                      } else {
                        if (gameService.aiMove()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "AI selected: ${gameService.playerState.selectedNumbers.last}",
                              ),
                            ),
                          );
                          if (gameService.playerState.bingoStatus == "BINGO") {
                            _showWinDialog("AI won!");
                          }
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Number already selected!")),
                      );
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWinDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Game Over"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Return to home screen
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
  }
}