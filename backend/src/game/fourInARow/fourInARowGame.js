'use strict';

// Server-authoritative port of the Flutter app's FourInARowGame engine
// (app/lib/games/four_in_a_row/logic/four_in_a_row_game.dart). Kept in sync
// with that file's rules deliberately -- this is the copy the backend
// trusts for online matches (AGENTS.md §34 Backend Authority).

const ROWS = 6;
const COLS = 7;
const CONNECT_COUNT = 4;

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

class FourInARowGame {
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

  isColumnFull(col) {
    if (col < 0 || col >= COLS) return true;
    return this.board[0][col] !== null;
  }

  canDrop(col) {
    if (this.isGameOver) return false;
    return !this.isColumnFull(col);
  }

  /**
   * Applies a disc drop for the current player.
   * Returns the resolved move, or `null` if the column was invalid, full,
   * or the game had already ended.
   */
  tryDropDisc(col) {
    if (!this.canDrop(col)) return null;

    let targetRow = -1;
    for (let r = ROWS - 1; r >= 0; r--) {
      if (this.board[r][col] === null) {
        targetRow = r;
        break;
      }
    }
    if (targetRow === -1) return null;

    const movingPlayer = this.currentPlayer;
    this.board[targetRow][col] = movingPlayer;

    const winningLine = this._checkWin(targetRow, col, movingPlayer);
    if (winningLine) {
      this.status = STATUS_WON;
      this.winner = movingPlayer;
      this.winningPositions = winningLine;
      return { player: movingPlayer, column: col, row: targetRow, status: this.status, winner: this.winner };
    }

    if (this._isBoardFull()) {
      this.status = STATUS_DRAW;
      return { player: movingPlayer, column: col, row: targetRow, status: this.status, winner: null };
    }

    this.currentPlayer = movingPlayer === PLAYER_ONE ? PLAYER_TWO : PLAYER_ONE;
    return { player: movingPlayer, column: col, row: targetRow, status: this.status, winner: null };
  }

  _isBoardFull() {
    for (let c = 0; c < COLS; c++) {
      if (this.board[0][c] === null) return false;
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
        line.sort((a, b) => (a.col !== b.col ? a.col - b.col : a.row - b.row));
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

FourInARowGame.rows = ROWS;
FourInARowGame.cols = COLS;
FourInARowGame.connectCount = CONNECT_COUNT;
FourInARowGame.PLAYER_ONE = PLAYER_ONE;
FourInARowGame.PLAYER_TWO = PLAYER_TWO;

module.exports = { FourInARowGame, PLAYER_ONE, PLAYER_TWO };
