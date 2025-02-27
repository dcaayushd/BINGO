import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../models/game_state.dart';
import '../services/game_service.dart';
import '../widgets/bingo_board.dart';

class MultiplayerScreen extends StatefulWidget {
  const MultiplayerScreen({super.key});

  @override
  MultiplayerScreenState createState() => MultiplayerScreenState();
}

class MultiplayerScreenState extends State<MultiplayerScreen> {
  final GameService gameService = GameService();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String roomId = "";
  String playerName = "";
  TextEditingController nameController = TextEditingController();
  TextEditingController roomController = TextEditingController();
  int playerIndex = -1;
  StreamSubscription? _roomSubscription;
  late ConfettiController _confettiController;
  GameState? gameState;
  String? opponentName;
  bool isMyTurn = false;
  bool gameStarted = false;
  bool isLoading = false;
  bool isPlayerReady = false;
  bool isOpponentReady = false;
  bool opponentJoined = false;
  String notificationMessage = "";

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: Duration(seconds: 3));
    _loadName();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _confettiController.dispose();
    nameController.dispose();
    roomController.dispose();
    if (roomId.isNotEmpty) {
      gameService.leaveRoom(roomId, playerIndex);
    }
    super.dispose();
  }

  Future<void> _loadName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        playerName = prefs.getString('playerName') ?? "";
        nameController.text = playerName;
      });
    } catch (e) {
      print('Error loading name: $e');
    }
  }

  Future<void> _saveName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('playerName', name);
    } catch (e) {
      print('Error saving name: $e');
    }
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
        // For lists that might be in player selections or game state
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
        } else if (stringKey == 'board') {
          // Handle board as a 2D array
          List<List<dynamic>> boardList = [];
          for (int i = 0; i < value.length; i++) {
            if (value[i] is List) {
              boardList.add(List<dynamic>.from(value[i].where((cell) => cell != null)));
            }
          }
          result[stringKey] = boardList;
        } else {
          // Default handling for other list types
          result[stringKey] = value.map((item) {
            if (item is Map) {
              return _safelyConvertData(item);
            }
            return item;
          }).toList();
        }
      } else {
        // For non-collection types, just assign the value
        result[stringKey] = value;
      }
    });

    return result;
  }

  return {};
}

  void _handleRoomUpdate(Map<Object?, Object?> rawRoomData) {
  try {
    if (rawRoomData.isEmpty) {
      print('Room data is empty');
      return;
    }

    print('Raw room data type: ${rawRoomData.runtimeType}');

    final roomData = _safelyConvertData(rawRoomData);
    print('Processed room data: $roomData');

    final status = roomData['status'] as String? ?? 'waiting';
    final currentTurn = roomData['currentTurn'] as int? ?? 0;
    final lastMove = roomData['lastMove'] as int?;  // Track the last move

    final playersData = roomData['players'];
    if (playersData == null) {
      print('No players data found');
      return;
    }

    Map<String, dynamic> players = {};
    
    if (playersData is Map) {
      players = _safelyConvertData(playersData);
    } else if (playersData is List) {
      // Convert list to map
      for (int i = 0; i < playersData.length; i++) {
        if (playersData[i] != null) {
          players[i.toString()] = _safelyConvertData(playersData[i]);
        }
      }
    }

    if (playerIndex < 0 || !players.containsKey(playerIndex.toString())) {
      print('Player index $playerIndex not found in room');
      return;
    }

    setState(() {
      final playerData = players[playerIndex.toString()];
      GameState? updatedGameState;
      
      if (playerData != null && playerData is Map) {
        final gameStateData = playerData['gameState'];
        if (gameStateData != null && gameStateData is Map) {
          updatedGameState = GameState.fromJson(_safelyConvertData(gameStateData));
        }
        isPlayerReady = playerData['isReady'] == true;
      }

      final opponentIndex = playerIndex == 0 ? '1' : '0';
      final wasOpponentJoined = opponentJoined;
      opponentJoined = players.containsKey(opponentIndex);

      if (opponentJoined) {
        final opponentData = players[opponentIndex];
        if (opponentData != null && opponentData is Map) {
          final newOpponentName = opponentData['name'] as String? ?? "Opponent";

          if (!wasOpponentJoined) {
            notificationMessage = "$newOpponentName has joined the room!";
            Future.delayed(Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  notificationMessage = "";
                });
              }
            });
          }

          opponentName = newOpponentName;
          isOpponentReady = opponentData['isReady'] == true;
        }
      }

      isMyTurn = currentTurn == playerIndex;
      gameStarted = (status == 'playing' && opponentJoined);
      
      // Only update the game state if we actually have a valid update
      if (updatedGameState != null) {
        gameState = updatedGameState;
      }

      if (isPlayerReady && isOpponentReady && opponentJoined && status == 'waiting') {
        print('Both players ready - updating game status to playing');
        _database.child('rooms').child(roomId).update({
          'status': 'playing',
          'currentTurn': 0,
        });
      }

      if (gameState?.bingoStatus == "BINGO") {
        _showWinDialog("You won!", isPlayerWin: true);
      }
    });
  } catch (e) {
    print('Error handling room update: $e');
  }
}

  void _startListeningToRoom() {
    _roomSubscription = gameService.getRoomStream(roomId).listen((roomData) {
      if (roomData.isNotEmpty) {
        _handleRoomUpdate(roomData.cast<Object?, Object?>());
      }
    });
  }

  Future<void> _createRoom() async {
    setState(() => isLoading = true);
    try {
      final newRoomId = await gameService.createRoom(playerName);
      setState(() {
        roomId = newRoomId;
        playerIndex = 0; // First player is always index 0
        _startListeningToRoom();
      });
    } catch (e) {
      _showErrorSnackBar('Error creating room');
      print('Error creating room: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _joinRoom(String roomId) async {
    setState(() => isLoading = true);
    try {
      final success = await gameService.joinRoom(roomId.trim(), playerName);
      if (success) {
        setState(() {
          this.roomId = roomId.trim();
          playerIndex = 1; // Second player is always index 1
          _startListeningToRoom();
        });
      } else {
        _showErrorSnackBar('Invalid Room ID or Room Full');
      }
    } catch (e) {
      _showErrorSnackBar('Error joining room');
      print('Error joining room: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleReadyStatus() async {
    if (roomId.isEmpty || playerIndex < 0) return;

    try {
      final roomRef = _database.child('rooms').child(roomId);
      final playerRef = roomRef.child('players').child(playerIndex.toString());

      setState(() {
        isPlayerReady = !isPlayerReady;
      });

      await playerRef.update({
        'isReady': isPlayerReady,
      });

      if (isPlayerReady && isOpponentReady && opponentJoined) {
        print('Setting game status to playing after both ready');
        await roomRef.update({
          'status': 'playing',
          'currentTurn': 0,
        });
      }
    } catch (e) {
      print('Error toggling ready status: $e');
      _showErrorSnackBar('Error updating ready status');
      setState(() {
        isPlayerReady = !isPlayerReady;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
      ),
    );
  }

  void _restartGame() {
    setState(() {
      if (roomId.isNotEmpty) {
        gameService.leaveRoom(roomId, playerIndex);
      }
      roomId = "";
      playerIndex = -1;
      gameState = null;
      opponentName = null;
      isMyTurn = false;
      gameStarted = false;
      isPlayerReady = false;
      isOpponentReady = false;
      opponentJoined = false;
      notificationMessage = "";
      _roomSubscription?.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    print('Build: gameStarted=$gameStarted, isReady=$isPlayerReady, opponent ready=$isOpponentReady');

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(156, 39, 176, 0.7),
              Color.fromRGBO(123, 31, 162, 0.9),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  if (isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  else if (playerName.isEmpty)
                    _buildNameInput()
                  else if (roomId.isEmpty)
                    _buildRoomSelection()
                  else if (!gameStarted)
                    _buildWaitingRoom()
                  else
                    _buildGameScreen(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameInput() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            "Enter Your Name",
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: "Your Name",
              hintStyle: TextStyle(color: Colors.white70),
            ),
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 20),
          _buildButton(
            "Continue",
            () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  playerName = nameController.text.trim();
                  _saveName(playerName);
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            "Welcome, $playerName!",
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          TextField(
            controller: roomController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: "Enter Room ID",
              hintStyle: TextStyle(color: Colors.white70),
            ),
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 20),
          _buildButton(
            "Join Room",
            () => _joinRoom(roomController.text),
          ),
          SizedBox(height: 10),
          _buildButton(
            "Create Room",
            _createRoom,
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingRoom() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Room ID: $roomId",
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),

          if (!opponentJoined)
            Text(
              "Waiting for opponent...",
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),

          if (notificationMessage.isNotEmpty)
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                notificationMessage,
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (opponentJoined && opponentName != null)
            Text(
              "Opponent: $opponentName",
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),

          SizedBox(height: 20),
          _buildButton(
            isPlayerReady ? "Not Ready" : "I'm Ready",
            _toggleReadyStatus,
          ),
          SizedBox(height: 10),
          _buildButton("Leave Room", _restartGame),

          if (opponentJoined && isOpponentReady)
            Container(
              margin: EdgeInsets.only(top: 15),
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Opponent is ready!",
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (isPlayerReady && isOpponentReady && opponentJoined)
            Padding(
              padding: EdgeInsets.only(top: 15),
              child: Text(
                "Game will start soon...",
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Room ID: $roomId",
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
        ),
        SizedBox(height: 10),
        Text(
          isMyTurn ? "Your Turn" : "$opponentName's Turn",
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 20),

        if (gameState != null)
          Padding(
            padding: EdgeInsets.all(16),
            child: BingoBoard(
              gameState: gameState!,
              onNumberSelected: (number) {
                if (isMyTurn) {
                  gameService.makeMove(roomId, playerIndex, number);
                }
              },
              onRestart: _restartGame,
              showOpponentColors: true, // Make sure to show opponent colors
            ),
          ),

        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: [Colors.green, Colors.yellow, Colors.pink, Colors.purple],
        ),
      ],
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontFamily: 'Poppins',
          color: Color.fromRGBO(123, 31, 162, 1),
        ),
      ),
    );
  }

  void _showWinDialog(String message, {required bool isPlayerWin}) {
    if (isPlayerWin) _confettiController.play();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(156, 39, 176, 0.7),
                Color.fromRGBO(123, 31, 162, 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Game Over",
                style: TextStyle(
                  fontSize: 28,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _restartGame();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "New Game",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(123, 31, 162, 1),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Exit",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color.fromRGBO(123, 31, 162, 1),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}