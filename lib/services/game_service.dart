import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../models/game_state.dart';

class GameService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final _random = Random();
  
  // Add back the single player state
  GameState playerState = GameState.initial();
  
  // Single player methods
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

  // Multiplayer methods
  Future<String> createRoom(String playerName) async {
    final roomId = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final gameState = GameState.initial();
    
    await _database.child('rooms/$roomId').set({
      'status': 'waiting',
      'currentTurn': 0,
      'players': {
        '0': {
          'name': playerName,
          'gameState': gameState.toJson(),
        }
      }
    });
    
    return roomId;
  }

  Future<bool> joinRoom(String roomId, String playerName) async {
    final snapshot = await _database.child('rooms/$roomId').get();
    if (!snapshot.exists) return false;
    
    final room = snapshot.value as Map<dynamic, dynamic>;
    final players = room['players'] as Map<dynamic, dynamic>;
    
    if (players.length >= 2) return false;
    
    final gameState = GameState.initial();
    await _database.child('rooms/$roomId/players/1').set({
      'name': playerName,
      'gameState': gameState.toJson(),
    });
    
    await _database.child('rooms/$roomId').update({
      'status': 'playing'
    });
    
    return true;
  }

  Stream<DatabaseEvent> getRoomStream(String roomId) {
    return _database.child('rooms/$roomId').onValue;
  }

  Future<void> makeMove(String roomId, int playerIndex, int number) async {
    final playerRef = _database.child('rooms/$roomId/players/$playerIndex');
    final snapshot = await playerRef.get();
    if (!snapshot.exists) return;

    final playerData = snapshot.value as Map<dynamic, dynamic>;
    final gameState = GameState.fromJson(Map<String, dynamic>.from(playerData['gameState']));
    
    if (gameState.markNumber(number)) {
      await playerRef.update({
        'gameState': gameState.toJson()
      });
      
      await _database.child('rooms/$roomId').update({
        'currentTurn': (playerIndex + 1) % 2,
        'lastMove': number,
      });
    }
  }

  Future<void> leaveRoom(String roomId, int playerIndex) async {
    await _database.child('rooms/$roomId').update({
      'status': 'ended'
    });
  }
}