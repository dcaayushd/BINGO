import 'package:bingo/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _orderedBoard() => GameState(
      board: const [
        [1, 2, 3, 4, 5],
        [6, 7, 8, 9, 10],
        [11, 12, 13, 14, 15],
        [16, 17, 18, 19, 20],
        [21, 22, 23, 24, 25],
      ],
    );

void main() {
  group('GameState', () {
    test('counts a completed row and keeps selection ownership', () {
      final state = _orderedBoard();

      for (var number = 1; number <= 5; number++) {
        expect(state.applySelection(number, selectedBy: 0), isTrue);
      }

      expect(state.lineCount, 1);
      expect(state.bingoStatus, 'B');
      expect(state.marked.take(5), everyElement(isTrue));
      expect(state.playerSelections[3], 0);
      expect(state.applySelection(3, selectedBy: 1), isFalse);
    });

    test('counts intersecting lines only once each', () {
      final state = _orderedBoard();
      const selected = <int>[1, 2, 3, 4, 5, 6, 11, 16, 21];

      for (final number in selected) {
        state.applySelection(number, selectedBy: 1);
      }

      expect(state.lineCount, 2);
      expect(state.bingoStatus, 'BI');
    });

    test('rebuilds marks from a server-authoritative selection list', () {
      final state = _orderedBoard();
      state.applySelections(const [1, 7, 13], const {1: 0, 7: 1, 13: 0});

      expect(state.selectedNumbers, [1, 7, 13]);
      expect(state.marked.where((value) => value).length, 3);
      expect(state.playerSelections[7], 1);
      expect(state.lineCount, 0);
    });
  });
}
