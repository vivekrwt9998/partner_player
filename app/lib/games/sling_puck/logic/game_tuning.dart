/// Every tunable number for Sling Puck, in one place.
///
/// ## Units
///
/// The simulation runs in **field widths**. The field is exactly `1.0` wide
/// and `2.0` tall, so every length here is a fraction of the field width
/// (`W`) and every speed is `W` per second. The renderer is the only thing
/// that knows about pixels: it scales the whole field by whatever width it
/// has been given. That keeps the physics identical on every screen size.
///
/// The defaults were measured frame-by-frame from a 30 fps recording of the
/// reference game at W = 424 px, so they carry roughly +/-15%.
class GameTuning {
  const GameTuning({
    this.pieceRadius = 0.074,
    this.barThickness = 0.05,
    this.gateThicknessFactor = 0.7,
    this.gapWidth = 0.28,
    this.bandInset = 0.16,
    this.bandStroke = 0.014,
    this.bandPostInset = 0.02,
    this.maxStretch = 0.16,
    this.minLaunchStretch = 0.02,
    this.launchSpeed = 4.0,
    this.cruiseSpeed = 2.0,
    this.boostDuration = 0.25,
    this.boostEaseRate = 25.0,
    this.slowRate = 2.20,
    this.restSpeed = 0.02,
    this.bandOmega = 18.0,
    this.bandZeta = 0.35,
    this.bandSettleFraction = 0.05,
    this.restitutionPiece = 0.35,
    this.restitutionWall = 0.30,
    this.restitutionBand = 0.45,
    this.reboostFactor = 2.0,
    this.reboostShare = 0.45,
    this.trailSeconds = 0.15,
    this.trailMinSpeed = 0.3,
  });

  /// Field is 1 wide by 2 tall, by definition of the unit.
  static const double fieldWidth = 1.0;
  static const double fieldHeight = 2.0;

  /// Physics sub-step. Fixed so behaviour cannot drift with frame rate.
  static const double fixedDt = 1 / 240;

  /// Longest real frame fed into the accumulator in one go, so a stalled
  /// frame cannot spiral into hundreds of catch-up sub-steps.
  static const double maxFrameTime = 0.25;

  /// Piece collision radius, including its outline.
  final double pieceRadius;

  /// Full thickness of the divider bars (they are drawn and collided as
  /// capsules, so this is twice their capsule radius).
  final double barThickness;

  /// Width of the goal gap in the middle of the divider.
  final double gapWidth;

  /// How thick the gate is relative to the bars it closes between. Slimmer
  /// than the divider so a shut gate reads as a separate thing dropped
  /// into the gap rather than the wall simply growing over it.
  final double gateThicknessFactor;

  /// How far each band's resting line sits in from its own end of the field.
  final double bandInset;

  /// Stroke width the band is drawn with.
  final double bandStroke;

  /// How far in from the side walls the band's anchor posts sit.
  final double bandPostInset;

  /// `D_MAX` -- the furthest a band can be drawn, measured at the apex. A
  /// piece can be held here for as long as the player likes; it is letting
  /// go that fires it.
  final double maxStretch;

  /// How far the band must be drawn for letting go to count as a shot.
  /// Below this the piece is simply put down.
  final double minLaunchStretch;

  /// `V_LAUNCH` -- the speed a band always releases at, and the ceiling on
  /// a player's own throw.
  final double launchSpeed;

  /// `V_CRUISE` -- the speed a piece settles to once its boost runs out.
  final double cruiseSpeed;

  /// `T_BOOST` -- how long a full-speed launch coasts without any drag.
  final double boostDuration;

  /// `BOOST_EASE` expressed as a rate: once the boost ends, speed above
  /// [cruiseSpeed] decays toward it at this exponential rate.
  final double boostEaseRate;

  /// `K_SLOW` -- gentle exponential decay applied at or below cruise speed.
  final double slowRate;

  /// `V_REST` -- below this a piece is snapped to a dead stop.
  final double restSpeed;

  /// Band spring: undamped angular frequency and damping ratio for the
  /// release animation `d'' = -omega^2 d - 2 zeta omega d'`.
  final double bandOmega;
  final double bandZeta;

  /// The band counts as settled once its amplitude falls under this
  /// fraction of [maxStretch]. Purely a visual/bookkeeping cut-off.
  final double bandSettleFraction;

  final double restitutionPiece;
  final double restitutionWall;

  /// How much speed a *loose* piece keeps when it rebounds off a band.
  ///
  /// Not in the measured spec, which had bands catapult anything that
  /// touched them. Only a piece a player deliberately presses in loads a
  /// band now, so a stray one has to be turned back instead -- and slack
  /// elastic absorbs far more than a wall does.
  final double restitutionBand;

  /// A piece knocked above `cruiseSpeed * reboostFactor` by another piece
  /// picks up a boost of its own, scaled by how hard it was hit.
  final double reboostFactor;

  /// What share of a real launch's coasting a *struck* piece gets.
  ///
  /// Kept well under 1 so a shot into a cluster does not hand every piece
  /// it touches the same drag-free run the shot itself had -- otherwise one
  /// good hit sends the whole pile flying at full speed.
  final double reboostShare;

  /// Comet trail: how many seconds of travel its length represents, and the
  /// speed below which it is not drawn at all.
  final double trailSeconds;
  final double trailMinSpeed;

  // -- Derived geometry -------------------------------------------------

  double get barHalfThickness => barThickness / 2;
  double get gateThickness => barThickness * gateThicknessFactor;
  double get gateHalfThickness => gateThickness / 2;
  double get barCentreY => fieldHeight / 2;
  double get gapLeft => (fieldWidth - gapWidth) / 2;
  double get gapRight => (fieldWidth + gapWidth) / 2;

  /// Resting line of the top band, and of the bottom band.
  double get topBandY => bandInset;
  double get bottomBandY => fieldHeight - bandInset;

  /// Speed above which a struck piece earns its own boost.
  double get reboostSpeed => cruiseSpeed * reboostFactor;

  /// Amplitude under which a released band is considered settled.
  double get bandSettleDepth => maxStretch * bandSettleFraction;

  GameTuning copyWith({
    double? pieceRadius,
    double? barThickness,
    double? gapWidth,
    double? gateThicknessFactor,
    double? bandInset,
    double? bandStroke,
    double? bandPostInset,
    double? maxStretch,
    double? minLaunchStretch,
    double? launchSpeed,
    double? cruiseSpeed,
    double? boostDuration,
    double? boostEaseRate,
    double? slowRate,
    double? restSpeed,
    double? bandOmega,
    double? bandZeta,
    double? bandSettleFraction,
    double? restitutionPiece,
    double? restitutionWall,
    double? restitutionBand,
    double? reboostFactor,
    double? reboostShare,
    double? trailSeconds,
    double? trailMinSpeed,
  }) {
    return GameTuning(
      pieceRadius: pieceRadius ?? this.pieceRadius,
      barThickness: barThickness ?? this.barThickness,
      gapWidth: gapWidth ?? this.gapWidth,
      gateThicknessFactor: gateThicknessFactor ?? this.gateThicknessFactor,
      bandInset: bandInset ?? this.bandInset,
      bandStroke: bandStroke ?? this.bandStroke,
      bandPostInset: bandPostInset ?? this.bandPostInset,
      maxStretch: maxStretch ?? this.maxStretch,
      minLaunchStretch: minLaunchStretch ?? this.minLaunchStretch,
      launchSpeed: launchSpeed ?? this.launchSpeed,
      cruiseSpeed: cruiseSpeed ?? this.cruiseSpeed,
      boostDuration: boostDuration ?? this.boostDuration,
      boostEaseRate: boostEaseRate ?? this.boostEaseRate,
      slowRate: slowRate ?? this.slowRate,
      restSpeed: restSpeed ?? this.restSpeed,
      bandOmega: bandOmega ?? this.bandOmega,
      bandZeta: bandZeta ?? this.bandZeta,
      bandSettleFraction: bandSettleFraction ?? this.bandSettleFraction,
      restitutionPiece: restitutionPiece ?? this.restitutionPiece,
      restitutionWall: restitutionWall ?? this.restitutionWall,
      restitutionBand: restitutionBand ?? this.restitutionBand,
      reboostFactor: reboostFactor ?? this.reboostFactor,
      reboostShare: reboostShare ?? this.reboostShare,
      trailSeconds: trailSeconds ?? this.trailSeconds,
      trailMinSpeed: trailMinSpeed ?? this.trailMinSpeed,
    );
  }
}
