class GameState {
  List<List<int>> board; // 5x5 Bingo board
  List<bool> marked; // Tracks marked numbers on the board
  Map<int, bool> isAiSelection; // Tracks if a number was selected by AI
  String bingoStatus; // Current BINGO status (e.g., "B", "BI", "BIN", etc.)
  String roomId; // Room ID for multiplayer
  List<int> selectedNumbers; // List of selected numbers
  Map<int, int> playerSelections; // Tracks which player selected each number

  GameState({
    required this.board,
    required this.marked,
    required this.isAiSelection,
    required this.bingoStatus,
    required this.roomId,
    required this.selectedNumbers,
    required this.playerSelections,
  });

  // Factory constructor for initializing a new game state
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
      bingoStatus: "",
      roomId: "",
      selectedNumbers: [],
      playerSelections: {},
    );
  }

  // Convert GameState to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'board': board.map((row) => row.map((e) => e).toList()).toList(),
      'marked': marked.map((e) => e).toList(),
      'isAiSelection':
          isAiSelection.map((key, value) => MapEntry(key.toString(), value)),
      'playerSelections':
          playerSelections.map((key, value) => MapEntry(key.toString(), value)),
      'bingoStatus': bingoStatus,
      'selectedNumbers': selectedNumbers,
    };
  }

  // Create GameState from JSON (Firebase data)
  factory GameState.fromJson(Map<String, dynamic> json) {
    // Parse player selections with better error handling
    Map<int, int> parsePlayerSelections(dynamic data) {
      Map<int, int> result = {};
      if (data != null) {
        if (data is Map) {
          data.forEach((key, value) {
            try {
              final numKey = int.parse(key.toString());
              final numValue = int.tryParse(value.toString()) ?? -1;
              result[numKey] = numValue;
            } catch (e) {
              print('Error parsing player selection: $e');
            }
          });
        }
      }
      return result;
    }

    // Parse board with error handling
    List<List<int>> parseBoard(dynamic data) {
      List<List<int>> result = List.generate(5, (_) => List.generate(5, (_) => 0));
      if (data != null && data is List) {
        for (int i = 0; i < data.length && i < 5; i++) {
          var row = data[i];
          if (row is List) {
            for (int j = 0; j < row.length && j < 5; j++) {
              try {
                result[i][j] = (row[j] is int) ? row[j] : int.parse(row[j].toString());
              } catch (e) {
                print('Error parsing board value: $e');
              }
            }
          }
        }
      }
      return result;
    }

    // Parse marked with error handling
    List<bool> parseMarked(dynamic data) {
      List<bool> result = List.filled(25, false);
      if (data != null && data is List) {
        for (int i = 0; i < data.length && i < 25; i++) {
          result[i] = (data[i] == true);
        }
      }
      return result;
    }

    // Parse AI selections with error handling
    Map<int, bool> parseAiSelections(dynamic data) {
      Map<int, bool> result = {};
      if (data != null && data is Map) {
        data.forEach((key, value) {
          try {
            final numKey = int.parse(key.toString());
            result[numKey] = (value == true);
          } catch (e) {
            print('Error parsing AI selection: $e');
          }
        });
      }
      return result;
    }

    // Parse selected numbers
    List<int> parseSelectedNumbers(dynamic data) {
      List<int> result = [];
      if (data != null && data is List) {
        for (var item in data) {
          try {
            if (item is int) {
              result.add(item);
            } else {
              result.add(int.parse(item.toString()));
            }
          } catch (e) {
            print('Error parsing selected number: $e');
          }
        }
      }
      return result;
    }

    return GameState(
      board: parseBoard(json['board']),
      marked: parseMarked(json['marked']),
      isAiSelection: parseAiSelections(json['isAiSelection']),
      playerSelections: parsePlayerSelections(json['playerSelections']),
      bingoStatus: json['bingoStatus'] as String? ?? "",
      roomId: json['roomId'] as String? ?? "",
      selectedNumbers: parseSelectedNumbers(json['selectedNumbers']),
    );
  }

  // Mark a number on the board
  bool markNumber(int number, {bool isAi = false, int playerIndex = -1}) {
    // If number is already selected, don't do anything
    if (selectedNumbers.contains(number)) {
      return false;
    }

    // Find the position of the number on the board
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 5; col++) {
        if (board[row][col] == number) {
          // Calculate the index in the marked list (0-24)
          int index = row * 5 + col;
          marked[index] = true;
          isAiSelection[number] = isAi;
          if (playerIndex >= 0) {
            playerSelections[number] = playerIndex;
          }
          selectedNumbers.add(number);
          updateBingoStatus();
          return true;
        }
      }
    }
    return false; // Number not found on the board
  }

  // Update BINGO status based on marked numbers
  void updateBingoStatus() {
    int bingoCount = 0;

    // Check rows for BINGO
    for (int i = 0; i < 5; i++) {
      bool rowBingo = true;
      for (int j = 0; j < 5; j++) {
        int index = i * 5 + j;
        if (!marked[index]) {
          rowBingo = false;
          break;
        }
      }
      if (rowBingo) bingoCount++;
    }

    // Check columns for BINGO
    for (int j = 0; j < 5; j++) {
      bool colBingo = true;
      for (int i = 0; i < 5; i++) {
        int index = i * 5 + j;
        if (!marked[index]) {
          colBingo = false;
          break;
        }
      }
      if (colBingo) bingoCount++;
    }

    // Check diagonals for BINGO
    bool diagBingo = true;
    for (int i = 0; i < 5; i++) {
      int index = i * 5 + i;
      if (!marked[index]) {
        diagBingo = false;
        break;
      }
    }
    if (diagBingo) bingoCount++;

    diagBingo = true;
    for (int i = 0; i < 5; i++) {
      int index = i * 5 + (4 - i);
      if (!marked[index]) {
        diagBingo = false;
        break;
      }
    }
    if (diagBingo) bingoCount++;

    // Update BINGO status
    bingoStatus = "BINGO".substring(0, bingoCount > 5 ? 5 : bingoCount);
  }

  // Reset the game state but keep the same board
  void reset() {
    marked = List.filled(25, false);
    isAiSelection = {};
    bingoStatus = "";
    selectedNumbers = [];
    playerSelections = {};
  }
}