class GameState {
  List<List<int>> board; // 5x5 bingo board
  List<bool> marked; // Tracks marked numbers (1-25)
  String bingoStatus; // Tracks "B", "I", "N", "G", "O"
  String roomId; // For multiplayer
  List<int> selectedNumbers; // Tracks all numbers selected in the game

  GameState({
    required this.board,
    this.marked = const [],
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
      selectedNumbers: [],
    );
  }

  bool markNumber(int number) {
    if (selectedNumbers.contains(number)) return false; // Number already selected
    int index = number - 1;
    if (index >= 0 && index < 25) {
      marked[index] = true;
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