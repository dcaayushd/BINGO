import 'dart:math';

/// One player's board. Selections are shared by a match, but a shuffled board
/// means each player completes lines at a different pace.
class GameState {
  GameState({
    required this.board,
    List<bool>? marked,
    Map<int, int>? playerSelections,
    List<int>? selectedNumbers,
    this.roomId = '',
  })  : marked = marked ?? List<bool>.filled(25, false),
        playerSelections = playerSelections ?? <int, int>{},
        selectedNumbers = selectedNumbers ?? <int>[] {
    _validateBoard(board);
    _recalculateLines();
  }

  factory GameState.initial({Random? random}) {
    final numbers = List<int>.generate(25, (index) => index + 1)
      ..shuffle(random);
    return GameState(
      board: List<List<int>>.generate(
        5,
        (row) => numbers.sublist(row * 5, row * 5 + 5),
      ),
    );
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    final boardData = json['board'];
    if (boardData is! List) return GameState.initial();
    final board = boardData
        .whereType<List>()
        .map((row) => row.map((item) => int.parse(item.toString())).toList())
        .toList();
    final selections = <int, int>{};
    final rawSelections = json['playerSelections'];
    if (rawSelections is Map) {
      rawSelections.forEach((key, value) {
        final number = int.tryParse(key.toString());
        final owner = int.tryParse(value.toString());
        if (number != null && owner != null) selections[number] = owner;
      });
    }
    final selected = (json['selectedNumbers'] as List? ?? const <dynamic>[])
        .map((item) => int.tryParse(item.toString()))
        .whereType<int>()
        .toList();
    final marked = (json['marked'] as List? ?? const <dynamic>[])
        .map((item) => item == true)
        .toList();
    return GameState(
      board: board,
      marked: marked.length == 25 ? marked : null,
      playerSelections: selections,
      selectedNumbers: selected,
      roomId: json['roomId']?.toString() ?? '',
    );
  }

  final List<List<int>> board;
  List<bool> marked;
  Map<int, int> playerSelections;
  List<int> selectedNumbers;
  final String roomId;
  List<Set<int>> _completedLines = <Set<int>>[];

  int get lineCount => _completedLines.length;
  String get bingoStatus => 'BINGO'.substring(0, min(lineCount, 5));
  bool get isComplete => lineCount >= 5;
  List<Set<int>> get completedLines => List.unmodifiable(_completedLines);

  bool isMarked(int number) => selectedNumbers.contains(number);

  /// Independent snapshot for local AI look-ahead. The board itself is
  /// immutable for a round, while selection state must never leak back into
  /// the live game during evaluation.
  GameState copy() => GameState(
        board: board.map((row) => List<int>.from(row)).toList(),
        marked: List<bool>.from(marked),
        playerSelections: Map<int, int>.from(playerSelections),
        selectedNumbers: List<int>.from(selectedNumbers),
        roomId: roomId,
      );

  /// Applies a number selected elsewhere in the match to this board.
  /// Returns false when it was already applied or is outside the valid range.
  bool applySelection(int number, {required int selectedBy}) {
    if (number < 1 || number > 25 || selectedNumbers.contains(number)) {
      return false;
    }
    final index = _indexOf(number);
    if (index < 0) return false;
    marked[index] = true;
    selectedNumbers.add(number);
    playerSelections[number] = selectedBy;
    _recalculateLines();
    return true;
  }

  /// Synchronises this board from an authoritative multiplayer room update.
  void applySelections(Iterable<int> numbers, Map<int, int> owners) {
    marked = List<bool>.filled(25, false);
    selectedNumbers = <int>[];
    playerSelections = Map<int, int>.from(owners);
    for (final number in numbers) {
      final index = _indexOf(number);
      if (index >= 0) {
        marked[index] = true;
        selectedNumbers.add(number);
      }
    }
    _recalculateLines();
  }

  /// A lightweight tactical value used by the local opponent.
  int tacticalValueFor(int number) {
    if (isMarked(number)) return -1;
    final index = _indexOf(number);
    if (index < 0) return -1;
    final row = index ~/ 5;
    final column = index % 5;
    var score = 0;
    for (final line in _lineIndexesFor(row, column)) {
      final markedInLine = line.where((cell) => marked[cell]).length;
      score += markedInLine * markedInLine + 1;
      if (markedInLine == 4) score += 100;
    }
    if (row == 2 && column == 2) score += 2;
    if ((row == 0 || row == 4) && (column == 0 || column == 4)) score += 1;
    return score;
  }

  /// Number of lines that this currently unmarked selection would complete.
  /// This is side-effect free so AI planning never mutates the live board.
  int completedLineDeltaFor(int number) {
    if (isMarked(number)) return 0;
    final index = _indexOf(number);
    if (index < 0) return 0;
    final row = index ~/ 5;
    final column = index % 5;
    return _lineIndexesFor(row, column)
        .where((line) => line.where((cell) => marked[cell]).length == 4)
        .length;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'board': board,
        'marked': marked,
        'playerSelections':
            playerSelections.map((key, value) => MapEntry('$key', value)),
        'selectedNumbers': selectedNumbers,
        'roomId': roomId,
      };

  int _indexOf(int number) {
    for (var row = 0; row < 5; row++) {
      for (var column = 0; column < 5; column++) {
        if (board[row][column] == number) return row * 5 + column;
      }
    }
    return -1;
  }

  Iterable<Set<int>> _lineIndexesFor(int row, int column) sync* {
    yield <int>{for (var cell = 0; cell < 5; cell++) row * 5 + cell};
    yield <int>{for (var cell = 0; cell < 5; cell++) cell * 5 + column};
    if (row == column) {
      yield <int>{for (var cell = 0; cell < 5; cell++) cell * 6};
    }
    if (row + column == 4) {
      yield <int>{for (var cell = 0; cell < 5; cell++) 4 + cell * 4};
    }
  }

  void _recalculateLines() {
    _completedLines = <Set<int>>[];
    for (var row = 0; row < 5; row++) {
      final line = <int>{for (var cell = 0; cell < 5; cell++) row * 5 + cell};
      if (line.every((cell) => marked[cell])) _completedLines.add(line);
    }
    for (var column = 0; column < 5; column++) {
      final line = <int>{
        for (var cell = 0; cell < 5; cell++) cell * 5 + column
      };
      if (line.every((cell) => marked[cell])) _completedLines.add(line);
    }
    final forward = <int>{for (var cell = 0; cell < 5; cell++) cell * 6};
    if (forward.every((cell) => marked[cell])) _completedLines.add(forward);
    final reverse = <int>{for (var cell = 0; cell < 5; cell++) 4 + cell * 4};
    if (reverse.every((cell) => marked[cell])) _completedLines.add(reverse);
  }

  static void _validateBoard(List<List<int>> board) {
    if (board.length != 5 || board.any((row) => row.length != 5)) {
      throw ArgumentError.value(
          board, 'board', 'A Bingo board must be 5 by 5.');
    }
  }
}
