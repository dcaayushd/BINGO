import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../widgets/bingo_cell.dart';

class BingoBoard extends StatelessWidget {
  final GameState gameState;
  final Function(int) onNumberSelected;

  const BingoBoard(
      {super.key, required this.gameState, required this.onNumberSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade100, Colors.purple.shade300],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Text(
            gameState.bingoStatus.isEmpty ? "Bingo" : gameState.bingoStatus,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: Colors.purple.shade900,
            ),
          ),
          SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 25,
            itemBuilder: (context, index) {
              int row = index ~/ 5;
              int col = index % 5;
              int number = gameState.board[row][col];
              return BingoCell(
                number: number,
                marked: gameState.marked[number - 1],
                isAiSelection: gameState.isAiSelection[number] ?? false,
                onTap: () => onNumberSelected(number),
              );
            },
          ),
        ],
      ),
    );
  }
}
