import 'game_state.dart';

class OnlinePlayer {
  const OnlinePlayer({
    required this.name,
    required this.board,
    required this.lineCount,
    required this.score,
    required this.isReady,
    required this.rematchRequested,
    required this.connected,
  });

  final String name;
  final GameState board;
  final int lineCount;
  final int score;
  final bool isReady;
  final bool rematchRequested;
  final bool connected;
}

class OnlineRoom {
  const OnlineRoom({
    required this.id,
    required this.status,
    required this.currentTurn,
    required this.round,
    required this.winner,
    required this.players,
  });

  factory OnlineRoom.fromJson(Map<String, dynamic> json) {
    final selected = _intList(json['selectedNumbers']);
    final owners = _owners(json['playerSelections']);
    final rawPlayers = json['players'] as List? ?? const <dynamic>[];
    final players = List<OnlinePlayer?>.generate(2, (index) {
      if (index >= rawPlayers.length || rawPlayers[index] is! Map) return null;
      final data = _map(rawPlayers[index]);
      final boardData = data['board'];
      if (boardData is! List) return null;
      try {
        final board = GameState(
          board: boardData
              .whereType<List>()
              .map((row) =>
                  row.map((item) => int.parse(item.toString())).toList())
              .toList(),
        )..applySelections(selected, owners);
        return OnlinePlayer(
          name: data['name']?.toString() ?? 'Player',
          board: board,
          lineCount: _int(data['lineCount']),
          score: _int(data['score']),
          isReady: data['isReady'] == true,
          rematchRequested: data['rematchRequested'] == true,
          connected: data['connected'] != false,
        );
      } on FormatException {
        return null;
      } on ArgumentError {
        return null;
      }
    });
    return OnlineRoom(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'waiting',
      currentTurn: _int(json['currentTurn']),
      round: _int(json['round'], fallback: 1),
      winner: json['winner'] is int ? json['winner'] as int : null,
      players: players,
    );
  }

  final String id;
  final String status;
  final int currentTurn;
  final int round;
  final int? winner;
  final List<OnlinePlayer?> players;

  OnlinePlayer? playerAt(int index) =>
      index >= 0 && index < players.length ? players[index] : null;
  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isPaused => status == 'paused';
  bool get isFinished => status == 'finished';

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<int> _intList(dynamic value) =>
      (value as List? ?? const <dynamic>[])
          .map((item) => int.tryParse(item.toString()))
          .whereType<int>()
          .toList();

  static Map<int, int> _owners(dynamic value) {
    final values = <int, int>{};
    if (value is Map) {
      value.forEach((key, entry) {
        final number = int.tryParse(key.toString());
        final owner = int.tryParse(entry.toString());
        if (number != null && owner != null) values[number] = owner;
      });
    }
    return values;
  }

  static int _int(dynamic value, {int fallback = 0}) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
}
