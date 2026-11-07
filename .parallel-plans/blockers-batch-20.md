# Blockers — batch 20 (EDGY-FEEL)

## 1. The recognizer can't tell which zones have a swipe bound (`GestureContext`, frozen)

**Brief item 6:** "make the swipe threshold stricter on such edges" (an edge with both a slide and a swipe).

**What I did instead (no contract change):** the stricter threshold (260 mm/s and 9 mm instead of
180 mm/s and 6 mm, `Tuning.slideZoneFlickSpeedMMPerS` / `slideZoneSwipeMinTravelMM`) applies on
**every zone the context names in `slideZones`**, not only those that also have a swipe. On a
slide-only zone that is the right call anyway (a quick flick there should drive the slide with
speed-up, and the router drops a swipe nobody bound), so nothing is lost.

**What a contract change would buy:** with `GestureContext.swipeZones: Set<Zone>?` (nil = every
enabled zone may swipe), a slide-only zone could **never** divert to a swipe candidate (every flick
stays a slide, at any speed), and only slide + swipe zones would pay the stricter threshold.

**Proposed change on `main` (chief):**
```swift
/// Zones with a swipe bound (any direction). `nil` = every enabled zone may swipe.
public var swipeZones: Set<Zone>?
```
plus the init parameter (defaulted `nil`), and `Engine.handle` passing
`zones(bound:)` for every `.swipe(_)` kind. The Gestures change after that is two lines in
`advancePendingEdge` / `finish`.

Not blocking: everything else in batch 20 is done.
