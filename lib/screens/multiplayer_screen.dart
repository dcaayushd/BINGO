import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/game_server_config.dart';
import '../models/online_room.dart';
import '../models/player_profile.dart';
import '../services/audio_service.dart';
import '../services/game_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/bingo_board.dart';
import '../widgets/confetti_overlay.dart';

class MultiplayerScreen extends StatefulWidget {
  const MultiplayerScreen({super.key, required this.profile});

  final PlayerProfile profile;

  @override
  State<MultiplayerScreen> createState() => _MultiplayerScreenState();
}

class _MultiplayerScreenState extends State<MultiplayerScreen> {
  final _gameService = GameService();
  final _roomController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _roomSubscription;
  StreamSubscription<Map<String, dynamic>>? _roomClosedSubscription;
  late PlayerProfile _profile;
  OnlineRoom? _room;
  String? _roomId;
  int? _playerIndex;
  bool _loading = false;
  bool _movePending = false;
  bool _isLeaving = false;
  bool _resultDialogOpen = false;
  bool _closeQueued = false;
  bool _showConfetti = false;
  int? _presentedRound;
  int? _recordedRound;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _roomSubscription = _gameService.roomUpdates.listen(_onRoomUpdate);
    _roomClosedSubscription = _gameService.roomClosed.listen(_onRoomClosed);
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _roomClosedSubscription?.cancel();
    _roomController.dispose();
    _gameService.dispose();
    super.dispose();
  }

  void _onRoomUpdate(Map<String, dynamic> data) {
    final room = OnlineRoom.fromJson(data);
    if (_roomId == null || room.id != _roomId || !mounted) return;
    final wasMyTurn =
        _room?.isPlaying == true && _room?.currentTurn == _playerIndex;
    final wasPaused = _room?.isPaused == true;
    final roundStarted =
        room.isPlaying && !wasMyTurn && !wasPaused && _room?.isPlaying != true;
    final isMyTurn = room.isPlaying && room.currentTurn == _playerIndex;
    final isNewRoundResult = room.isFinished && _presentedRound != room.round;
    setState(() {
      _room = room;
      _movePending = false;
      _showConfetti = isNewRoundResult && room.winner == _playerIndex;
      if (!room.isFinished) _showConfetti = false;
    });
    if (roundStarted) unawaited(AudioService().playGameStart());
    if (isMyTurn && !wasMyTurn && !roundStarted) _notifyPlayerTurn();
    if (isNewRoundResult) {
      _presentedRound = room.round;
      unawaited(_showRoundResult(room));
    }
  }

  void _onRoomClosed(Map<String, dynamic> event) {
    if (!mounted || _isLeaving || _roomId == null) return;
    final isPlayerDeparture = event['type'] == 'player_left';
    final name = event['playerName']?.toString().trim();
    final eventReason = event['reason']?.toString().trim();
    final reason = eventReason?.isNotEmpty == true
        ? eventReason!
        : isPlayerDeparture && name?.isNotEmpty == true
            ? '$name left the game.'
            : 'The room was closed.';
    _isLeaving = true;
    unawaited(_exitAfterRoomClosed(
      reason,
      showBeforeLeaving: isPlayerDeparture,
    ));
  }

  Future<void> _exitAfterRoomClosed(
    String reason, {
    required bool showBeforeLeaving,
  }) async {
    if (_closeQueued) return;
    _closeQueued = true;
    // A room can close while its non-dismissible result dialog is open. Close
    // that route first, then pop this screen in the next event-loop turn.
    if (_resultDialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop(false);
      await Future<void>.delayed(Duration.zero);
    }
    if (mounted) showAppToast(context, reason);
    // Let the remaining player read a named departure before returning home.
    if (showBeforeLeaving) {
      await Future<void>.delayed(const Duration(milliseconds: 1800));
    }
    if (mounted) Navigator.of(context).pop(_profile);
  }

  Future<void> _createRoom() async {
    setState(() => _loading = true);
    RoomJoin? join;
    try {
      final createdRoom = await _gameService.createRoom(_profile.displayName);
      join = createdRoom;
      if (!mounted) return;
      setState(() {
        _roomId = createdRoom.roomId;
        _playerIndex = createdRoom.playerIndex;
      });
      await _gameService.subscribe(createdRoom.roomId);
      if (!mounted) return;
    } catch (error) {
      if (join != null) {
        unawaited(_gameService.leaveRoom(join.roomId));
        if (mounted) {
          setState(() {
            _roomId = null;
            _playerIndex = null;
          });
        }
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom() async {
    final roomId = _roomController.text.trim().toUpperCase();
    if (!RegExp(r'^[A-F0-9]{6}$').hasMatch(roomId)) {
      // The Join button is disabled until the code is complete. Keep this
      // guard for keyboard submission and programmatic calls without showing
      // a disruptive error banner.
      return;
    }
    setState(() => _loading = true);
    RoomJoin? join;
    try {
      final joinedRoom =
          await _gameService.joinRoom(roomId, _profile.displayName);
      join = joinedRoom;
      if (!mounted) return;
      setState(() {
        _roomId = joinedRoom.roomId;
        _playerIndex = joinedRoom.playerIndex;
      });
      await _gameService.subscribe(joinedRoom.roomId);
      if (!mounted) return;
      unawaited(AudioService().playNotification());
    } catch (error) {
      if (join != null) {
        unawaited(_gameService.leaveRoom(join.roomId));
        if (mounted) {
          setState(() {
            _roomId = null;
            _playerIndex = null;
          });
        }
      }
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleReady() async {
    final room = _room;
    final index = _playerIndex;
    if (room == null || index == null) return;
    final player = room.playerAt(index);
    if (player == null) return;
    setState(() => _loading = true);
    try {
      await _gameService.setReady(room.id, !player.isReady);
      unawaited(AudioService().playButtonClick());
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _makeMove(int number) async {
    final room = _room;
    if (room == null ||
        _movePending ||
        room.currentTurn != _playerIndex ||
        !room.isPlaying) {
      return;
    }
    setState(() => _movePending = true);
    unawaited(AudioService().playCellSelect());
    try {
      await _gameService.makeMove(room.id, number);
    } catch (error) {
      if (mounted) setState(() => _movePending = false);
      _showMessage(_friendlyError(error));
    }
  }

  Future<void> _showRoundResult(OnlineRoom room) async {
    final index = _playerIndex;
    if (index == null || !mounted) return;
    final won = room.winner == index;
    if (_recordedRound != room.round) {
      _recordedRound = room.round;
      _profile = await ProfileService.instance
          .recordMultiplayerResult(_profile, won: won);
    }
    if (!mounted || _isLeaving) return;
    unawaited(won
        ? AudioService().playWinSound()
        : AudioService().playNotification());
    final opponent = room.playerAt(index == 0 ? 1 : 0);
    final myScore = room.playerAt(index)?.score ?? 0;
    final opponentScore = opponent?.score ?? 0;
    bool? requestRematch;
    _resultDialogOpen = true;
    try {
      requestRematch = await showAppChoiceDialog<bool>(
        context,
        barrierDismissible: false,
        title: Text(won
            ? 'You won the round'
            : '${opponent?.name ?? 'Opponent'} won the round'),
        content: Text('$myScore–$opponentScore match score'),
        actions: const [
          AppDialogAction(label: 'Leave', value: false),
          AppDialogAction(label: 'Rematch', value: true, isDefault: true),
        ],
      );
    } finally {
      _resultDialogOpen = false;
    }
    if (!mounted || _isLeaving) return;
    if (requestRematch == true) {
      try {
        await _gameService.requestRematch(room.id);
      } catch (error) {
        _showMessage(_friendlyError(error));
      }
    } else {
      await _leaveGame();
    }
  }

  Future<void> _copyRoomCode() async {
    final roomId = _roomId;
    if (roomId == null) return;
    await Clipboard.setData(ClipboardData(text: roomId));
    if (mounted) _showMessage('Room code copied');
  }

  Future<void> _leaveGame() async {
    if (_isLeaving) return;
    _isLeaving = true;
    final roomId = _roomId;
    if (roomId != null) {
      try {
        await _gameService.leaveRoom(roomId);
      } catch (_) {
        // The remote connection may already be gone; close the local screen.
      }
    }
    if (mounted) Navigator.pop(context, _profile);
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (!didPop) unawaited(_leaveGame());
  }

  String _friendlyError(Object error) => error is GameServerUnavailableException
      ? error.message
      : error
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('SocketException: ', '');

  void _notifyPlayerTurn() {
    HapticFeedback.mediumImpact();
    unawaited(AudioService().playTurnSound());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showAppToast(context, message);
  }

  bool get _hasCompleteRoomCode => RegExp(r'^[A-F0-9]{6}$')
      .hasMatch(_roomController.text.trim().toUpperCase());

  void _onRoomCodeChanged(String _) {
    // Rebuild only to update the enabled state of the Join control. The field
    // itself stays focused and does not show a validation error while typing.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final view = _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : room == null
            ? _buildRoomSetup()
            : room.isWaiting
                ? _buildLobby(room)
                : _buildGame(room);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor:
            AppColors.screenBottomColorFor(Theme.of(context).brightness),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Play with Friends',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                    gradient: AppColors.screenGradientFor(
                        Theme.of(context).brightness)),
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0, .02),
                                      end: Offset.zero)
                                  .animate(animation),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(
                                '${room?.id}-${room?.status}-${_loading ? 'loading' : 'view'}'),
                            child: view,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(child: ConfettiOverlay(active: _showConfetti)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSetup() {
    if (!GameServerConfig.isConfigured) {
      return _buildMultiplayerUnavailable();
    }
    final canJoin = _hasCompleteRoomCode;
    final mutedText = Theme.of(context).colorScheme.onSurfaceVariant;
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Playing as ${_profile.displayName}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 32),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create a room',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                    'Share the room code, then both players confirm they are ready.'),
                const SizedBox(height: 20),
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: _createRoom,
                    icon: const Icon(Icons.add),
                    label: const Text('Create room'),
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Join a room',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: _roomController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Fa-f0-9]')),
                  ],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: InputDecoration(
                    labelText: 'Room code',
                    hintText: 'ABC123',
                    helperText: 'Six-character code shared by your friend',
                    helperStyle: TextStyle(color: mutedText),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onRoomCodeChanged,
                  onSubmitted: canJoin ? (_) => _joinRoom() : null,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  child: FilledButton.tonalIcon(
                    onPressed: canJoin ? _joinRoom : null,
                    icon: const Icon(Icons.login),
                    label: const Text('Join room'),
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Server ready — create a private room or join a friend.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: .72), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplayerUnavailable() => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Playing as ${_profile.displayName}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 32),
            _Panel(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.cloud_off_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Multiplayer is not available yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This copy of Bingo was installed without a game server.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ask the app host to enable multiplayer, then reopen the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildLobby(OnlineRoom room) {
    final index = _playerIndex!;
    final player = room.playerAt(index)!;
    final opponent = room.playerAt(index == 0 ? 1 : 0);
    final opponentIsReady = opponent?.isReady == true;
    final hasOpponent = opponent != null;
    final readyMessage = !hasOpponent
        ? 'Share the code above so a friend can join.'
        : player.isReady && opponentIsReady
            ? 'Both players are ready. Starting the match…'
            : player.isReady
                ? 'You are ready. Waiting for ${opponent.name}.'
                : opponentIsReady
                    ? '${opponent.name} is ready. Confirm when you are set.'
                    : 'Confirm when you are ready to start.';
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Private match',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          const Text(
            'Share this code with your friend',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 14),
          _RoomCodeCard(roomId: room.id, onCopy: _copyRoomCode),
          const SizedBox(height: 22),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.groups_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Match lobby',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.grid_view_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Classic Bingo · first to 5 lines'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _PlayerStatus(
                    name: player.name,
                    ready: player.isReady,
                    connected: player.connected,
                    isYou: true),
                const Divider(height: 24),
                if (opponent == null)
                  const Text('Waiting for an opponent…')
                else
                  _PlayerStatus(
                      name: opponent.name,
                      ready: opponent.isReady,
                      connected: opponent.connected),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 68,
            child: FilledButton.icon(
              onPressed: hasOpponent ? _toggleReady : null,
              icon: Icon(player.isReady
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_fill_rounded),
              label: Text(player.isReady
                  ? 'Ready — tap to cancel'
                  : 'I’m ready to play'),
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            readyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .80)),
          ),
          const SizedBox(height: 32),
          _buildLeaveGameButton(),
        ],
      ),
    );
  }

  Widget _buildGame(OnlineRoom room) {
    final index = _playerIndex!;
    final player = room.playerAt(index)!;
    final opponent = room.playerAt(index == 0 ? 1 : 0);
    final canMove =
        room.isPlaying && room.currentTurn == index && !_movePending;
    final status = room.isPaused
        ? 'Connection paused — waiting for ${opponent?.name ?? 'opponent'} to return'
        : room.isFinished
            ? player.rematchRequested
                ? 'Rematch requested — waiting for ${opponent?.name ?? 'opponent'}'
                : 'Round complete'
            : canMove
                ? 'Your turn'
                : "${opponent?.name ?? 'Opponent'}'s turn";
    final statusColor = room.isPaused || room.isFinished
        ? Colors.white70
        : canMove
            ? Colors.green
            : Colors.red;
    return SingleChildScrollView(
      child: Column(
        children: [
          _MatchScore(room: room, playerIndex: index),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(status,
                key: ValueKey(status),
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          BingoBoard(
              gameState: player.board,
              playerIndex: index,
              enabled: canMove,
              showOpponentColors: true,
              onNumberSelected: _makeMove),
          const SizedBox(height: 14),
          Text('Round ${room.round}',
              style: TextStyle(color: Colors.white.withValues(alpha: .74))),
          const SizedBox(height: 40),
          _buildLeaveGameButton(),
        ],
      ),
    );
  }

  Widget _buildLeaveGameButton() => Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          onPressed: _isLeaving ? null : _leaveGame,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.exit_to_app),
          label: const Text(
            'Leave game',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16)),
        child: child,
      );
}

class _PlayerStatus extends StatelessWidget {
  const _PlayerStatus(
      {required this.name,
      required this.ready,
      required this.connected,
      this.isYou = false});

  final String name;
  final bool ready;
  final bool connected;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = ready
        ? 'Ready'
        : connected
            ? 'Not ready'
            : 'Reconnecting';
    final statusColor = ready
        ? Colors.green.shade700
        : connected
            ? colorScheme.onSurfaceVariant
            : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isYou
            ? colorScheme.primaryContainer.withValues(alpha: .28)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: statusColor.withValues(alpha: .14),
            child: Icon(
              connected ? Icons.person_rounded : Icons.person_off_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  isYou
                      ? 'You'
                      : connected
                          ? 'Connected'
                          : 'Reconnecting',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  const _RoomCodeCard({required this.roomId, required this.onCopy});

  final String roomId;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Copy room code $roomId',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                border: Border.all(color: Colors.white.withValues(alpha: .24)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      roomId,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.copy_outlined, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _MatchScore extends StatelessWidget {
  const _MatchScore({required this.room, required this.playerIndex});

  final OnlineRoom room;
  final int playerIndex;

  @override
  Widget build(BuildContext context) {
    final player = room.playerAt(playerIndex)!;
    final opponent = room.playerAt(playerIndex == 0 ? 1 : 0);
    final opponentName = opponent?.name ?? 'Opponent';
    final opponentScore = opponent?.score ?? 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MatchPerson(name: player.name, score: player.score, isYou: true),
            const Text('VS',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w700)),
            _MatchPerson(name: opponentName, score: opponentScore),
          ],
        ),
      ],
    );
  }
}

class _MatchPerson extends StatelessWidget {
  const _MatchPerson({
    required this.name,
    required this.score,
    this.isYou = false,
  });

  final String name;
  final int score;
  final bool isYou;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isYou ? Icons.person_rounded : Icons.person_outline,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Text('$score',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
        ],
      );
}
