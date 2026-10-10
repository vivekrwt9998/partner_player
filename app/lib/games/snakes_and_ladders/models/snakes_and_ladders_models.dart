/// Player representation for Snakes and Ladders.
enum SnakesAndLaddersPlayer {
  player1,
  player2;

  /// Returns the opponent player.
  SnakesAndLaddersPlayer get opponent => this == SnakesAndLaddersPlayer.player1
      ? SnakesAndLaddersPlayer.player2
      : SnakesAndLaddersPlayer.player1;

  /// Display name for the player.
  String get displayName =>
      this == SnakesAndLaddersPlayer.player1 ? 'Player 1' : 'Player 2';
}

/// Overall status of the game.
///
/// There is no `draw`: somebody reaches the last square first, and only
/// one token can get there.
enum SnakesAndLaddersGameStatus {
  playing,
  won,
}

/// A snake or a ladder on the board.
class Jump {
  final int from;
  final int to;

  const Jump(this.from, this.to);

  bool get isSnake => to < from;

  bool get isLadder => to > from;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Jump &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'Jump($from -> $to)';
}

/// Everything one roll of the die did.
///
/// A roll is not always a move: a token still waiting to come on stays
/// put unless the roll is a six, and a token near the end stays put
/// unless the roll lands it exactly on the last square. The screen
/// needs to tell those apart to say why nothing happened.
class SnakesAndLaddersMove {
  final SnakesAndLaddersPlayer player;

  /// What the die showed, 1 to 6.
  final int roll;

  /// The square the token started on. Zero means it was still waiting
  /// to come onto the board.
  final int from;

  /// Where the token walked to, before any snake or ladder.
  final int landedOn;

  /// Where it ended up once the snake or ladder had its say.
  final int to;

  /// The snake or ladder it found at [landedOn], if any.
  final Jump? jump;

  /// Whether this roll brought the token onto the board.
  final bool entered;

  /// Whether the roll was refused: either it was not the six needed to
  /// come on, or it would have overshot the last square.
  final bool blocked;

  /// Whether the same player rolls again.
  final bool rollsAgain;

  final SnakesAndLaddersGameStatus status;
  final SnakesAndLaddersPlayer? winner;

  const SnakesAndLaddersMove({
    required this.player,
    required this.roll,
    required this.from,
    required this.landedOn,
    required this.to,
    required this.jump,
    required this.entered,
    required this.blocked,
    required this.rollsAgain,
    required this.status,
    required this.winner,
  });

  bool get isTerminal => status != SnakesAndLaddersGameStatus.playing;

  /// How many squares the token actually walks, before any jump.
  int get steps => landedOn - from;
}
