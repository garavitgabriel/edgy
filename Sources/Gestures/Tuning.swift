import EdgyCore

/// Pipeline thresholds that are not user settings. Distances in millimetres, times in seconds.
///
/// These are first guesses chosen from typical finger kinematics; they are meant to be tuned
/// against real recorded traces (see `.parallel-plans/done-batch-2.md`).
struct Tuning: Hashable, Sendable {
  /// A touch that never strays farther than this from where it landed counts as "still" for dwell.
  var stillRadiusMM = 1.0
  /// Along-axis travel that, if clearly dominant, claims a slide before the dwell elapses.
  var alongClaimMM = 2.0
  /// "Clearly dominant": the winning axis must be this many times the other axis.
  var axisDominance = 2.0
  /// Perpendicular travel at which a perpendicular-dominant touch is decided (handoff or off-axis).
  var perpendicularDecideMM = 2.5
  /// Total travel at which a touch with no dominant axis is rejected as off-axis.
  var diagonalDecideMM = 3.0
  /// Initial along-axis speed at or above which a touch is a swipe candidate instead of a slide.
  var flickSpeedMMPerS = 180.0
  /// Minimum along-axis travel for a swipe.
  var swipeMinTravelMM = 6.0
  /// A swipe candidate must lift within this time of landing.
  var swipeMaxDurationS = 0.35
  /// Swipe time limit on zones with no slide bound (no slide to confuse it with, so be generous).
  var swipeOnlyMaxDurationS = 0.6
  /// Longest touch that can still be a tap.
  var tapMaxDurationS = 0.25
  /// Most a tap may travel.
  var tapMaxTravelMM = 1.5
  /// Most a long-press may travel before it fires. Same stillness as a dwell claim
  /// (`stillRadiusMM`): at 1.5 mm a finger drifting ~2.7 mm/s still fired at 500 ms (v0.3).
  var longPressMaxTravelMM = 1.0
  /// A corner touch that travels farther than this (before a long-press fires) is rejected.
  var cornerMaxTravelMM = 3.0
  /// A resting slide must move this far before it emits output again (hysteresis).
  var deadBandMM = 0.8
  /// While moving, staying within this distance for `restDurationS` puts the slide back at rest.
  var restEpsilonMM = 0.6
  /// See `restEpsilonMM`.
  var restDurationS = 0.1
  /// A claim (slide or hold) is revoked when another, non-palm contact travels this far from
  /// where it landed: a second finger moving the pointer means the hand isn't on the edge for us,
  /// and the claim would freeze the pointer under it. A late finger that only rests is left alone.
  var foreignMotionMM = 3.0
  /// Contacts landing within this window of each other belong to one multi-finger touch.
  var multiFingerWindowS = 0.12
  /// Palm gate: a minor axis this wide is a flat, round blob (palm or knuckle), whatever the major axis.
  var palmMinorAxisMM = 14.0
  /// Palm gate: device-reported size at or above this is a palm-sized outlier.
  var palmSize = 2.5
  /// Palm gate: size at or above `palmSoftSize` with density below `palmMaxDensity` is a light,
  /// spread-out contact typical of a resting hand edge.
  var palmSoftSize = 1.5
  /// See `palmSoftSize`.
  var palmMaxDensity = 0.1
  /// Floor for elapsed time when computing an initial speed (half a 120 Hz frame).
  var minimumIntervalS = 1.0 / 240.0

  static let standard = Tuning()
}

/// `GestureSettings` times converted once from milliseconds to seconds, so no comparison mixes units.
struct Timing: Hashable, Sendable {
  let dwell: Double
  let longPress: Double
  let doubleTapWindow: Double
  let typingSuppression: Double

  init(_ settings: GestureSettings) {
    dwell = settings.dwellMS / 1000
    longPress = settings.longPressMS / 1000
    doubleTapWindow = settings.doubleTapWindowMS / 1000
    typingSuppression = settings.typingSuppressionMS / 1000
  }
}
