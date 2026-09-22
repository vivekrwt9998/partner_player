'use strict';

// In-memory online game rooms. No accounts exist yet (AGENTS.md §17 Friends
// and login/signup are explicitly out of scope for now), so a room is
// identified purely by a short shareable code, and each player is identified
// by a random session token handed back on create/join -- that token is
// what lets a dropped player's client rejoin the same seat after a network
// blip (AGENTS.md §21 Background/Reconnection) without any real identity.
//
// Rooms live only in this process's memory: restarting the server drops all
// in-progress rooms. That's an acceptable, deliberate tradeoff for the free
// single-instance hosting this project targets -- see AGENTS.md §23,
// persist only what actually needs persisting, and no match is "won" from a
// business standpoint until it's actually finished (see models/MatchHistory.js).

const crypto = require('crypto');
const { FourInARowGame } = require('../game/fourInARow/fourInARowGame');
const { TicTacToeGame } = require('../game/ticTacToe/ticTacToeGame');

const ROOM_CODE_LENGTH = 5;
// Excludes visually ambiguous characters (0/O, 1/I) so a code is easy to
// read aloud or retype.
const ROOM_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const RECONNECT_GRACE_MS = 30_000;

const ENGINES = {
  four_in_a_row: FourInARowGame,
  tic_tac_toe: TicTacToeGame,
};

/** @type {Map<string, object>} roomCode -> room */
const roomsByCode = new Map();
/** @type {Map<string, string>} socketId -> roomCode */
const roomCodeBySocketId = new Map();

function isSupportedGame(gameId) {
  return Object.prototype.hasOwnProperty.call(ENGINES, gameId);
}

function generateRoomCode() {
  let code;
  do {
    code = Array.from(
      { length: ROOM_CODE_LENGTH },
      () => ROOM_CODE_CHARS[crypto.randomInt(ROOM_CODE_CHARS.length)],
    ).join('');
  } while (roomsByCode.has(code));
  return code;
}

function createPlayer(slot, socketId, displayName) {
  return {
    slot,
    socketId,
    sessionToken: crypto.randomUUID(),
    displayName: (displayName || '').trim() || (slot === 'player1' ? 'Player 1' : 'Player 2'),
    connected: true,
    disconnectTimer: null,
  };
}

function createRoom({ gameId, socketId, displayName }) {
  if (!isSupportedGame(gameId)) {
    return { error: 'UNSUPPORTED_GAME' };
  }

  const EngineClass = ENGINES[gameId];
  const code = generateRoomCode();
  const player = createPlayer('player1', socketId, displayName);

  const room = {
    code,
    gameId,
    status: 'waiting',
    engine: new EngineClass(),
    players: [player],
    createdAt: Date.now(),
  };

  roomsByCode.set(code, room);
  roomCodeBySocketId.set(socketId, code);

  return { room, sessionToken: player.sessionToken, slot: player.slot };
}

function joinRoom({ code, socketId, displayName }) {
  const room = roomsByCode.get((code || '').toUpperCase());
  if (!room) return { error: 'ROOM_NOT_FOUND' };
  if (room.players.length >= 2) return { error: 'ROOM_FULL' };
  if (room.status !== 'waiting') return { error: 'ROOM_NOT_JOINABLE' };

  const player = createPlayer('player2', socketId, displayName);
  room.players.push(player);
  room.status = 'playing';

  roomCodeBySocketId.set(socketId, room.code);

  return { room, sessionToken: player.sessionToken, slot: player.slot };
}

function getRoomByCode(code) {
  return roomsByCode.get((code || '').toUpperCase()) || null;
}

function getRoomBySocketId(socketId) {
  const code = roomCodeBySocketId.get(socketId);
  return code ? roomsByCode.get(code) || null : null;
}

/** Finds the player a caller claims to be, preferring the session token. */
function findPlayer(room, { socketId, sessionToken }) {
  if (!room) return null;
  return (
    room.players.find((p) => sessionToken && p.sessionToken === sessionToken) ||
    room.players.find((p) => p.socketId === socketId) ||
    null
  );
}

function reconnectPlayer({ code, sessionToken, socketId }) {
  const room = getRoomByCode(code);
  if (!room) return { error: 'ROOM_NOT_FOUND' };

  const player = room.players.find((p) => p.sessionToken === sessionToken);
  if (!player) return { error: 'INVALID_SESSION' };

  if (player.disconnectTimer) {
    clearTimeout(player.disconnectTimer);
    player.disconnectTimer = null;
  }
  roomCodeBySocketId.delete(player.socketId);
  player.socketId = socketId;
  player.connected = true;
  roomCodeBySocketId.set(socketId, room.code);

  return { room, slot: player.slot };
}

/**
 * Marks the disconnected socket's player as offline and starts a grace
 * period before the room is torn down, so a brief network blip doesn't end
 * the match outright.
 */
function handleDisconnect(socketId, { onExpire }) {
  const room = getRoomBySocketId(socketId);
  roomCodeBySocketId.delete(socketId);
  if (!room) return null;

  const player = room.players.find((p) => p.socketId === socketId);
  if (!player) return null;

  player.connected = false;
  player.disconnectTimer = setTimeout(() => {
    deleteRoom(room.code);
    onExpire?.(room);
  }, RECONNECT_GRACE_MS);

  return { room, slot: player.slot };
}

function deleteRoom(code) {
  const room = roomsByCode.get(code);
  if (!room) return;

  for (const player of room.players) {
    if (player.disconnectTimer) clearTimeout(player.disconnectTimer);
    roomCodeBySocketId.delete(player.socketId);
  }
  roomsByCode.delete(code);
}

module.exports = {
  RECONNECT_GRACE_MS,
  isSupportedGame,
  createRoom,
  joinRoom,
  getRoomByCode,
  getRoomBySocketId,
  findPlayer,
  reconnectPlayer,
  handleDisconnect,
  deleteRoom,
};
