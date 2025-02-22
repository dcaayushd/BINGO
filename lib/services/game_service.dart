
import 'dart:math';

import '../models/game_state.dart';

class GameService {
  final _random = Random();
  GameState playerState = GameState.initial();

  bool aiMove() {
    List<int> availableNumbers = List.generate(25, (i) => i + 1)
        .where((n) => !playerState.selectedNumbers.contains(n))
        .toList();
    if (availableNumbers.isNotEmpty) {
      int number = availableNumbers[_random.nextInt(availableNumbers.length)];
      return playerState.markNumber(number, isAi: true);
    }
    return false;
  }

  Map<String, Map<String, dynamic>> rooms = {}; // roomId -> {players: [GameState], names: [String]}

  String createRoom(String playerName) {
    String roomId = (_random.nextInt(9000) + 1000).toString();
    rooms[roomId] = {
      'players': [GameState.initial()],
      'names': [playerName],
    };
    return roomId;
  }

  bool joinRoom(String roomId, String playerName) {
    if (rooms.containsKey(roomId) && rooms[roomId]!['players'].length < 2) {
      rooms[roomId]!['players'].add(GameState.initial());
      rooms[roomId]!['names'].add(playerName);
      return true;
    }
    return false;
  }

  bool syncMove(String roomId, int number, int playerIndex) {
    if (rooms.containsKey(roomId)) {
      bool success = true;
      for (var state in rooms[roomId]!['players']) {
        if (!state.markNumber(number, isAi: playerIndex == 1)) success = false;
      }
      return success;
    }
    return false;
  }
}