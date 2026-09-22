'use strict';

// Server-authoritative port of the Flutter app's TicTacToeGame engine
// (app/lib/games/tic_tac_toe/logic/tic_tac_toe_game.dart). Kept in sync
// with that file's rules deliberately -- this is the copy the backend
// trusts for online matches (AGENTS.md §34 Backend Authority).

const ROWS = 3;
const COLS = 3;
const CONNECT_COUNT = 3;

const PLAYER_ONE = 'player1';
const PLAYER_TWO = 'player2';

const STATUS_PLAYING = 'playing';
const STATUS_WON = 'won';
const STATUS_DRAW = 'draw';

const DIRECTIONS = [
  { dr: 0, dc: 1 }, // horizontal
  { dr: 1, dc: 0 }, // vertical
  { dr: 1, dc: 1 }, // diagonal down-right
  { dr: -1, dc: 1 }, // diagonal up-right
];

class TicTacToeGame {
  constructor() {
    this.reset();
  }

  reset() {
    this.board = Array.from({ length: ROWS }, () => Array(COLS).fill(null));
    this.currentPlayer = PLAYER_ONE;
    this.status = STATUS_PLAYING;
    this.winner = null;
    this.winningPositions = [];
  }

  get isGameOver() {
    return this.status !== STATUS_PLAYING;
  }

  getCell(row, col) {
    if (row < 0 || row >= ROWS || col < 0 || col >= COLS) return null;
    return this.board[row][col];
  }

  canPlace(row, col) {
    if (this.isGameOver) return false;
    if (row < 0 || row >= ROWS || col < 0 || col >= COLS) return false;
    return this.board[row][col] === null;
  }

  /**
   * Places a mark for the current player at row/col.
   * Returns the resolved move, or `null` if the cell was invalid, occupied,
   * or the game had already ended.
   */
  tryPlaceMark(row, col) {
    if (!this.canPlace(row, col)) return null;

    const movingPlayer = this.currentPlayer;
    this.board[row][col] = movingPlayer;

    const winningLine = this._checkWin(row, col, movingPlayer);
    if (winningLine) {
      this.status = STATUS_WON;
      this.winner = movingPlayer;
      this.winningPositions = winningLine;
      return { player: movingPlayer, row, col, status: this.status, winner: this.winner };
    }

    if (this._isBoardFull()) {
      this.status = STATUS_DRAW;
      return { player: movingPlayer, row, col, status: this.status, winner: null };
    }

    this.currentPlayer = movingPlayer === PLAYER_ONE ? PLAYER_TWO : PLAYER_ONE;
    return { player: movingPlayer, row, col, status: this.status, winner: null };
  }

  _isBoardFull() {
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (this.board[r][c] === null) return false;
      }
    }
    return true;
  }

  _checkWin(row, col, player) {
    for (const dir of DIRECTIONS) {
      const line = [{ row, col }];

      let r = row + dir.dr;
      let c = col + dir.dc;
      while (this._isValidCell(r, c) && this.board[r][c] === player) {
        line.push({ row: r, col: c });
        r += dir.dr;
        c += dir.dc;
      }

      r = row - dir.dr;
      c = col - dir.dc;
      while (this._isValidCell(r, c) && this.board[r][c] === player) {
        line.push({ row: r, col: c });
        r -= dir.dr;
        c -= dir.dc;
      }

      if (line.length >= CONNECT_COUNT) {
        line.sort((a, b) => (a.row !== b.row ? a.row - b.row : a.col - b.col));
        return line;
      }
    }
    return null;
  }

  _isValidCell(row, col) {
    return row >= 0 && row < ROWS && col >= 0 && col < COLS;
  }

  toJSON() {
    return {
      board: this.board,
      currentPlayer: this.currentPlayer,
      status: this.status,
      winner: this.winner,
      winningPositions: this.winningPositions,
    };
  }
}

TicTacToeGame.rows = ROWS;
TicTacToeGame.cols = COLS;
TicTacToeGame.connectCount = CONNECT_COUNT;
TicTacToeGame.PLAYER_ONE = PLAYER_ONE;
TicTacToeGame.PLAYER_TWO = PLAYER_TWO;

module.exports = { TicTacToeGame, PLAYER_ONE, PLAYER_TWO };
