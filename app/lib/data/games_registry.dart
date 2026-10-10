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
      'Every cell has a limit: 2 orbs in a corner, 3 along an edge, 4 in the middle.',
      'Reach that limit and the cell bursts, throwing one orb into each neighbouring cell.',
      'Every cell a burst touches turns your colour, orbs and all -- so a single move can flip a whole corner of the board.',
      'Cells hit by a burst can burst in turn, setting off a chain reaction.',
      'Once both players have had a turn, taking your opponent\'s last cell wins the game.',
    ],
  ),
  GameDefinition(
    id: 'reversi',
    name: 'Reversi',
    description: 'Trap a line of your opponent\'s discs between two of yours and flip the lot.',
    icon: Icons.change_circle_rounded,
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
      'The board starts with four discs in the middle, two each. Blue goes first.',
      'Place a disc so that one or more of your opponent\'s discs are trapped in a straight line between it and another disc of yours.',
      'Every trapped disc flips to your colour -- in all eight directions at once, if the placement traps that many lines.',
      'A square that traps nothing is not a legal move; the squares you may play are marked for you.',
      'If you have no legal move your turn is skipped and your opponent plays again.',
      'When neither player can move the discs are counted, and whoever holds more of the board wins. An even split is a draw.',
    ],
  ),
  GameDefinition(
    id: 'dots_and_boxes',
    name: 'Dots and Boxes',
    description: 'Join the dots one line at a time and close more boxes than your opponent.',
    icon: Icons.border_all_rounded,
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
    // The grid is taller than it is wide (6 dots across, 8 down) and is
    // fit/scaled to whatever space is available. Never rotates the
    // device or the pixels. See AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'Take turns drawing one line between any two dots that are next to each other.',
      'Draw the fourth side of a box and it is yours -- it fills with your colour.',
      'Closing a box earns you another line straight away, so a good move can run on and on.',
      'One line can close the box on either side of it, taking both at once.',
      'The line your opponent drew last is shown in their colour, so you can always see what they just did.',
      'When every line is drawn the boxes are counted, and whoever holds more wins.',
    ],
  ),
  GameDefinition(
    id: 'hex',
    name: 'Hex',
    description:
        'Build an unbroken chain of your own stones from one of your sides to the other.',
    icon: Icons.hexagon_rounded,
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
    // The 11x11 rhombus of hexagons is taller than it is wide (17 to
    // 16*sqrt(3)) and is fit/scaled to whatever space is available.
    // Never rotates the device or the pixels. See AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'Take turns placing one stone on any empty cell. Blue goes first.',
      'Stones are never moved, taken or turned over -- once a cell is yours it stays yours.',
      'Blue wins by joining the board\'s two straight sides; Red wins by joining the two slanted ones. Each side is striped in its owner\'s colour, so you can always see which are yours.',
      'A chain counts through any of a cell\'s six neighbours, so it may wander as much as it likes on the way across.',
      'The cells in the corners count towards both of the sides they touch.',
      'Hex can never end in a draw -- fill the board however you like and exactly one player ends up holding a chain.',
    ],
  ),
  GameDefinition(
    id: 'air_hockey',
    name: 'Air Hockey',
    description:
        'Slide your striker, smack the puck past your opponent, and get to three goals first.',
    icon: Icons.sports_hockey_rounded,
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
    // Both players push at once, so there is no turn to indicate. This is
    // the platform's second game with no turns; each player gets their own
    // live score where a face-to-face badge would be. See AGENTS.md
    // §10.1.3.
    turnIndicatorLayout: TurnIndicatorLayout.simultaneous,
    // The table is a real one stood on its end -- 1 wide by 2 tall -- and
    // is fit/scaled to whatever space is available. Never rotates the
    // device or the pixels. See AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'Touch anywhere in your own half and your striker slides to your finger. Both players can push at the same time -- there are no turns here.',
      'Your striker cannot cross the centre line, so your half is yours to defend.',
      'Knock the puck into the goal at the far end. The goal you are defending is painted in your own colour.',
      'The harder you swing your striker, the harder the puck goes -- but a striker can only move so fast, so a wild flick is no quicker than a firm push.',
      'The puck rattles off the walls and off the posts, so a bank shot off the side is often the way past a well-guarded goal.',
      'First to three goals wins the match.',
    ],
  ),
  GameDefinition(
    id: 'soccer_pool',
    name: 'Soccer Pool',
    description: 'Flick your tokens at the ball and knock it past the goalie into the opponent\'s net.',
    icon: Icons.sports_soccer_rounded,
    playerCount: 2,
    status: GameStatus.available,
    supportedModes: [
      GameMode.local,
      GameMode.bot,
      GameMode.online,
    ],
    // Board sits flat between two players, each flicking their own tokens
    // from their own end toward the opponent's goal; it is not handed back
    // and forth. See AGENTS.md §7 / §10.1.4.
    localInteractionType: LocalInteractionType.sharedDevice,
    // Players take turns flicking their tokens at the ball. Red sits at the
    // top (defending the top goal), Blue at the bottom (defending the
    // bottom goal); the standard face-to-face badges place one player on
    // each side of the layout. See AGENTS.md §10.1.2 / §10.1.4.
    turnIndicatorLayout: TurnIndicatorLayout.faceToFace,
    // The pitch is always portrait-shaped (tall), fit/scaled to whatever
    // space is available. Never rotates the device or the pixels; the
    // field stays top-goal-down-goal. See AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'Take turns flicking one of your five tokens at the ball -- pick up a token, drag to aim, release to fire.',
      'Tokens bounce off the walls, the goal frame and each other, so plan your angle and let the rebounds open up the goal.',
      'Knock the ball into the opponent\'s goal mouth to score; first to 3 wins.',
      'Misses and rebounds stay on the pitch -- repositioning is automatic, and the next turn is the opponent\'s.',
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
    id: 'snakes_and_ladders',
    name: 'Snakes and Ladders',
    description:
        'Roll the die, climb the ladders, dodge the snakes, and be first to a hundred.',
    icon: Icons.casino_rounded,
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
    // A 10x10 board is square, so it reads the same whether the device
    // is portrait or landscape; the composition always stays stacked
    // top-board-bottom. See AGENTS.md §8.
    orientationBehavior: GameOrientationBehavior.fixedPortrait,
    tags: ['2 Players'],
    howToPlayRules: [
      'Your token waits off the board until you roll a six, which brings it on at square six.',
      'Roll a six and you go again -- however many times in a row it comes up.',
      'Land at the foot of a ladder and you climb it; land on a snake\'s head and you slide all the way down its tail.',
      'To finish you have to land on a hundred exactly. Roll more than you need and your token stays where it is.',
      'First token to a hundred wins.',
    ],
  ),
];
