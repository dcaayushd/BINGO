import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../widgets/bingo_cell.dart';

class BingoBoard extends StatelessWidget {
  final GameState gameState;
  final Function(int) onNumberSelected;
  final VoidCallback onRestart;

  const BingoBoard({
    super.key,
    required this.gameState,
    required this.onNumberSelected,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(156, 39, 176, 0.7),
                Color.fromRGBO(123, 31, 162, 0.9),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                gameState.bingoStatus.isEmpty ? "Bingo" : gameState.bingoStatus,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: onRestart,
                icon: Icon(Icons.replay, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(156, 39, 176, 0.7),
                Color.fromRGBO(123, 31, 162, 0.9),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.all(16),
          child: GridView.builder(
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
              bool isMarked = gameState.marked[
                  index]; // Use the index to check if the number is marked
              return BingoCell(
                number: number,
                marked: isMarked,
                isAiSelection: gameState.isAiSelection[number] ?? false,
                onTap: () => onNumberSelected(number),
              );
            },
          ),
        ),
      ],
    );
  }
}
