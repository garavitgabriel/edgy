# Blockers: batch 28

All code items (1–6) are committed, including add-app, chips and tabs (`AppMark`) through the icon cache. The verification triple and the denylist are green.

## Blocked on the chief / Gabriel (live; this session must not launch or quit Edgy, per the chief)
1. **"After" numbers with hands off.** Install this branch's release build (`scripts/bundle.sh` in the worktree, or after merge). Don't touch the trackpad. Run `scripts/measure-idle.sh` in each state:
   - no window: `0.5 50`
   - popover open: `3 150`
   - Settings open: `3 150`
   - Settings with the App chooser open: `3 150`
   - onboarding open: `3 150`

   What we have so far: wakeups went from 732/s to 0/s, but CPU could not be judged because the trackpad was in use (see done-batch-28.md). If a state is over budget, take `sample Edgy 5`. CPU from live touch frames redrawing an open mirror is a real change, not idle cost.
2. **App chooser on device.** Open Open App → "Choose an app". The list should appear within 300 ms (after "Loading apps…" if slow). Confirm the empty-list report is gone. It was not reproduced from this session.

`/builder-close` done (vault ee40142). Nothing else is open from this session.
