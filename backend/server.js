const crypto = require('crypto');
const http = require('http');
const express = require('express');
const cors = require('cors');
const { Server } = require('socket.io');
const {
  expiredDisconnectedPlayer,
  playerLeftEvent,
} = require('./room_lifecycle');

const app = express();
const server = http.createServer(app);
const isProduction = process.env.NODE_ENV === 'production';
const configuredOrigins = process.env.ALLOWED_ORIGINS
  ?.split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
if (isProduction && !configuredOrigins?.length) {
  throw new Error('ALLOWED_ORIGINS must be set in production.');
}
const allowedOrigins = configuredOrigins?.length ? configuredOrigins : ['*'];
const io = new Server(server, {
  cors: { origin: allowedOrigins, methods: ['GET', 'POST'] },
});

const PORT = Number(process.env.PORT || 3000);
const ROOM_IDLE_MS = 60 * 60 * 1000;
const DISCONNECT_GRACE_MS = 2 * 60 * 1000;
const CLASSIC_TARGET_LINES = 5;
const ROOM_ACTION_WINDOW_MS = 60 * 1000;
const MAX_ROOM_ACTIONS_PER_WINDOW = 20;
const rooms = new Map();
const roomActionBuckets = new Map();

app.disable('x-powered-by');
app.use((_request, response, next) => {
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Referrer-Policy', 'no-referrer');
  next();
});
app.use(cors({ origin: allowedOrigins }));
app.use(express.json({ limit: '16kb' }));
app.get('/health', (_request, response) => response.json({ status: 'ok', rules: 'classic-5-lines' }));

function cleanName(value) {
  const name = String(value || '').trim().replace(/\s+/g, ' ');
  return name.slice(0, 20) || 'Player';
}

function roomCode() {
  let code;
  do {
    code = crypto.randomBytes(3).toString('hex').toUpperCase();
  } while (rooms.has(code));
  return code;
}

function objectPayload(payload) {
  return payload && typeof payload === 'object' && !Array.isArray(payload)
    ? payload
    : {};
}

function validRoomId(value) {
  return typeof value === 'string' && /^[A-F0-9]{6}$/.test(value);
}

function safeTokenEquals(value, expected) {
  if (typeof value !== 'string' || typeof expected !== 'string') return false;
  const supplied = Buffer.from(value);
  const stored = Buffer.from(expected);
  return supplied.length === stored.length && crypto.timingSafeEqual(supplied, stored);
}

function allowRoomAction(socket) {
  const key = socket.handshake.address || socket.id;
  const now = Date.now();
  const bucket = roomActionBuckets.get(key);
  if (!bucket || now - bucket.startedAt >= ROOM_ACTION_WINDOW_MS) {
    roomActionBuckets.set(key, { startedAt: now, count: 1 });
    return true;
  }
  bucket.count += 1;
  return bucket.count <= MAX_ROOM_ACTIONS_PER_WINDOW;
}

function shuffledBoard() {
  const numbers = Array.from({ length: 25 }, (_, index) => index + 1);
  for (let index = numbers.length - 1; index > 0; index -= 1) {
    const swapIndex = crypto.randomInt(index + 1);
    [numbers[index], numbers[swapIndex]] = [numbers[swapIndex], numbers[index]];
  }
  return Array.from({ length: 5 }, (_, row) => numbers.slice(row * 5, row * 5 + 5));
}

function completedLines(board, selectedNumbers) {
  const selected = new Set(selectedNumbers);
  const marked = board.flat().map((number) => selected.has(number));
  const lines = [];
  for (let row = 0; row < 5; row += 1) {
    const indexes = Array.from({ length: 5 }, (_, column) => row * 5 + column);
    if (indexes.every((index) => marked[index])) lines.push({ type: 'row', index: row });
  }
  for (let column = 0; column < 5; column += 1) {
    const indexes = Array.from({ length: 5 }, (_, row) => row * 5 + column);
    if (indexes.every((index) => marked[index])) lines.push({ type: 'column', index: column });
  }
  if ([0, 6, 12, 18, 24].every((index) => marked[index])) lines.push({ type: 'mainDiagonal', index: 0 });
  if ([4, 8, 12, 16, 20].every((index) => marked[index])) lines.push({ type: 'reverseDiagonal', index: 0 });
  return lines;
}

function newPlayer(name, socket) {
  return {
    name: cleanName(name),
    token: crypto.randomUUID(),
    board: shuffledBoard(),
    lines: [],
    score: 0,
    isReady: false,
    rematchRequested: false,
    connected: true,
    socketId: socket.id,
    disconnectedAt: null,
  };
}

function publicRoom(room) {
  return {
    id: room.id,
    status: room.status,
    currentTurn: room.currentTurn,
    selectedNumbers: room.selectedNumbers,
    playerSelections: room.playerSelections,
    round: room.round,
    winner: room.winner,
    players: room.players.map((player) => player && ({
      name: player.name,
      board: player.board,
      lineCount: player.lines.length,
      score: player.score,
      isReady: player.isReady,
      rematchRequested: player.rematchRequested,
      connected: player.connected,
    })),
  };
}

function publish(room) {
  room.updatedAt = Date.now();
  io.to(room.id).emit('room_update', publicRoom(room));
}

function reply(socket, event, payload) {
  socket.emit(`${event}_response`, payload);
}

function attachSocket(socket, room, playerIndex) {
  socket.join(room.id);
  socket.data.roomId = room.id;
  socket.data.playerIndex = playerIndex;
  const player = room.players[playerIndex];
  player.socketId = socket.id;
  player.connected = true;
  player.disconnectedAt = null;
}

function ownRoom(socket, roomId) {
  if (!validRoomId(roomId) || socket.data.roomId !== roomId) return null;
  const room = rooms.get(roomId);
  const playerIndex = socket.data.playerIndex;
  if (!Number.isInteger(playerIndex)) return null;
  const player = room?.players[playerIndex];
  return player?.socketId === socket.id ? room : null;
}

function allPlayers(room) {
  return room.players.length === 2 && room.players.every(Boolean);
}

function resetRound(room) {
  room.selectedNumbers = [];
  room.playerSelections = {};
  room.winner = null;
  room.players.forEach((player) => {
    player.board = shuffledBoard();
    player.lines = [];
    player.isReady = true;
    player.rematchRequested = false;
  });
}

function clearSocketRoom(socket, roomId) {
  socket.leave(roomId);
  if (socket.data.roomId === roomId) {
    socket.data.roomId = null;
    socket.data.playerIndex = null;
  }
}

function closeRoom(room, event, exceptSocketId) {
  if (!room || rooms.get(room.id) !== room) return false;
  rooms.delete(room.id);

  // This server stores rooms in memory, so current room sockets are local.
  for (const player of room.players) {
    if (!player?.connected) continue;
    const playerSocket = io.sockets.sockets.get(player.socketId);
    if (!playerSocket) continue;
    if (playerSocket.id !== exceptSocketId) {
      playerSocket.emit('room_closed', event);
    }
    clearSocketRoom(playerSocket, room.id);
  }
  return true;
}

io.on('connection', (socket) => {
  socket.on('create_room', (unsafePayload = {}) => {
    if (!allowRoomAction(socket)) {
      return reply(socket, 'create_room', { success: false, error: 'Too many room requests. Please try again shortly.' });
    }
    if (socket.data.roomId) {
      return reply(socket, 'create_room', { success: false, error: 'Leave your current room before creating another.' });
    }
    const payload = objectPayload(unsafePayload);
    const id = roomCode();
    const room = {
      id,
      status: 'waiting',
      currentTurn: 0,
      selectedNumbers: [],
      playerSelections: {},
      players: [newPlayer(payload.name, socket), null],
      winner: null,
      round: 1,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    };
    rooms.set(id, room);
    attachSocket(socket, room, 0);
    reply(socket, 'create_room', { success: true, roomId: id, playerIndex: 0, playerToken: room.players[0].token });
    publish(room);
  });

  socket.on('join_room', (unsafePayload = {}) => {
    if (!allowRoomAction(socket)) {
      return reply(socket, 'join_room', { success: false, error: 'Too many room requests. Please try again shortly.' });
    }
    if (socket.data.roomId) {
      return reply(socket, 'join_room', { success: false, error: 'Leave your current room before joining another.' });
    }
    const payload = objectPayload(unsafePayload);
    const roomId = String(payload.roomId || '').trim().toUpperCase();
    if (!validRoomId(roomId)) {
      return reply(socket, 'join_room', { success: false, error: 'Enter a valid six-character room code.' });
    }
    const room = rooms.get(roomId);
    if (!room) return reply(socket, 'join_room', { success: false, error: 'Room not found.' });
    if (room.status !== 'waiting' || room.players[1]) {
      return reply(socket, 'join_room', { success: false, error: 'This room is no longer available.' });
    }
    room.players[1] = newPlayer(payload.name, socket);
    attachSocket(socket, room, 1);
    reply(socket, 'join_room', { success: true, roomId, playerIndex: 1, playerToken: room.players[1].token });
    publish(room);
  });

  socket.on('rejoin_room', (unsafePayload = {}) => {
    const payload = objectPayload(unsafePayload);
    const roomId = String(payload.roomId || '').trim().toUpperCase();
    if (!validRoomId(roomId)) {
      return reply(socket, 'rejoin_room', { success: false, error: 'The room is no longer available.' });
    }
    const room = rooms.get(roomId);
    const playerIndex = room?.players.findIndex((player) =>
      player && safeTokenEquals(payload.playerToken, player.token),
    ) ?? -1;
    if (!room || playerIndex < 0) {
      return reply(socket, 'rejoin_room', { success: false, error: 'The room is no longer available.' });
    }
    attachSocket(socket, room, playerIndex);
    if (room.status === 'paused' && room.players.every((player) => player.connected)) room.status = 'playing';
    reply(socket, 'rejoin_room', { success: true, roomId, playerIndex });
    publish(room);
  });

  socket.on('subscribe_room', (unsafePayload = {}) => {
    const payload = objectPayload(unsafePayload);
    const room = ownRoom(socket, payload.roomId);
    if (!room) return reply(socket, 'subscribe_room', { success: false, error: 'Room access expired.' });
    reply(socket, 'subscribe_room', { success: true });
    socket.emit('room_update', publicRoom(room));
  });

  socket.on('set_ready', (unsafePayload = {}) => {
    const payload = objectPayload(unsafePayload);
    const room = ownRoom(socket, payload.roomId);
    if (!room) return reply(socket, 'set_ready', { success: false, error: 'Room access expired.' });
    if (room.status !== 'waiting') return reply(socket, 'set_ready', { success: false, error: 'The game has already started.' });
    room.players[socket.data.playerIndex].isReady = payload.ready === true;
    if (allPlayers(room) && room.players.every((player) => player.isReady)) {
      room.status = 'playing';
      room.currentTurn = 0;
    }
    reply(socket, 'set_ready', { success: true });
    publish(room);
  });

  socket.on('make_move', (unsafePayload = {}) => {
    const payload = objectPayload(unsafePayload);
    const room = ownRoom(socket, payload.roomId);
    if (!room) return reply(socket, 'make_move', { success: false, error: 'Room access expired.' });
    if (room.status !== 'playing') return reply(socket, 'make_move', { success: false, error: 'The round is not active.' });
    const playerIndex = socket.data.playerIndex;
    if (room.currentTurn !== playerIndex) return reply(socket, 'make_move', { success: false, error: 'Wait for your turn.' });
    const number = Number(payload.number);
    if (!Number.isInteger(number) || number < 1 || number > 25) {
      return reply(socket, 'make_move', { success: false, error: 'That is not a valid board number.' });
    }
    if (Object.hasOwn(room.playerSelections, number)) {
      return reply(socket, 'make_move', { success: false, error: 'That number has already been selected.' });
    }

    room.selectedNumbers.push(number);
    room.playerSelections[number] = playerIndex;
    room.players.forEach((player) => { player.lines = completedLines(player.board, room.selectedNumbers); });
    const finishers = room.players
      .map((player, index) => (player.lines.length >= CLASSIC_TARGET_LINES ? index : null))
      .filter((index) => index !== null);
    if (finishers.length) {
      // A shared number can complete both boards; the legal move owner wins a tie.
      room.winner = finishers.includes(playerIndex) ? playerIndex : finishers[0];
      room.players[room.winner].score += 1;
      room.status = 'finished';
    } else {
      room.currentTurn = playerIndex === 0 ? 1 : 0;
    }
    reply(socket, 'make_move', { success: true });
    publish(room);
  });

  socket.on('request_rematch', (unsafePayload = {}) => {
    const payload = objectPayload(unsafePayload);
    const room = ownRoom(socket, payload.roomId);
    if (!room) return reply(socket, 'request_rematch', { success: false, error: 'Room access expired.' });
    if (room.status !== 'finished') return reply(socket, 'request_rematch', { success: false, error: 'Finish this round first.' });
    room.players[socket.data.playerIndex].rematchRequested = true;
    if (room.players.every((player) => player.rematchRequested)) {
      const lastWinner = room.winner;
      resetRound(room);
      room.round += 1;
      room.status = 'playing';
      room.currentTurn = lastWinner === 0 ? 1 : 0;
    }
    reply(socket, 'request_rematch', { success: true });
    publish(room);
  });

  socket.on('leave_room', (unsafePayload = {}) => {
    const payload = objectPayload(unsafePayload);
    const room = ownRoom(socket, payload.roomId);
    const playerIndex = socket.data.playerIndex;
    const player = room?.players[playerIndex];
    if (room && player) {
      closeRoom(room, playerLeftEvent(player, playerIndex), socket.id);
    } else if (socket.data.roomId) {
      clearSocketRoom(socket, socket.data.roomId);
    }
    reply(socket, 'leave_room', { success: true });
  });

  socket.on('disconnect', () => {
    const room = rooms.get(socket.data.roomId);
    const player = room?.players[socket.data.playerIndex];
    if (player?.socketId !== socket.id) return;
    player.connected = false;
    player.disconnectedAt = Date.now();
    if (room.status === 'playing') room.status = 'paused';
    publish(room);
  });
});

setInterval(() => {
  const now = Date.now();
  for (const [key, bucket] of roomActionBuckets.entries()) {
    if (now - bucket.startedAt > ROOM_ACTION_WINDOW_MS) roomActionBuckets.delete(key);
  }
  for (const room of rooms.values()) {
    const stale = now - room.updatedAt > ROOM_IDLE_MS;
    const disconnectedPlayer = expiredDisconnectedPlayer(
      room,
      now,
      DISCONNECT_GRACE_MS,
    );
    if (disconnectedPlayer) {
      closeRoom(
        room,
        playerLeftEvent(
          disconnectedPlayer,
          room.players.indexOf(disconnectedPlayer),
        ),
      );
    } else if (stale) {
      closeRoom(room, { reason: 'Room expired.', type: 'room_expired' });
    }
  }
}, 60 * 1000).unref();

server.listen(PORT, '0.0.0.0', () => console.log(`Bingo server listening on :${PORT}`));
