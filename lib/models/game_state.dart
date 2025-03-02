class GameState {
  List<List<int>> board;
  List<bool> marked;
  Map<int, bool> isAiSelection;
  String bingoStatus;
  String roomId;
  List<int> selectedNumbers;
  Map<int, int> playerSelections;

  GameState({
    required this.board,
    required this.marked,
    required this.isAiSelection,
    required this.bingoStatus,
    required this.roomId,
    required this.selectedNumbers,
    required this.playerSelections,
  });

  factory GameState.initial() {
    List<List<int>> generateBoard() {
      List<int> numbers = List.generate(25, (i) => i + 1)..shuffle();
      return List.generate(5, (i) => numbers.sublist(i * 5, (i + 1) * 5));
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

  Map<String, dynamic> toJson() {
    return {
      'board': board.map((row) => row.map((e) => e).toList()).toList(),
      'marked': marked.map((e) => e).toList(),
      'isAiSelection': isAiSelection.map((key, value) => MapEntry(key.toString(), value)),
      'playerSelections': playerSelections.map((key, value) => MapEntry(key.toString(), value)),
      'bingoStatus': bingoStatus,
      'selectedNumbers': selectedNumbers,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    Map<int, int> parsePlayerSelections(dynamic data) {
      Map<int, int> result = {};
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
      return result;
    }

    List<List<int>> parseBoard(dynamic data) {
      List<List<int>> result = List.generate(5, (_) => List.generate(5, (_) => 0));
      if (data is List) {
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

    List<bool> parseMarked(dynamic data) {
      List<bool> result = List.filled(25, false);
      if (data is List) {
        for (int i = 0; i < data.length && i < 25; i++) {
          result[i] = (data[i] == true);
        }
      }
      return result;
    }

    Map<int, bool> parseAiSelections(dynamic data) {
      Map<int, bool> result = {};
      if (data is Map) {
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

    List<int> parseSelectedNumbers(dynamic data) {
      List<int> result = [];
      if (data is List) {
        for (var item in data) {
          try {
            result.add(item is int ? item : int.parse(item.toString()));
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

bool markNumber(int number, {bool isAi = false, int playerIndex = -1}) {
  if (selectedNumbers.contains(number)) return false;
  
  for (int row = 0; row < 5; row++) {
    for (int col = 0; col < 5; col++) {
      if (board[row][col] == number) {
        int index = row * 5 + col;
        marked[index] = true;
        isAiSelection[number] = isAi;
        
        // Always update playerSelections if a valid playerIndex is provided
        if (playerIndex >= 0) {
          playerSelections[number] = playerIndex;
        }
        
        selectedNumbers.add(number);
        updateBingoStatus();
        return true;
      }
    }
  }
  return false;
}

  void updateBingoStatus() {
    int bingoCount = 0;

    for (int i = 0; i < 5; i++) {
      bool rowBingo = true;
      bool colBingo = true;
      for (int j = 0; j < 5; j++) {
        if (!marked[i * 5 + j]) rowBingo = false;
        if (!marked[j * 5 + i]) colBingo = false;
      }
      if (rowBingo) bingoCount++;
      if (colBingo) bingoCount++;
    }

    bool diagBingo = true;
    for (int i = 0; i < 5; i++) {
      if (!marked[i * 5 + i]) diagBingo = false;
    }
    if (diagBingo) bingoCount++;

    diagBingo = true;
    for (int i = 0; i < 5; i++) {
      if (!marked[i * 5 + (4 - i)]) diagBingo = false;
    }
    if (diagBingo) bingoCount++;

    bingoStatus = "BINGO".substring(0, bingoCount > 5 ? 5 : bingoCount);
  }

  void reset() {
    marked = List.filled(25, false);
    isAiSelection = {};
    bingoStatus = "";
    selectedNumbers = [];
    playerSelections = {};
  }
}