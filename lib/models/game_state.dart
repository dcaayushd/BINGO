class GameState {
  List<List<int>> board;
  List<bool> marked;
  Map<int, bool> isAiSelection;
  String bingoStatus;
  String roomId;
  List<int> selectedNumbers;

  GameState({
    required this.board,
    this.marked = const [],
    this.isAiSelection = const {},
    this.bingoStatus = "",
    this.roomId = "",
    this.selectedNumbers = const [],
  });

  factory GameState.initial() {
    List<List<int>> generateBoard() {
      List<int> numbers = List.generate(25, (i) => i + 1)..shuffle();
      List<List<int>> board = [];
      for (int i = 0; i < 5; i++) {
        board.add(numbers.sublist(i * 5, (i + 1) * 5));
      }
      return board;
    }

    return GameState(
      board: generateBoard(),
      marked: List.filled(25, false),
      isAiSelection: {},
      selectedNumbers: [],
    );
  }

  // Add these methods for Firebase
  Map<String, dynamic> toJson() {
    return {
      'board': board.map((row) => row.map((e) => e).toList()).toList(),
      'marked': marked.map((e) => e).toList(),
      'isAiSelection': isAiSelection.map((key, value) => MapEntry(key.toString(), value)),
      'bingoStatus': bingoStatus,
      'selectedNumbers': selectedNumbers,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      board: (json['board'] as List).map((row) => 
        (row as List).map((e) => e as int).toList()
      ).toList(),
      marked: (json['marked'] as List).map((e) => e as bool).toList(),
      isAiSelection: (json['isAiSelection'] as Map).map(
        (key, value) => MapEntry(int.parse(key as String), value as bool)
      ),
      bingoStatus: json['bingoStatus'] as String,
      selectedNumbers: (json['selectedNumbers'] as List).map((e) => e as int).toList(),
    );
  }

  bool markNumber(int number, {bool isAi = false}) {
    if (selectedNumbers.contains(number)) return false; // Number already selected
    int index = number - 1;
    if (index >= 0 && index < 25) {
      marked[index] = true;
      isAiSelection[number] = isAi;
      selectedNumbers.add(number);
      updateBingoStatus();
      return true;
    }
    return false;
  }

  void updateBingoStatus() {
    int bingoCount = 0;
    // Check rows
    for (int i = 0; i < 5; i++) {
      if (List.generate(5, (j) => marked[board[i][j] - 1]).every((m) => m)) bingoCount++;
    }
    // Check columns
    for (int j = 0; j < 5; j++) {
      if (List.generate(5, (i) => marked[board[i][j] - 1]).every((m) => m)) bingoCount++;
    }
    // Check diagonals
    if (List.generate(5, (i) => marked[board[i][i] - 1]).every((m) => m)) bingoCount++;
    if (List.generate(5, (i) => marked[board[i][4 - i] - 1]).every((m) => m)) bingoCount++;

    bingoStatus = "BINGO".substring(0, bingoCount > 5 ? 5 : bingoCount);
  }
}