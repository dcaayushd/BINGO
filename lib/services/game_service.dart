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
      final roomId =
          DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final gameState = GameState.initial();

      // Create initial room structure with more explicit typing
      await _database.child('rooms').child(roomId).set({
        'status': 'waiting',
        'currentTurn': 0,
        'timestamp': ServerValue.timestamp,
        'players': {
          '0': {
            'name': playerName,
            'gameState': gameState.toJson(),
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

      // Get room data
      final roomSnapshot = await roomRef.get();
      if (!roomSnapshot.exists) {
        debugPrint('Room does not exist');
        return false;
      }

      // Safe conversion to map
      Map<String, dynamic> roomData = {};
      try {
        final dynamic rawData = roomSnapshot.value;
        if (rawData is Map) {
          roomData = _convertToStringDynamicMap(rawData);
        } else {
          debugPrint('Room data is not a Map: ${rawData.runtimeType}');
          return false;
        }
      } catch (e) {
        debugPrint('Error converting room data: $e');
        return false;
      }

      // Check room status
      if (roomData['status'] != 'waiting') {
        debugPrint('Room is not in waiting status: ${roomData['status']}');
        return false;
      }

      // Get players data - with safer access
      final playersData = roomData['players'];
      if (playersData == null) {
        debugPrint('No players data found');
        return false;
      }

      Map<String, dynamic> players = {};
      if (playersData is Map) {
        players = _convertToStringDynamicMap(playersData);
      } else if (playersData is List) {
        // Handle case where Firebase returns a list
        for (int i = 0; i < playersData.length; i++) {
          if (playersData[i] != null) {
            players[i.toString()] = playersData[i];
          }
        }
      } else {
        debugPrint(
            'Players data is not a Map or List: ${playersData.runtimeType}');
        return false;
      }

      if (players.length >= 2 || players.containsKey('1')) {
        debugPrint('Room is full: ${players.length} players');
        return false;
      }

      // Create player data
      final gameState = GameState.initial();
      final updates = {
        '/players/1': {
          'name': playerName,
          'gameState': gameState.toJson(),
        },
        '/status': 'playing',
      };

      // Update room data
      await roomRef.update(updates);
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

        // Print the actual type for debugging
        debugPrint('Room data type: ${value.runtimeType}');

        // Convert DataSnapshot value to a Map<String, dynamic>
        if (value is Map) {
          return _processRoomData(value);
        } else {
          debugPrint('Room data is not a Map: ${value.runtimeType}');
          return {};
        }
      } catch (e) {
        debugPrint('Error processing room data: $e');
        return {};
      }
    });
  }

  // Process room data with better error handling
  Map<String, dynamic> _processRoomData(Map rawData) {
    Map<String, dynamic> roomData = {};

    rawData.forEach((key, val) {
      if (key is String) {
        if (key == 'players' && val != null) {
          Map<String, dynamic> players = {};

          if (val is Map) {
            val.forEach((playerKey, playerValue) {
              if (playerKey is String && playerValue is Map) {
                players[playerKey] = _convertToStringDynamicMap(playerValue);
              }
            });
          } else if (val is List) {
            // Handle list format from Firebase
            for (int i = 0; i < val.length; i++) {
              if (val[i] != null) {
                players[i.toString()] =
                    val[i] is Map ? _convertToStringDynamicMap(val[i]) : val[i];
              }
            }
          } else {
            debugPrint('Players data is unexpected type: ${val.runtimeType}');
          }

          roomData[key] = players;
        } else {
          roomData[key] = val;
        }
      }
    });

    return roomData;
  }

  // Helper method to convert Map<Object?, Object?> to Map<String, dynamic>
  Map<String, dynamic> _convertToStringDynamicMap(Map map) {
    Map<String, dynamic> result = {};
    map.forEach((key, value) {
      if (key is String) {
        if (value is Map) {
          result[key] = _convertToStringDynamicMap(value);
        } else if (value is List) {
          // Handle lists within maps
          List<dynamic> convertedList = [];
          for (var item in value) {
            if (item is Map) {
              convertedList.add(_convertToStringDynamicMap(item));
            } else {
              convertedList.add(item);
            }
          }
          result[key] = convertedList;
        } else {
          result[key] = value;
        }
      }
    });
    return result;
  }

  Future<void> makeMove(String roomId, int playerIndex, int number) async {
    try {
      final roomRef = _database.child('rooms').child(roomId);
      final playerRef = roomRef.child('players').child(playerIndex.toString());

      final playerSnapshot = await playerRef.get();
      if (!playerSnapshot.exists) {
        debugPrint('Player data does not exist');
        return;
      }

      // Better type handling
      final dynamic playerValue = playerSnapshot.value;
      if (playerValue is! Map) {
        debugPrint('Player data is not a Map: ${playerValue.runtimeType}');
        return;
      }

      final Map<String, dynamic> playerData =
          _convertToStringDynamicMap(playerValue);
      final dynamic gameStateValue = playerData['gameState'];

      if (gameStateValue is! Map) {
        debugPrint(
            'GameState data is not a Map: ${gameStateValue.runtimeType}');
        return;
      }

      final gameState =
          GameState.fromJson(_convertToStringDynamicMap(gameStateValue));

      if (gameState.markNumber(number)) {
        await playerRef.update({'gameState': gameState.toJson()});

        await roomRef.update({
          'currentTurn': (playerIndex + 1) % 2,
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

      // Remove player
      await roomRef.child('players').child(playerIndex.toString()).remove();

      // Check remaining players
      final playersSnapshot = await roomRef.child('players').get();
      if (!playersSnapshot.exists) {
        // No players left, remove the room
        await roomRef.remove();
        return;
      }

      final dynamic playersValue = playersSnapshot.value;
      bool shouldRemoveRoom = false;

      if (playersValue == null) {
        shouldRemoveRoom = true;
      } else if (playersValue is Map && playersValue.isEmpty) {
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
        // If no players left, remove the room
        await roomRef.remove();
      } else {
        // Otherwise, mark the room as ended
        await roomRef.update({'status': 'ended'});
      }
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }
}
