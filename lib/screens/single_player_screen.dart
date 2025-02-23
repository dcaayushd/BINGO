import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '/services/game_service.dart';
import '/widgets/bingo_board.dart';

class SinglePlayerScreen extends StatefulWidget {
  const SinglePlayerScreen({super.key});

  @override
  SinglePlayerScreenState createState() => SinglePlayerScreenState();
}

class SinglePlayerScreenState extends State<SinglePlayerScreen> {
  final GameService gameService = GameService();
  bool isPlayerTurn = true;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade100, Colors.purple.shade400],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 20),
                  Text(
                    isPlayerTurn ? "Your Turn" : "AI's Turn",
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: BingoBoard(
                        gameState: gameService.playerState,
                        onNumberSelected: (number) {
                          if (isPlayerTurn) {
                            setState(() {
                              if (gameService.playerState.markNumber(number)) {
                                if (gameService.playerState.bingoStatus ==
                                    "BINGO") {
                                  _showWinDialog("You won!", isPlayerWin: true);
                                } else {
                                  isPlayerTurn = false;
                                  Future.delayed(Duration(milliseconds: 500),
                                      () {
                                    setState(() {
                                      gameService.aiMove();
                                      if (gameService.playerState.bingoStatus ==
                                          "BINGO") {
                                        _showWinDialog("AI won!",
                                            isPlayerWin: false);
                                      } else {
                                        isPlayerTurn = true;
                                      }
                                    });
                                  });
                                }
                              }
                            });
                          }
                        },
                        onRestart: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [Colors.green, Colors.yellow, Colors.pink, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }

  void _showWinDialog(String message, {required bool isPlayerWin}) {
    if (isPlayerWin) _confettiController.play();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade300, Colors.purple.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Game Over",
                style: TextStyle(
                  fontSize: 28,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  "OK",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.purple.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
