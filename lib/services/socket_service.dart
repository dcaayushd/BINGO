import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/game_server_config.dart';

/// A screen-owned socket. GameService adds the game-specific recovery logic.
class SocketService {
  SocketService() {
    if (!GameServerConfig.isConfigured) return;
    final socket = io.io(
      GameServerConfig.endpoint,
      <String, dynamic>{
        'transports': <String>['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 6,
        'reconnectionDelay': 800,
        'reconnectionDelayMax': 4000,
      },
    );
    _socket = socket;
    socket.on('connect', (_) => _connections.add(null));
  }

  io.Socket? _socket;
  final StreamController<void> _connections =
      StreamController<void>.broadcast();
  Completer<void>? _connectionCompleter;

  Stream<void> get connections => _connections.stream;

  Future<void> connect() {
    final socket = _socket;
    if (socket == null) {
      return Future<void>.error(
          GameServerUnavailableException(GameServerConfig.setupHint));
    }
    if (socket.connected) return Future<void>.value();
    if (_connectionCompleter != null) return _connectionCompleter!.future;
    final completer = Completer<void>();
    _connectionCompleter = completer;
    socket.once('connect', (_) {
      if (!completer.isCompleted) completer.complete();
      _connectionCompleter = null;
    });
    socket.once('connect_error', (error) {
      if (!completer.isCompleted) {
        completer.completeError(const GameServerUnavailableException(
            'Could not reach the multiplayer server. Check your connection and try again.'));
      }
      _connectionCompleter = null;
    });
    socket.connect();
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _connectionCompleter = null;
        throw const GameServerUnavailableException(
            'Could not reach the multiplayer server. Check your connection and try again.');
      },
    );
  }

  Future<Map<String, dynamic>> request(
      String event, Map<String, dynamic> payload) async {
    await connect();
    final completer = Completer<Map<String, dynamic>>();
    void listener(dynamic response) {
      if (response is Map) {
        completer.complete(Map<String, dynamic>.from(response));
      } else {
        completer.complete(<String, dynamic>{
          'success': false,
          'error': 'Unexpected server response.'
        });
      }
    }

    final socket = _socket;
    if (socket == null) {
      return <String, dynamic>{
        'success': false,
        'error': GameServerConfig.setupHint,
      };
    }
    socket.once('${event}_response', listener);
    socket.emit(event, payload);
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        socket.off('${event}_response', listener);
        return <String, dynamic>{
          'success': false,
          'error': 'The server did not respond in time.'
        };
      },
    );
  }

  void onRoomUpdate(void Function(Map<String, dynamic>) listener) {
    _socket?.on('room_update', (data) {
      if (data is Map) listener(Map<String, dynamic>.from(data));
    });
  }

  void onRoomClosed(void Function(Map<String, dynamic>) listener) {
    _socket?.on('room_closed', (data) {
      listener(
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
    });
  }

  void dispose() {
    _connections.close();
    _socket?.dispose();
  }
}
