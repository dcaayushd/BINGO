import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../widgets/bingo_cell.dart';

class BingoBoard extends StatelessWidget {
  final GameState gameState;
  final Function(int) onNumberSelected;

  const BingoBoard({
    super.key,
    required this.gameState,
    required this.onNumberSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          gameState.bingoStatus.isEmpty
              ? "Nepali Bingo"
              : gameState.bingoStatus,
          style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 25,
          itemBuilder: (context, index) {
            int row = index ~/ 5;
            int col = index % 5;
            int number = gameState.board[row][col];
            return BingoCell(
              number: number,
              marked: gameState.marked[number - 1],
              onTap: () => onNumberSelected(number),
            );
          },
        ),
      ],
    );
  }
}
