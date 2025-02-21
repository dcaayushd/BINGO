import 'package:flutter/material.dart';

class BingoCell extends StatelessWidget {
  final int number;
  final bool marked;
  final VoidCallback onTap;

  const BingoCell({super.key, 
    required this.number,
    required this.marked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: marked ? Colors.redAccent : Colors.blueAccent,
          border: Border.all(color: Colors.white),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}