const assert = require('node:assert/strict');
const test = require('node:test');

const {
  expiredDisconnectedPlayer,
  playerLeftEvent,
} = require('../room_lifecycle');

test('a departure event identifies the player who intentionally left', () => {
  assert.deepEqual(playerLeftEvent({ name: '  Alex  Kim ' }, 1), {
    type: 'player_left',
    reason: 'Alex Kim left the game.',
    playerName: 'Alex Kim',
    playerIndex: 1,
  });
});

test('a temporary disconnect remains recoverable during the grace period', () => {
  const disconnectedPlayer = {
    name: 'Alex',
    connected: false,
    disconnectedAt: 1_000,
  };
  const room = { players: [disconnectedPlayer, { connected: true }] };

  assert.equal(expiredDisconnectedPlayer(room, 2_999, 2_000), null);
  assert.equal(expiredDisconnectedPlayer(room, 3_000, 2_000), disconnectedPlayer);
});
