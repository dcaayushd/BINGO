import 'package:flutter/material.dart';

class BingoCell extends StatelessWidget {
  final int number;
  final bool marked;
  final bool isAiSelection;
  final VoidCallback onTap;

  const BingoCell({super.key, 
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
          border: Border.all(color: Colors.grey.shade300, width: 1),
          color: marked
              ? (isAiSelection ? Colors.orange.shade100 : Colors.green.shade100)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
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
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }
}