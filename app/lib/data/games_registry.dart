import 'package:flutter/material.dart';
import '../models/game_definition.dart';

/// Central static catalog of all games supported on the platform.
///
/// To add a new game:
///   1. Add its [GameDefinition] entry here with its supported modes.
///   2. Create its gameplay screen.
///   3. Register its route in [GameLauncher].
///
/// The Lobby and Generic Game Details pages will render the new game automatically.
const List<GameDefinition> kGames = [
  GameDefinition(
    id: 'four_in_a_row',
    name: 'Four in a Row',
    description: 'Drop pieces and connect four in a line before your opponent does.',
    icon: Icons.grid_on_rounded,
    playerCount: 2,
    status: GameStatus.available,
    supportedModes: [
      GameMode.local,
      GameMode.bot,
      GameMode.online,
    ],
    // Board sits flat between two players, each dropping discs from their
    // own side; it is not handed back and forth. See AGENTS.md §7 / §10.1.4.
    localInteractionType: LocalInteractionType.sharedDevice,
    turnIndicatorLayout: TurnIndicatorLayout.sideBySide,
    // The board is always landscape-shaped (7 wide x 6 tall), fit/scaled to
    // whatever space is available. Never rotates the device or the pixels;
    // discs always fall top -> bottom. See AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedLandscape,
    tags: ['2 Players', 'Offline Ready'],
    howToPlayRules: [
      'Players take turns dropping one colored disc into any of the 7 columns.',
      'The disc falls to the lowest empty spot in that column.',
      'First player to connect 4 discs in a line (horizontal, vertical, or diagonal) wins!',
      'If the board fills up with no 4-in-a-row, the game is a draw.',
    ],
  ),
  GameDefinition(
    id: 'tic_tac_toe',
    name: 'Tic Tac Toe',
    description: 'The classic 3×3 showdown. Get three in a row to claim victory.',
    icon: Icons.grid_3x3_rounded,
    playerCount: 2,
    status: GameStatus.available,
    supportedModes: [
      GameMode.local,
      GameMode.bot,
      GameMode.online,
    ],
    // Players sit opposite each other reaching the same flat device, one
    // near/bottom (Blue) and one far/top (Red). See AGENTS.md §10.1.2.
    localInteractionType: LocalInteractionType.sharedDevice,
    turnIndicatorLayout: TurnIndicatorLayout.faceToFace,
    // A 3x3 board is square, so it reads the same whether the device is
    // portrait or landscape; the composition always stays stacked
    // top-board-bottom (never a side-by-side layout). See AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'Take turns placing your mark (X or O) on any empty cell in the 3×3 grid.',
      'Get 3 of your marks in a horizontal, vertical, or diagonal line to win.',
      'If all 9 cells are filled with no winner, the game ends in a draw.',
    ],
  ),
  GameDefinition(
    id: 'checkers',
    name: 'Checkers',
    description: 'Jump your way to victory. Capture all of your opponent\'s pieces to win.',
    icon: Icons.grid_4x4_rounded,
    playerCount: 2,
    status: GameStatus.available,
    supportedModes: [
      GameMode.local,
      GameMode.bot,
      GameMode.online,
    ],
    // Players sit opposite each other reaching the same flat device, one
    // near/bottom (Blue) and one far/top (Red). See AGENTS.md §10.1.2.
    localInteractionType: LocalInteractionType.sharedDevice,
    turnIndicatorLayout: TurnIndicatorLayout.faceToFace,
    // An 8x8 board is square, so it reads the same whether the device is
    // portrait or landscape; the composition always stays stacked
    // top-board-bottom (never a side-by-side layout). See AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'Move your pieces diagonally forward, one square at a time.',
      'Jump over an adjacent opponent piece into an empty square to capture it.',
      'If a capture is available, you must take it -- chain multiple jumps when you can.',
      'Reach the far row to crown your piece as a King, which can move and capture in every direction.',
      'Capture all of your opponent\'s pieces, or leave them with no legal moves, to win.',
    ],
  ),
  GameDefinition(
    id: 'tetra_tower',
    name: 'Tetra Tower',
    description: 'Stack Tetris-shaped pieces without tipping the tower over.',
    icon: Icons.layers_rounded,
    playerCount: 2,
    status: GameStatus.available,
    supportedModes: [
      GameMode.local,
      GameMode.bot,
      GameMode.online,
    ],
    // Players sit opposite each other reaching the same flat device, one
    // near/bottom (Blue) and one far/top (Red). See AGENTS.md §10.1.2.
    localInteractionType: LocalInteractionType.sharedDevice,
    turnIndicatorLayout: TurnIndicatorLayout.faceToFace,
    // Each floor is a square 4x4 grid, so it reads the same whether the
    // device is portrait or landscape; the composition always stays
    // stacked top-board-bottom (never a side-by-side layout). See
    // AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'Each turn you get a random Tetris-shaped piece -- rotate it if you need to, then place it anywhere it fits on the current floor.',
      'Placing a piece over empty space below makes the tower less stable -- and so does simply building higher.',
      'Watch the stability meter: once it\'s full, the tower comes crashing down.',
      'Whoever places the piece that topples the tower loses!',
    ],
  ),
  GameDefinition(
    id: 'sling_puck',
    name: 'Sling Puck',
    description: 'Sling every puck off your half before your opponent clears theirs.',
    icon: Icons.sports_hockey_rounded,
    playerCount: 2,
    status: GameStatus.available,
    supportedModes: [
      GameMode.local,
      GameMode.bot,
      GameMode.online,
    ],
    // Board sits flat on a table between two players sitting opposite each
    // other, each slinging pucks from their own end; it is not handed back
    // and forth. See AGENTS.md §7 / §10.1.4.
    localInteractionType: LocalInteractionType.sharedDevice,
    // The one game on the platform with no turns: both players scrabble at
    // the board at once and the first to clear their own half wins, so
    // there is no turn to indicate. See AGENTS.md §10.1.3 and the
    // `simultaneous` enum value's own documentation.
    turnIndicatorLayout: TurnIndicatorLayout.simultaneous,
    // The board is always portrait-shaped (tall), fit/scaled to whatever
    // space is available. Never rotates the device or the pixels. See
    // AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'There are no turns -- both players play at the same time, as fast as they can.',
      'Each end of the board has an elastic band. Pick up a puck, carry it back into your band, then let go to fire it.',
      'The puck flies out the exact opposite way you pulled it, so pull back and left to send it forward and right.',
      'The further you draw the band, the faster the puck goes and the further it travels.',
      'Aim for the gap in the middle wall -- getting a puck through sends it onto your opponent\'s end.',
      'Missed shots bounce off the walls, off other pucks, and back off the bands, and stay on your half to try again.',
      'Any puck on your half is yours to sling, whatever colour it is -- so send theirs straight back.',
      'The moment a player\'s half is clear they win, and the gate slams shut so nothing can come back through.',
    ],
  ),
  GameDefinition(
    id: 'color_war',
    name: 'Color War',
    description: 'Overfill a cell to set off a chain reaction and paint the whole board your colour.',
    icon: Icons.bubble_chart_rounded,
    playerCount: 2,
    status: GameStatus.available,
    supportedModes: [
      GameMode.local,
      GameMode.bot,
      GameMode.online,
    ],
    // Players sit opposite each other reaching the same flat device, one
    // near/bottom (Blue) and one far/top (Red). See AGENTS.md §10.1.2.
    localInteractionType: LocalInteractionType.sharedDevice,
    turnIndicatorLayout: TurnIndicatorLayout.faceToFace,
    // The grid is square, so it reads the same whether the device is
    // portrait or landscape; the composition always stays stacked
    // top-board-bottom (never a side-by-side layout). See AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'Take turns dropping one orb into any empty cell, or into a cell you already own -- never into your opponent\'s.',
      'Every cell holds 4 orbs, wherever it sits on the board.',
      'Collect the 4th orb and the cell bursts, emptying itself and throwing one orb into each neighbouring cell.',
      'Every cell a burst touches turns your colour, orbs and all -- so a single move can flip a whole corner of the board.',
      'Cells hit by a burst can burst in turn, setting off a chain reaction.',
      'Once both players have had a turn, taking your opponent\'s last cell wins the game.',
    ],
  ),
  GameDefinition(
    id: 'battleship',
    name: 'Battleship',
    description: 'Hunt your opponent\'s fleet across the ocean and sink them all.',
    icon: Icons.water_rounded,
    playerCount: 2,
    status: GameStatus.comingSoon,
    supportedModes: [
      GameMode.online,
      GameMode.bot,
    ],
    // Placeholder only: Battleship has no gameplay screen yet, so its board
    // shape hasn't actually been designed. Revisit when it is built.
    orientationBehavior: GameOrientationBehavior.adaptive,
    tags: ['2 Players'],
    howToPlayRules: [
      'Position your fleet of ships secretly on the ocean grid.',
      'Take turns calling out grid coordinates to attack enemy waters.',
      'Sink all of your opponent\'s ships first to claim victory!',
    ],
  ),
];
