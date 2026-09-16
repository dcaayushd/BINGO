import 'package:flutter/material.dart';

import '../models/game_state.dart';

class BingoBoard extends StatelessWidget {
  const BingoBoard({
    super.key,
    required this.gameState,
    required this.onNumberSelected,
    this.enabled = true,
    this.playerIndex,
    this.showOpponentColors = false,
  });

  final GameState gameState;
  final ValueChanged<int> onNumberSelected;
  final bool enabled;
  final int? playerIndex;
  final bool showOpponentColors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BingoProgress(lineCount: gameState.lineCount),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            // Reserve the container and inter-cell gutters, so the grid fills
            // its available width while retaining a comfortable screen edge.
            final cellSize =
                ((constraints.maxWidth - 46) / 5).clamp(46.0, 74.0);
            return Container(
              width: constraints.maxWidth,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < 5; row++)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var column = 0; column < 5; column++)
                          _BingoCell(
                            number: gameState.board[row][column],
                            size: cellSize,
                            marked: gameState.marked[row * 5 + column],
                            enabled: enabled,
                            color: _cellColor(gameState.board[row][column]),
                            onTap: onNumberSelected,
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
        if (showOpponentColors) ...[
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: Colors.green, label: 'Your selections'),
              SizedBox(width: 16),
              _Legend(color: Colors.red, label: "Opponent's selections"),
            ],
          ),
        ],
      ],
    );
  }

  Color _cellColor(int number) {
    final owner = gameState.playerSelections[number];
    if (owner == null || playerIndex == null) {
      return gameState.playerSelections[number] == 1
          ? Colors.red
          : Colors.green;
    }
    return owner == playerIndex ? Colors.green : Colors.red;
  }
}

class _BingoProgress extends StatelessWidget {
  const _BingoProgress({required this.lineCount});

  final int lineCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < 5; index++)
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: lineCount > index
                      ? Colors.green
                      : Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  'BINGO'[index],
                  style: TextStyle(
                    color: Colors.white
                        .withValues(alpha: lineCount > index ? 1 : .70),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BingoCell extends StatelessWidget {
  const _BingoCell({
    required this.number,
    required this.size,
    required this.marked,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final int number;
  final double size;
  final bool marked;
  final bool enabled;
  final Color color;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: marked ? color : Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled && !marked ? () => onTap(number) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: .30)),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: Colors.white.withValues(alpha: marked ? 1 : .90),
                fontSize: size >= 52 ? 23 : 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
