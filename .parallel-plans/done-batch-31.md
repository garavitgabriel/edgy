# Batch 31 — EDGY-PUBLIC: done

Branch `worktree-edgy-public`. Changed only the owned paths: `README.md`, `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, `.github/` (two issue templates, `config.yml`, PR template; no workflows), `docs/readme/` (4 images), and this file. No Swift changed.

## Build items

- [x] **1. README.md**: one line on what Edgy is, a hero (`<picture>`, light and dark), what it does (any zone → any action, per-app profiles, no misfires with real limits, Test Mode with "Don't run actions"), the default layout table (checked against `EdgyConfig.defaults` in `Sources/EdgyCore/Config.swift`), the two ways to get it (download at `DOWNLOAD_URL`, no price; build it yourself with macOS 14+, Swift 6.0+ from `swift-tools-version: 6.0`, `git clone`, `make app` as the batch 30 brief describes it, the trade-off), first run (Accessibility, why, what Edgy reads and doesn't), how it works (five lines from the `Package.swift` targets), three troubleshooting cases, the log command, the licence line.
- [x] **2. Images** in `docs/readme/` (4, each under 400 KB, resized with `sips`; no redraws):
  - `settings-light.png` / `settings-dark.png` ← `docs/design/build-shots/batch-27/window-identity-{light,dark}.png` (1100 px wide, 363 KB each)
  - `popover-dark.png` ← `batch-25/popover-last-touch-dark.png` (330 KB, unchanged)
  - `rejected-light.png` ← `batch-25/step2-rejected-light.png` (1000 px, 312 KB)
  - Only invented app names (Huddle, Wayfare) are visible in them.
- [x] **3. LICENSE**: MIT, `Copyright (c) 2026 Gabriel Garavit`. The name-and-icon note is in the README's Licence section, not in the licence.
- [x] **4. CONTRIBUTING.md**: build and the verification triple, formatting, the log command, the rules (protocols and mocks only in tests, units, private frameworks loaded at runtime, own work only, no other products' names, design spec), recording a trace (`scripts/record-traces.md`), what makes a good issue. It states the names rule without naming the denylist's contents (outsiders can't run it).
- [x] **5. `.github/`**: bug report (macOS version, Mac model, trackpad, Edgy version, steps, Test Mode plate, the log command, optional trace), feature request, `config.yml` (blank issues off, security link), PR template (the triple passed, tested by hand). `SECURITY.md` with the `SECURITY_CONTACT` placeholder.
- [x] **6. History scan**: below.

## Acceptance

- [x] README claims checked against the code on this branch (base `8fed0ef`):
  - the gesture/zone support matrix (`Zone.supports`);
  - the catalog (`docs/settings-reference.md`);
  - the limits: 18 mm palm, 500 ms typing, 6 mm swipe;
  - the plate strings (`PlateCopy.swift`), the broken-config sentence (`WindowEnvironment.swift`);
  - the config path (`ConfigStore.swift`), the log subsystem (`Logging.swift`);
  - what is read: `TypingActivity.swift` keeps only the time of the last key-down, and the recorder's listen-only tap runs only while recording.
  - I left out a "Turn back on" step for external displays: there is no UI control for it on `main`.
- [x] Commands: I ran `git clone`'s URL check (`git remote -v`), `swift build --product edgy-trace` (via the triple), and the log command. **Not run here, comes with batch 30:** `make app` (no `Makefile` on this branch yet). The README describes it exactly as the batch 30 brief specifies (output `build/release/Edgy.app`, development identity, else ad hoc, never installs or launches). Check that once batch 30 merges.
- [x] Relative links and images resolve (scripted check: every `](…)`, `src`/`srcset` and every `docs/…`/`scripts/…` path in the new files exists).
- [x] Denylist over the tree (`git grep -niE -f ~/.config/edgy-names-denylist`, with the new files staged): prints nothing.
- [x] Verification triple: `swift build && swift test && swift format lint --strict -r Sources Tests Package.swift` passes (303 tests in 42 suites).

## Placeholders and claims for the chief

| Where | What to fill or confirm |
|---|---|
| `README.md` § Download | `DOWNLOAD_URL` (appears twice: link text and target). No price is stated, on purpose. |
| `SECURITY.md` | `SECURITY_CONTACT`. Also confirm the "reply within a week" promise, or change it. |
| `README.md`, `.github/ISSUE_TEMPLATE/config.yml` | Clone/security URL `github.com/garavitgabriel/edgy` (from `git remote -v`). Change it if the public repo gets a different name or owner. |
| `README.md` § Build it yourself | The `make app` description: re-check it against batch 30's real `Makefile`. |
| `README.md` § Troubleshooting, first case | It says to remove and re-add Edgy in Accessibility after an ad hoc rebuild. Confirm that is the fix on device. |

## History scan (counts and hashes only)

The denylist was run over every commit's message and its diff, separately (`git rev-list` plus `grep -qiE -f`; no matched text printed anywhere).

| Scope | Commits | `git log -p` matching lines | Messages that match | Diffs that match |
|---|---|---|---|---|
| `--all` | 317 | 7 | 1: `075d1fac` | 4: `2f3f9c6d`, `437c788b`, `1b2b9cc4`, `75f530b9` |
| `main` (what would publish) | 294 | 7 | 1: `075d1fac` | 4: `2f3f9c6d`, `437c788b`, `1b2b9cc4`, `75f530b9` |

All the hits are reachable from `main`, so publishing the existing history publishes them.

### Other things that shouldn't go public as-is

- **`.parallel-plans/release-plan-v1.md`** states the price, the payment provider and setup, a private vault path, and the Apple Developer decision.
- **`.parallel-plans/CHIEF-HANDOFF-2026-11-07.md`, `backlog.md`, the dated `2026-11-0*-edgy-v0*.md` plans** are private working notes. They include vault paths and the business plan.
- **16 `done-batch-*.md` files** contain absolute `/Users/…` home paths (5–13, 16–18, 20, 23, 24, 26). `Tests/ActionsTests/PickerTests.swift` uses `/Users/me/…`, which is a fake fixture and fine.
- **`docs/BRIEF.md`** names the owner-private design canvas. That's harmless, but it points at something outsiders can't open.
- **Commit author email:** all 317 commits use one personal gmail address. Use a `noreply` address in the public repo if that matters.
- The `$5|Stripe|vault` grep also hit four PNGs under `docs/design/build-shots/`. Those are coincidental byte matches in binary data, not text.

### Recommendation

**Start the public repo from a clean first commit.** Keep the private repo, with its full history, as the working repo. Its history has denylist hits on `main` (1 message, 4 diffs), and the price, payment and vault notes run through many commits. Scrubbing that would mean rewriting history, which this batch must not do and which would break every worktree.

Suggested shape (chief, on `main`, not done here):
1. Export a tree without `.parallel-plans/` and without `docs/design/canvas-prompts-*` if you'd rather not publish the sprint prompts.
2. Run the denylist and a `/Users/` grep on that tree.
3. Make one commit in a new public repo with a `noreply` author.
4. Push future releases from the private repo to it, as squashed or cherry-picked commits.
