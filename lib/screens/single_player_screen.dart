import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ai_difficulty.dart';
import '../models/game_state.dart';
import '../models/player_profile.dart';
import '../services/audio_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/bingo_board.dart';
import '../widgets/confetti_overlay.dart';

class SinglePlayerScreen extends StatefulWidget {
  const SinglePlayerScreen(
      {super.key, required this.profile, required this.difficulty});

  final PlayerProfile profile;
  final AiDifficulty difficulty;

  @override
  State<SinglePlayerScreen> createState() => _SinglePlayerScreenState();
}

class _SinglePlayerScreenState extends State<SinglePlayerScreen> {
  final _random = Random();
  late PlayerProfile _profile;
  late GameState _playerBoard;
  late GameState _aiBoard;
  final Map<int, int> _selectionOwners = <int, int>{};
  bool _isPlayerTurn = true;
  bool _playerStartsNextRound = true;
  bool _gameOver = false;
  bool _resultRecorded = false;
  bool _showConfetti = false;
  int _playerScore = 0;
  int _aiScore = 0;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _startRound(playSound: false);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(AudioService().playGameStart()),
    );
  }

  void _startRound({bool playSound = true}) {
    _playerBoard = GameState.initial(random: _random);
    _aiBoard = GameState.initial(random: _random);
    _selectionOwners.clear();
    _isPlayerTurn = _playerStartsNextRound;
    _gameOver = false;
    _resultRecorded = false;
    _showConfetti = false;
    if (playSound) unawaited(AudioService().playGameStart());
    if (!_isPlayerTurn) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_scheduleAiMove()));
    }
  }

  void _onPlayerMove(int number) {
    if (!_isPlayerTurn || _gameOver || _selectionOwners.containsKey(number)) {
      return;
    }
    unawaited(AudioService().playCellSelect());
    setState(() {
      _applyMove(number, owner: 0);
      if (_checkForWinner(lastMover: 0)) return;
      _isPlayerTurn = false;
    });
    unawaited(_scheduleAiMove());
  }

  Future<void> _scheduleAiMove() async {
    await Future<void>.delayed(Duration(
        milliseconds: widget.difficulty == AiDifficulty.hard ? 280 : 380));
    if (!mounted || _gameOver || _isPlayerTurn) return;
    final candidates = List<int>.generate(25, (index) => index + 1)
        .where((number) => !_selectionOwners.containsKey(number))
        .toList();
    if (candidates.isEmpty) return;
    final choice = _chooseAiMove(candidates);
    if (!mounted) return;
    var notifyPlayer = false;
    setState(() {
      _applyMove(choice, owner: 1);
      if (!_checkForWinner(lastMover: 1)) {
        _isPlayerTurn = true;
        notifyPlayer = true;
      }
    });
    if (notifyPlayer) _notifyPlayerTurn();
  }

  int _chooseAiMove(List<int> candidates) {
    switch (widget.difficulty) {
      case AiDifficulty.easy:
        // Easy mostly explores, with enough tactical awareness to feel like
        // an opponent rather than a random number generator.
        if (_random.nextDouble() < .82) {
          return candidates[_random.nextInt(candidates.length)];
        }
        return _pickFromTop(candidates, _mediumScore, 5);
      case AiDifficulty.medium:
        return _pickFromTop(candidates, _mediumScore, 2);
      case AiDifficulty.hard:
        return _chooseHardMove(candidates);
    }
  }

  int _mediumScore(int number) {
    final ownFinish = _aiBoard.completedLineDeltaFor(number);
    final playerFinish = _playerBoard.completedLineDeltaFor(number);
    return ownFinish * 7000 +
        _aiBoard.tacticalValueFor(number) * 12 -
        playerFinish * 3400 -
        _playerBoard.tacticalValueFor(number) * 4;
  }

  int _hardScore(int number) {
    final ownFinish = _aiBoard.completedLineDeltaFor(number);
    final playerFinish = _playerBoard.completedLineDeltaFor(number);
    return ownFinish * 30000 +
        _aiBoard.tacticalValueFor(number) * 36 -
        playerFinish * 22000 -
        _playerBoard.tacticalValueFor(number) * 22;
  }

  int _chooseHardMove(List<int> candidates) {
    // Simulate the best immediate moves and one shared selection ahead. This
    // keeps hard mode fast on-device while making it actively deny a strong
    // player reply.
    final shortlist = [...candidates]
      ..sort((left, right) => _hardScore(right).compareTo(_hardScore(left)));
    var bestNumber = shortlist.first;
    var bestScore = -1 << 60;
    for (final number in shortlist.take(min(8, shortlist.length))) {
      final playerAfter = _playerBoard.copy()
        ..applySelection(number, selectedBy: 1);
      final aiAfter = _aiBoard.copy()..applySelection(number, selectedBy: 1);
      var opponentBestReply = 0;
      for (final reply in candidates) {
        if (reply == number) continue;
        final replyScore = playerAfter.completedLineDeltaFor(reply) * 12000 +
            playerAfter.tacticalValueFor(reply) * 22 -
            aiAfter.completedLineDeltaFor(reply) * 7500 -
            aiAfter.tacticalValueFor(reply) * 8;
        opponentBestReply = max(opponentBestReply, replyScore);
      }
      final score = _hardScore(number) - opponentBestReply ~/ 2;
      if (score > bestScore) {
        bestScore = score;
        bestNumber = number;
      }
    }
    return bestNumber;
  }

  int _pickFromTop(
      List<int> candidates, int Function(int) score, int topCount) {
    final scored = [...candidates]
      ..sort((left, right) => score(right).compareTo(score(left)));
    return scored[_random.nextInt(min(topCount, scored.length))];
  }

  void _applyMove(int number, {required int owner}) {
    _selectionOwners[number] = owner;
    _playerBoard.applySelection(number, selectedBy: owner);
    _aiBoard.applySelection(number, selectedBy: owner);
  }

  void _notifyPlayerTurn() {
    HapticFeedback.mediumImpact();
    unawaited(AudioService().playTurnSound());
  }

  bool _checkForWinner({required int lastMover}) {
    final playerReachedTarget =
        _playerBoard.lineCount >= AppColors.classicTargetLines;
    final aiReachedTarget = _aiBoard.lineCount >= AppColors.classicTargetLines;
    if (!playerReachedTarget && !aiReachedTarget) return false;
    _gameOver = true;
    final playerWon =
        playerReachedTarget && (!aiReachedTarget || lastMover == 0);
    _showConfetti = playerWon;
    if (playerWon) {
      _playerScore += 1;
    } else {
      _aiScore += 1;
    }
    _playerStartsNextRound = !playerWon;
    unawaited(_showResult(playerWon));
    return true;
  }

  Future<void> _showResult(bool playerWon) async {
    if (_resultRecorded || !mounted) return;
    _resultRecorded = true;
    _profile = await ProfileService.instance.recordAiResult(
      _profile,
      won: playerWon,
    );
    if (!mounted) return;
    unawaited(playerWon
        ? AudioService().playWinSound()
        : AudioService().playNotification());
    final playAgain = await showAppChoiceDialog<bool>(
      context,
      barrierDismissible: false,
      title: Text(playerWon
          ? 'You won the round'
          : '${widget.difficulty.label} AI takes it'),
      content: Text('$_playerScore–$_aiScore match score'),
      actions: const [
        AppDialogAction(label: 'Home', value: false),
        AppDialogAction(label: 'Rematch', value: true, isDefault: true),
      ],
    );
    if (!mounted) return;
    if (playAgain == true) {
      setState(_startRound);
    } else {
      Navigator.pop(context, _profile);
    }
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (!didPop) Navigator.pop(context, _profile);
  }

  @override
  Widget build(BuildContext context) {
    final foreground = Colors.white;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor:
            AppColors.screenBottomColorFor(Theme.of(context).brightness),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: foreground,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text('${widget.difficulty.label} AI',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                    gradient: AppColors.screenGradientFor(
                        Theme.of(context).brightness)),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          children: [
                            _MatchScore(
                                playerName: _profile.displayName,
                                playerScore: _playerScore,
                                aiScore: _aiScore),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: Text(
                                _isPlayerTurn ? 'Your turn' : 'AI turn',
                                key: ValueKey(_isPlayerTurn),
                                style: TextStyle(
                                  color:
                                      _isPlayerTurn ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            BingoBoard(
                              gameState: _playerBoard,
                              playerIndex: 0,
                              enabled: _isPlayerTurn && !_gameOver,
                              onNumberSelected: _onPlayerMove,
                              showOpponentColors: true,
                            ),
                            const SizedBox(height: 48),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context, _profile),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: foreground),
                              icon: const Icon(Icons.exit_to_app),
                              label: const Text(
                                'Leave game',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ),
                          ],
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
}

class _MatchScore extends StatelessWidget {
  const _MatchScore(
      {required this.playerName,
      required this.playerScore,
      required this.aiScore});

  final String playerName;
  final int playerScore;
  final int aiScore;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Score(
                  name: playerName,
                  score: playerScore,
                  icon: Icons.person_rounded),
              const Text('VS',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w700)),
              _Score(
                  name: 'AI', score: aiScore, icon: Icons.smart_toy_outlined),
            ],
          ),
        ],
      );
}

class _Score extends StatelessWidget {
  const _Score({
    required this.name,
    required this.score,
    required this.icon,
  });

  final String name;
  final int score;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Column(
            // mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(name,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      );
}
