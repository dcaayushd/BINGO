import 'package:flutter/material.dart';

class BingoCell extends StatelessWidget {
  final int number;
  final bool marked;
  final bool isAiSelection;
  final VoidCallback onTap;

  const BingoCell({
    super.key,
    required this.number,
    required this.marked,
    required this.isAiSelection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border:
              Border.all(color: Color.fromRGBO(255, 255, 255, 0.2), width: 1),
          color: marked
              ? (isAiSelection
                  ? Color.fromRGBO(255, 152, 0, 0.9) // Orange for AI
                  : Color.fromRGBO(76, 175, 80, 0.9)) // Green for player
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: TextStyle(
              color: marked ? Colors.white : Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }
}
