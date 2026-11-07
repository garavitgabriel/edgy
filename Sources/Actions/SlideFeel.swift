import EdgyCore
import Foundation

/// The one slide feel every slide shares (batch 20): travel in millimetres becomes steps or level,
/// quick flicks go further, and resting at the end of the edge keeps stepping.
///
/// - **Steps in millimetres.** A stepped action (app switcher, repeated keys) moves one step per
///   `stepMM` of travel, the same on every pad and every segment size.
/// - **Speed-up.** Travel is multiplied by a gain that rises smoothly with the finger's speed:
///   1 up to `speedUpStartMMPerS` (slow = precise), `maxGain` from `speedUpFullMMPerS` on, a
///   smoothstep in between (continuous, flat at both ends, so no speed makes the gain jump).
///   Stepped actions use `steppedMaxGain`; levels use the gentler `levelMaxGain`.
/// - **End-of-edge stepping.** While the finger rests at an end of the zone
///   (`SlideMotion.atEnd ≠ 0`), a stepped action keeps stepping toward that end. The rate eases in
///   from `endStartRate` to `endFullRate` steps per second over `endEaseInS`, and stops the moment
///   the finger moves (any motion event has `atEnd == 0`) or lifts. The recognizer reports an end
///   on every frame while resting, so the frame clock drives the steps; no timer is needed.
///
/// Speed is the finger's along-axis speed, smoothed over `speedSmoothingS` so one jittery frame
/// can't spike the gain. A gap longer than `maxIntervalS` (a pause) starts the speed afresh.
enum SlideFeel {
  /// Below this speed the gain is 1.
  static let speedUpStartMMPerS = 60.0
  /// From this speed on the gain is its maximum.
  static let speedUpFullMMPerS = 300.0
  /// Most a quick flick multiplies travel by, for stepped actions (apps, key presses).
  static let steppedMaxGain = 3.0
  /// Most a quick flick multiplies travel by, for levels: gentle, so a flick can't slam the volume.
  static let levelMaxGain = 1.6
  /// Time constant of the speed's exponential smoothing.
  static let speedSmoothingS = 0.04
  /// The shortest interval used to compute a speed (half a 120 Hz frame).
  static let minIntervalS = 1.0 / 240.0
  /// A longer gap between motion events is a pause: the speed starts over.
  static let maxIntervalS = 0.1

  /// End stepping rate when it starts, steps per second.
  static let endStartRate = 2.0
  /// End stepping rate once eased in, steps per second.
  static let endFullRate = 6.0
  /// How long end stepping takes to reach `endFullRate`.
  static let endEaseInS = 0.6

  /// The gain at `speed` (mm/s), between 1 and `maxGain`.
  static func gain(speed: Double, maxGain: Double) -> Double {
    guard speed.isFinite, maxGain > 1 else { return 1 }
    let t = min(max((speed - speedUpStartMMPerS) / (speedUpFullMMPerS - speedUpStartMMPerS), 0), 1)
    return 1 + (maxGain - 1) * t * t * (3 - 2 * t)
  }

  /// The end stepping rate (steps/s) `seconds` after it started.
  static func endRate(after seconds: Double) -> Double {
    let t = min(max(seconds / endEaseInS, 0), 1)
    return endStartRate + (endFullRate - endStartRate) * t
  }
}

/// The finger's smoothed along-axis speed, from successive `SlideMotion`s.
struct SlideSpeed: Equatable {
  private(set) var speed = 0.0
  private var last: TimeInterval?

  /// Folds in one motion event and returns the smoothed speed (mm/s). Resting end reports (no
  /// travel) don't count as motion: they leave the speed as it was.
  mutating func update(_ motion: SlideMotion) -> Double {
    guard motion.deltaMM != 0 else { return speed }
    defer { last = motion.timestamp }
    guard let last, motion.timestamp > last, motion.timestamp - last <= SlideFeel.maxIntervalS else {
      // First motion (or after a pause): there is no interval yet. Treat it as one frame long.
      speed = abs(motion.deltaMM) / (1.0 / 120.0)
      speed = min(speed, SlideFeel.speedUpStartMMPerS)
      return speed
    }
    let dt = max(motion.timestamp - last, SlideFeel.minIntervalS)
    let instant = abs(motion.deltaMM) / dt
    let alpha = dt / (SlideFeel.speedSmoothingS + dt)
    speed += alpha * (instant - speed)
    return speed
  }
}

/// What one slide update did to a stepped action.
struct SlideStepResult: Equatable {
  /// Signed steps: + toward top/right.
  var steps: Int
  /// This update made the first step of an end-stepping run (earns a stronger click).
  var endStarted: Bool
}

/// Turns slide motion into whole steps with the shared feel: `stepMM` per step, speed-up, and end
/// stepping. Pure; one per slide (or per app switcher session, so short strokes keep their carry).
struct SlideStepper: Equatable {
  /// Travel per step, in the units `advance` is given (millimetres with a motion; normalized zone
  /// lengths in the legacy no-motion path).
  var step: Double
  var speedUp: Bool
  /// Travel toward the next step (signed), carried across updates and strokes.
  var carry = 0.0
  var speed = SlideSpeed()
  /// When the current end run started, and the last end report's time.
  private var endSince: TimeInterval?
  private var lastEnd: TimeInterval = 0
  /// Fractional end steps accumulated so far.
  private var endProgress = 0.0
  private var endStepped = false

  init(step: Double, speedUp: Bool) {
    self.step = step
    self.speedUp = speedUp
  }

  /// One update. `travel` is the travel since the last update in `step`'s units (scaled by the
  /// binding's sensitivity). `motion` (when the recognizer gave one) drives speed-up and end
  /// stepping; without it this is plain stepping, exactly the pre-batch-20 behaviour.
  mutating func advance(travel: Double, motion: SlideMotion?) -> SlideStepResult {
    guard let motion else { return SlideStepResult(steps: plain(travel), endStarted: false) }
    let speed = speed.update(motion)
    if motion.atEnd != 0 && motion.deltaMM == 0 {
      return endStep(toward: motion.atEnd, at: motion.timestamp)
    }
    endSince = nil
    let gain = speedUp ? SlideFeel.gain(speed: speed, maxGain: SlideFeel.steppedMaxGain) : 1
    return SlideStepResult(steps: plain(travel * gain), endStarted: false)
  }

  private mutating func plain(_ travel: Double) -> Int {
    let result = KeySteps.apply(travel: travel, step: step, carry: carry)
    carry = result.carry
    return result.presses
  }

  private mutating func endStep(toward side: Int, at time: TimeInterval) -> SlideStepResult {
    guard let since = endSince else {
      endSince = time
      lastEnd = time
      endProgress = 0
      endStepped = false
      return SlideStepResult(steps: 0, endStarted: false)
    }
    let dt = min(max(time - lastEnd, 0), SlideFeel.maxIntervalS)
    lastEnd = time
    endProgress += SlideFeel.endRate(after: time - since) * dt
    let whole = Int(endProgress.rounded(.down))
    guard whole > 0 else { return SlideStepResult(steps: 0, endStarted: false) }
    endProgress -= Double(whole)
    let first = !endStepped
    endStepped = true
    // End steps start from a clean carry: travel left over from the stroke must not add a step.
    carry = 0
    return SlideStepResult(steps: whole * (side > 0 ? 1 : -1), endStarted: first)
  }
}

/// Speed-up for level slides: the gentle gain, applied to the normalized delta.
struct LevelFeel: Equatable {
  var speed = SlideSpeed()

  /// `delta` with the level gain for `motion`'s speed; unchanged without a motion or with
  /// speed-up off (exactly the pre-batch-20 behaviour).
  mutating func scaled(_ delta: Double, motion: SlideMotion?, speedUp: Bool) -> Double {
    guard let motion else { return delta }
    let speed = speed.update(motion)
    guard speedUp else { return delta }
    return delta * SlideFeel.gain(speed: speed, maxGain: SlideFeel.levelMaxGain)
  }
}
