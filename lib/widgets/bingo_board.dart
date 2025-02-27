import 'package:flutter/material.dart';
import '../models/game_state.dart';

class BingoBoard extends StatelessWidget {
  final GameState gameState;
  final Function(int) onNumberSelected;
  final VoidCallback onRestart;
  final bool showOpponentColors;
  final int? playerIndex;

  const BingoBoard({
    super.key,
    required this.gameState,
    required this.onNumberSelected,
    required this.onRestart,
    this.showOpponentColors = false,
    this.playerIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // BINGO Text and indicator
        Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 5; i++)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: gameState.bingoStatus.length > i
                        ? Colors.green
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text(
                      "BINGO"[i],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: gameState.bingoStatus.length > i
                            ? Colors.white
                            : Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Bingo board
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              for (int row = 0; row < 5; row++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int col = 0; col < 5; col++)
                      _buildBingoCell(
                        gameState.board[row][col],
                        gameState.selectedNumbers
                            .contains(gameState.board[row][col]),
                        row * 5 + col,
                      ),
                  ],
                ),
            ],
          ),
        ),

        // Legend for colors
        if (showOpponentColors)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildColorDot(playerIndex == 0 ? Colors.green : Colors.orange,
                    "Your selections"),
                SizedBox(width: 12),
                _buildColorDot(playerIndex == 0 ? Colors.orange : Colors.green,
                    "Opponent's selections"),
              ],
            ),
          ),

        // Restart button
        Container(
          margin: EdgeInsets.only(top: 20),
          child: ElevatedButton(
            onPressed: onRestart,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              "Exit Game",
              style: TextStyle(
                fontSize: 16,
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBingoCell(int number, bool isMarked, int index) {
    // Get the color based on who selected it
    Color cellColor = Colors.transparent;
    if (isMarked) {
      // For multiplayer, check which player selected this number
      if (showOpponentColors &&
          gameState.playerSelections.containsKey(number)) {
        int playerWhoSelected = gameState.playerSelections[number] ?? -1;

        // Always use green for player 0 and orange for player 1 in multiplayer
        cellColor = playerWhoSelected == 0 ? Colors.green : Colors.orange;
      } else {
        // Default color (single player or AI mode)
        cellColor =
            gameState.isAiSelection[number] == true ? Colors.red : Colors.green;
      }
    }

    return GestureDetector(
      onTap: () {
        if (!isMarked) {
          onNumberSelected(number);
        }
      },
      child: Container(
        width: 60,
        height: 60,
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isMarked ? cellColor : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isMarked ? Colors.white : Colors.white.withOpacity(0.9),
            ),
          ),
        ),
      ),
    );
  }
}
