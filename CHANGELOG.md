# Changelog

What changed for people using Edgy, newest first. Versions follow the git tags.

## Unreleased

### Added
- Key sequences: a Keyboard Shortcut can send up to four shortcuts one after another. Record the first, then press **Add another key**.
- Your own name and icon for any gesture, under **Name and Icon…** in a gesture's "…" menu.
- Last App: go back to the app you were in before.

### Changed
- Open App and Last App bring an app forward the way a click on its Dock icon does, so they also work from a full-screen app.
- Last App counts only apps that had a window on screen while they were in front.
- Edge labels with two actions read "A and B"; with more, "A and 2 more".

### Fixed
- Builds with only the Command Line Tools; Xcode is no longer required to build the app.
- The release build no longer crashes the Swift compiler on newer SDKs.
- Haptics play on the trackpad you touched, not the built-in one, when a Mac has two.
- The menu-bar popover stays under its icon when its height changes.
- After you grant Accessibility, Edgy restarts itself so volume and brightness show the system indicator straight away.
- Before the grant, volume and brightness slides show Edgy's own level plate instead of the old system indicator.
- Splitting an empty edge draws the parts, so "Add gesture…" works on each part.
- Launch no longer stalls for about 20 seconds with external monitors that don't answer brightness requests.

## 0.5.0

The first complete build: every edge and corner, per-app profiles, Test Mode, onboarding, and the settings window with the to-scale trackpad.
