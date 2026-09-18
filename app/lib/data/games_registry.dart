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
    status: GameStatus.comingSoon,
    supportedModes: [
      GameMode.local,
      GameMode.bot,
      GameMode.online,
    ],
    tags: ['2 Players'],
    howToPlayRules: [
      'Take turns placing your mark (X or O) on any empty cell in the 3×3 grid.',
      'Get 3 of your marks in a horizontal, vertical, or diagonal line to win.',
      'If all 9 cells are filled with no winner, the game ends in a draw.',
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
    tags: ['2 Players'],
    howToPlayRules: [
      'Position your fleet of ships secretly on the ocean grid.',
      'Take turns calling out grid coordinates to attack enemy waters.',
      'Sink all of your opponent\'s ships first to claim victory!',
    ],
  ),
];
