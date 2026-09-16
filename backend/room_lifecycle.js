// Room-close payloads and reconnect-grace policy.

function displayName(player) {
  const name = typeof player?.name === 'string'
    ? player.name.trim().replace(/\s+/g, ' ').slice(0, 20)
    : '';
  return name || 'A player';
}

function playerLeftEvent(player, playerIndex) {
  const name = displayName(player);
  return {
    type: 'player_left',
    reason: `${name} left the game.`,
    playerName: name,
    playerIndex,
  };
}

function expiredDisconnectedPlayer(room, now, graceMs) {
  if (!Array.isArray(room?.players)) return null;
  return room.players.find((player) =>
    player &&
    player.connected === false &&
    Number.isFinite(player.disconnectedAt) &&
    now - player.disconnectedAt >= graceMs,
  ) ?? null;
}

module.exports = { expiredDisconnectedPlayer, playerLeftEvent };
