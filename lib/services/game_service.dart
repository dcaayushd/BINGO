import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import 'dart:math';

class GameService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
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

  Future<String> createRoom(String playerName) async {
    try {
      final roomId = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final player1GameState = GameState.initial();

      await _database.child('rooms').child(roomId).set({
        'status': 'waiting',
        'currentTurn': 0,
        'timestamp': ServerValue.timestamp,
        'players': {
          '0': {
            'name': playerName,
            'isReady': false,
            'gameState': player1GameState.toJson(),
          }
        }
      });

      return roomId;
    } catch (e) {
      debugPrint('Error creating room: $e');
      throw Exception('Failed to create room');
    }
  }

  Future<bool> joinRoom(String roomId, String playerName) async {
    try {
      final roomRef = _database.child('rooms').child(roomId);
      final roomSnapshot = await roomRef.get();
      if (!roomSnapshot.exists) {
        debugPrint('Room does not exist');
        return false;
      }

      final dynamic rawData = roomSnapshot.value;
      Map<String, dynamic> roomData = _safelyConvertData(rawData);

      if (roomData['status'] != 'waiting') {
        debugPrint('Room is not in waiting status: ${roomData['status']}');
        return false;
      }

      Map<String, dynamic> players = {};
      final playersData = roomData['players'];
      if (playersData != null) {
        players = _safelyConvertData(playersData);
      }

      if (players.length >= 2 || players.containsKey('1')) {
        debugPrint('Room is full: ${players.length} players');
        return false;
      }

      final player2GameState = GameState.initial();
      await roomRef.child('players/1').set({
        'name': playerName,
        'isReady': false,
        'gameState': player2GameState.toJson(),
      });

      return true;
    } catch (e) {
      debugPrint('Error joining room: $e');
      return false;
    }
  }

  Stream<Map<String, dynamic>> getRoomStream(String roomId) {
    return _database.child('rooms').child(roomId).onValue.map((event) {
      if (!event.snapshot.exists) {
        debugPrint('Room snapshot does not exist');
        return {};
      }

      try {
        final dynamic value = event.snapshot.value;
        if (value == null) {
          debugPrint('Room value is null');
          return {};
        }

        debugPrint('Room data type: ${value.runtimeType}');
        return _safelyConvertData(value);
      } catch (e) {
        debugPrint('Error processing room data: $e');
        return {'error': e.toString()};
      }
    });
  }

  Map<String, dynamic> _safelyConvertData(dynamic data) {
    if (data == null) return {};

    if (data is Map) {
      final Map<String, dynamic> result = {};

      data.forEach((key, value) {
        final String stringKey = key.toString();

        if (value is Map) {
          result[stringKey] = _safelyConvertData(value);
        } else if (value is List) {
          // Handle lists properly
          if (stringKey == 'players') {
            // Convert player list to map with string keys
            Map<String, dynamic> convertedPlayers = {};
            for (int i = 0; i < value.length; i++) {
              if (value[i] != null) {
                convertedPlayers[i.toString()] = _safelyConvertData(value[i]);
              }
            }
            result[stringKey] = convertedPlayers;
          } else if (stringKey == 'selectedNumbers') {
            // Keep selected numbers as a list
            result[stringKey] = value.where((item) => item != null).toList();
          } else {
            // For other lists
            result[stringKey] = value.map((item) {
              if (item is Map) {
                return _safelyConvertData(item);
              }
              return item;
            }).toList();
          }
        } else {
          result[stringKey] = value;
        }
      });

      return result;
    }

    return {};
  }

  Future<void> makeMove(String roomId, int playerIndex, int number) async {
    try {
      final roomRef = _database.child('rooms').child(roomId);

      // First, check if it's this player's turn
      final roomSnapshot = await roomRef.get();
      if (!roomSnapshot.exists) {
        debugPrint('Room does not exist');
        return;
      }

      final dynamic roomData = roomSnapshot.value;
      debugPrint('Room data for move: $roomData');

      // Convert the data structure safely
      final Map<String, dynamic> roomMap = _safelyConvertData(roomData);

      int currentTurn = roomMap['currentTurn'] as int? ?? 0;
      if (currentTurn != playerIndex) {
        debugPrint('Not player\'s turn. Current turn: $currentTurn, player: $playerIndex');
        return;
      }

      // Get player data using correct path
      final playersData = roomMap['players'];
      if (playersData == null) {
        debugPrint('No players data found in room');
        return;
      }

      Map<String, dynamic> players = {};
      
      if (playersData is Map) {
        players = _safelyConvertData(playersData);
      } else if (playersData is List) {
        // Handle the case where players come as a list
        for (int i = 0; i < playersData.length; i++) {
          if (playersData[i] != null) {
            players[i.toString()] = _safelyConvertData(playersData[i]);
          }
        }
      } else {
        debugPrint('Players data has unexpected type: ${playersData.runtimeType}');
        return;
      }

      // Debug players data structure
      debugPrint('Players data: $players');
      debugPrint('Player keys: ${players.keys.toList()}');
      
      final String playerKey = playerIndex.toString();
      if (!players.containsKey(playerKey)) {
        debugPrint('Player $playerIndex not found in players data');
        return;
      }

      final Map<String, dynamic> currentPlayerData = _safelyConvertData(players[playerKey]);

      // Verify gameState exists
      if (!currentPlayerData.containsKey('gameState')) {
        debugPrint('GameState not found in player data. Available keys: ${currentPlayerData.keys.toList()}');
        return;
      }

      final gameStateData = currentPlayerData['gameState'];
      if (gameStateData == null) {
        debugPrint('GameState is null');
        return;
      }

      final Map<String, dynamic> gameStateMap = _safelyConvertData(gameStateData);
      final gameState = GameState.fromJson(gameStateMap);

      // Mark number on current player's board with player index
      if (gameState.markNumber(number, playerIndex: playerIndex)) {
        debugPrint('Marking number $number for player $playerIndex');

        // Update current player's game state
        await roomRef.child('players').child(playerKey).child('gameState').set(gameState.toJson());

        // Get opponent index
        final opponentIndex = (playerIndex + 1) % 2;
        final opponentKey = opponentIndex.toString();

        // Update opponent's board with the same number
        if (players.containsKey(opponentKey)) {
          final Map<String, dynamic> opponentPlayerData = _safelyConvertData(players[opponentKey]);

          if (opponentPlayerData.containsKey('gameState')) {
            final opponentGameStateData = opponentPlayerData['gameState'];
            final Map<String, dynamic> opponentGameStateMap = _safelyConvertData(opponentGameStateData);
            final opponentGameState = GameState.fromJson(opponentGameStateMap);

            // Mark the SAME number on opponent's board, indicate it was selected by the current player
            opponentGameState.markNumber(number, playerIndex: playerIndex);

            // Update opponent's game state
            await roomRef.child('players').child(opponentKey).child('gameState').set(opponentGameState.toJson());
          }
        }

        // Update turn and last move
        await roomRef.update({
          'currentTurn': opponentIndex,
          'lastMove': number,
        });
      }
    } catch (e) {
      debugPrint('Error making move: $e');
    }
  }

  Future<void> leaveRoom(String roomId, int playerIndex) async {
    if (roomId.isEmpty || playerIndex < 0) {
      debugPrint('Invalid room ID or player index');
      return;
    }

    try {
      final roomRef = _database.child('rooms').child(roomId);
      await roomRef.child('players').child(playerIndex.toString()).remove();

      final playersSnapshot = await roomRef.child('players').get();
      if (!playersSnapshot.exists || playersSnapshot.value == null) {
        await roomRef.remove();
        return;
      }

      final dynamic playersValue = playersSnapshot.value;
      bool shouldRemoveRoom = false;

      if (playersValue is Map && playersValue.isEmpty) {
        shouldRemoveRoom = true;
      } else if (playersValue is List) {
        bool hasPlayers = false;
        for (var player in playersValue) {
          if (player != null) {
            hasPlayers = true;
            break;
          }
        }
        shouldRemoveRoom = !hasPlayers;
      }

      if (shouldRemoveRoom) {
        await roomRef.remove();
      } else {
        await roomRef.update({'status': 'ended'});
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }
}