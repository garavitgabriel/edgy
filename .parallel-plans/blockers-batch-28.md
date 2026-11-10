# Blockers: batch 28

Turn budget (60) reached. The code items (1 script, 2–6) are committed and the verification triple and denylist are green. What's left is waiting on a person, or on a new turn budget.

## Blocked on a person (live)
1. **"After" numbers.** These need the release build installed in place of the Edgy that's running. The brief says "Gabriel or the chief runs the live states". Steps are in `done-batch-28.md` § Needs Gabriel, all five states, each through `scripts/measure-idle.sh`.
2. **App chooser empty list.** Reproducing it and checking the fix means driving the live UI. Also time open-to-visible against the 300 ms budget; no test covers that, because the parallel test runner skews the timing.

## Left for the next session (needs a new turn budget)
3. A `sample Edgy 5` of any state still over budget: the "before" was 732 wakeups/s against a 50/s budget. Record which Apple-side cost remains.
4. Add-app (`AddAppView`) and the popover chips: lazy rows and off-main cached icons (`AppIconCache` is ready to reuse).
5. `/builder-close`.
