'use strict';

// Wires Socket.IO events to the room manager and the server-authoritative
// game engines. The server, never the client, decides whether a move is
// legal, whose turn it is, and how a match ends (AGENTS.md §34 Backend
// Authority, §35 Validation).

const roomManager = require('./roomManager');
const MatchHistory = require('../models/MatchHistory');

const MOVE_VALIDATORS = {
  four_in_a_row: (engine, move) =>
    !!move && typeof move.col === 'number' && engine.canDrop(move.col),
  tic_tac_toe: (engine, move) =>
    !!move &&
    typeof move.row === 'number' &&
    typeof move.col === 'number' &&
    engine.canPlace(move.row, move.col),
};

function applyMove(gameId, engine, move) {
  if (gameId === 'four_in_a_row') return engine.tryDropDisc(move.col);
  if (gameId === 'tic_tac_toe') return engine.tryPlaceMark(move.row, move.col);
  return null;
}

// The board is tiny (at most 6x7), so sending the full state after every
// move is simpler and still cheap -- diffing it would be needless
// complexity for the bandwidth it would actually save (AGENTS.md §54 Do Not
// Over-Engineer / §38 Network Efficiency).
function roomStatePayload(room) {
  return {
    code: room.code,
    gameId: room.gameId,
    status: room.status,
    game: room.engine.toJSON(),
    players: room.players.map((p) => ({
      slot: p.slot,
      displayName: p.displayName,
      connected: p.connected,
    })),
  };
}

async function persistMatchHistory(room) {
  await MatchHistory.create({
    gameId: room.gameId,
    roomCode: room.code,
    status: room.engine.status,
    winner: room.engine.winner,
    playerCount: room.players.length,
  });
}

function registerGameSocketHandlers(io, socket) {
  socket.on('room:create', ({ gameId, displayName } = {}, ack) => {
    const result = roomManager.createRoom({ gameId, socketId: socket.id, displayName });
    if (result.error) {
      ack?.({ ok: false, error: result.error });
      return;
    }

    const { room, sessionToken, slot } = result;
    socket.join(room.code);
    ack?.({ ok: true, code: room.code, sessionToken, slot, state: roomStatePayload(room) });
  });

  socket.on('room:join', ({ code, displayName } = {}, ack) => {
    const result = roomManager.joinRoom({ code, socketId: socket.id, displayName });
    if (result.error) {
      ack?.({ ok: false, error: result.error });
      return;
    }

    const { room, sessionToken, slot } = result;
    socket.join(room.code);
    ack?.({ ok: true, code: room.code, sessionToken, slot, state: roomStatePayload(room) });
    io.to(room.code).emit('room:state', roomStatePayload(room));
  });

  socket.on('room:rejoin', ({ code, sessionToken } = {}, ack) => {
    const result = roomManager.reconnectPlayer({ code, sessionToken, socketId: socket.id });
    if (result.error) {
      ack?.({ ok: false, error: result.error });
      return;
    }

    const { room, slot } = result;
    socket.join(room.code);
    ack?.({ ok: true, code: room.code, slot, state: roomStatePayload(room) });
    socket.to(room.code).emit('opponent:reconnected', { slot });
  });

  socket.on('room:leave', ({ code } = {}) => {
    const room = roomManager.getRoomByCode(code);
    if (!room) return;

    socket.to(room.code).emit('opponent:left');
    roomManager.deleteRoom(room.code);
  });

  socket.on('game:move', ({ code, sessionToken, move } = {}, ack) => {
    const room = roomManager.getRoomByCode(code);
    if (!room) {
      ack?.({ ok: false, error: 'ROOM_NOT_FOUND' });
      return;
    }

    const player = roomManager.findPlayer(room, { socketId: socket.id, sessionToken });
    if (!player || player.sessionToken !== sessionToken) {
      ack?.({ ok: false, error: 'INVALID_SESSION' });
      return;
    }
    if (room.status !== 'playing') {
      ack?.({ ok: false, error: 'GAME_NOT_ACTIVE' });
      return;
    }
    if (room.engine.currentPlayer !== player.slot) {
      ack?.({ ok: false, error: 'NOT_YOUR_TURN' });
      return;
    }

    const validator = MOVE_VALIDATORS[room.gameId];
    if (!validator?.(room.engine, move)) {
      ack?.({ ok: false, error: 'ILLEGAL_MOVE' });
      return;
    }

    const result = applyMove(room.gameId, room.engine, move);
    if (!result) {
      ack?.({ ok: false, error: 'ILLEGAL_MOVE' });
      return;
    }

    ack?.({ ok: true });
    io.to(room.code).emit('game:state', roomStatePayload(room));

    if (room.engine.isGameOver) {
      room.status = 'finished';
      io.to(room.code).emit('game:over', {
        status: room.engine.status,
        winner: room.engine.winner,
      });
      persistMatchHistory(room).catch((err) => {
        console.error('Failed to persist match history:', err.message);
      });
    }
  });

  socket.on('disconnect', () => {
    const result = roomManager.handleDisconnect(socket.id, {
      onExpire: (room) => {
        io.to(room.code).emit('opponent:left');
      },
    });
    if (result) {
      socket.to(result.room.code).emit('opponent:disconnected', { slot: result.slot });
    }
  });
}

module.exports = { registerGameSocketHandlers };
