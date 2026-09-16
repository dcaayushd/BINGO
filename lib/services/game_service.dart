import 'dart:async';

import 'socket_service.dart';

class RoomJoin {
  const RoomJoin(
      {required this.roomId,
      required this.playerIndex,
      required this.playerToken});

  final String roomId;
  final int playerIndex;
  final String playerToken;
}

class GameService {
  GameService() {
    _socket.onRoomUpdate((update) => _updates.add(update));
    _socket.onRoomClosed((event) {
      _activeRoom = null;
      _closed.add(event);
    });
    _connectionSubscription =
        _socket.connections.listen((_) => unawaited(_resumeActiveRoom()));
  }

  final SocketService _socket = SocketService();
  final StreamController<Map<String, dynamic>> _updates =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _closed =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<void>? _connectionSubscription;
  RoomJoin? _activeRoom;

  Stream<Map<String, dynamic>> get roomUpdates => _updates.stream;
  Stream<Map<String, dynamic>> get roomClosed => _closed.stream;

  Future<RoomJoin> createRoom(String playerName) async {
    final response = await _socket
        .request('create_room', <String, dynamic>{'name': playerName});
    final join = _roomJoinFrom(response);
    _activeRoom = join;
    return join;
  }

  Future<RoomJoin> joinRoom(String roomId, String playerName) async {
    final response = await _socket.request('join_room', <String, dynamic>{
      'roomId': roomId.trim().toUpperCase(),
      'name': playerName,
    });
    final join = _roomJoinFrom(response);
    _activeRoom = join;
    return join;
  }

  Future<void> setReady(String roomId, bool ready) => _requestSuccess(
      'set_ready', <String, dynamic>{'roomId': roomId, 'ready': ready});

  Future<void> makeMove(String roomId, int number) => _requestSuccess(
      'make_move', <String, dynamic>{'roomId': roomId, 'number': number});

  Future<void> requestRematch(String roomId) =>
      _requestSuccess('request_rematch', <String, dynamic>{'roomId': roomId});

  Future<void> leaveRoom(String roomId) async {
    await _requestSuccess('leave_room', <String, dynamic>{'roomId': roomId});
    _activeRoom = null;
  }

  Future<void> subscribe(String roomId) =>
      _requestSuccess('subscribe_room', <String, dynamic>{'roomId': roomId});

  Future<void> _resumeActiveRoom() async {
    final activeRoom = _activeRoom;
    if (activeRoom == null) return;
    try {
      final response = await _socket.request('rejoin_room', <String, dynamic>{
        'roomId': activeRoom.roomId,
        'playerToken': activeRoom.playerToken,
      });
      if (response['success'] == true) return;
      _activeRoom = null;
      _closed.add(<String, dynamic>{
        'reason': response['error'] ?? 'The room is no longer available.'
      });
    } catch (_) {
      _activeRoom = null;
      _closed.add(<String, dynamic>{
        'reason': 'Could not restore the multiplayer room.'
      });
    }
  }

  Future<void> _requestSuccess(
      String event, Map<String, dynamic> payload) async {
    final response = await _socket.request(event, payload);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Request failed.');
    }
  }

  RoomJoin _roomJoinFrom(Map<String, dynamic> response) {
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Unable to join the room.');
    }
    final roomId = response['roomId']?.toString() ?? '';
    final playerIndex = response['playerIndex'];
    final playerToken = response['playerToken']?.toString() ?? '';
    if (roomId.isEmpty || playerIndex is! int || playerToken.isEmpty) {
      throw Exception('The server returned an invalid room.');
    }
    return RoomJoin(
        roomId: roomId, playerIndex: playerIndex, playerToken: playerToken);
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _updates.close();
    _closed.close();
    _socket.dispose();
  }
}
