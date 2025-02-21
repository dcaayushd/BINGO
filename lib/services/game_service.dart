import 'dart:math';
import '/models/game_state.dart';

class GameService {
  final _random = Random();
  GameState playerState = GameState.initial();

  // AI selects a number from the player's board
  bool aiMove() {
    List<int> availableNumbers = List.generate(25, (i) => i + 1)
        .where((n) => !playerState.selectedNumbers.contains(n))
        .toList();
    if (availableNumbers.isNotEmpty) {
      int number = availableNumbers[_random.nextInt(availableNumbers.length)];
      return playerState.markNumber(number);
    }
    return false;
  }

  // Multiplayer room simulation
  Map<String, List<GameState>> rooms = {};

  String createRoom(List<GameState> players) {
    String roomId = (_random.nextInt(9000) + 1000).toString();
    rooms[roomId] = players;
    return roomId;
  }

  void joinRoom(String roomId, GameState playerState) {
    if (rooms.containsKey(roomId)) {
      rooms[roomId]!.add(playerState);
    }
  }

  bool syncMove(String roomId, int number) {
    if (rooms.containsKey(roomId)) {
      bool success = true;
      for (var state in rooms[roomId]!) {
        if (!state.markNumber(number)) success = false; // Mark fails if already selected
      }
      return success;
    }
    return false;
  }
}