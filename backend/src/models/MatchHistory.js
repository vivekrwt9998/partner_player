'use strict';

// The only piece of persistent data this backend needs so far: a record of
// how each completed online match ended. No accounts exist yet, so this is
// intentionally anonymous -- just enough to support future stats without
// storing anything that needs a login to make sense of (AGENTS.md §23
// Persistent Data: persist only what actually needs persisting).

const mongoose = require('mongoose');

const matchHistorySchema = new mongoose.Schema(
  {
    gameId: { type: String, required: true, index: true },
    roomCode: { type: String, required: true },
    status: { type: String, required: true, enum: ['won', 'draw'] },
    winner: { type: String, default: null, enum: ['player1', 'player2', null] },
    playerCount: { type: Number, required: true },
  },
  { timestamps: true },
);

module.exports = mongoose.model('MatchHistory', matchHistorySchema);
