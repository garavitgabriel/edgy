# Contributing to Edgy

Thanks for helping. Edgy aims to be the best-feeling app of its kind, and that depends on two things more than on a long action list: you can map any zone to any action, and nothing fires by accident. Changes are judged against both.

## Build and check

You need macOS 14 or later and a Swift 6.0 or later toolchain.

```bash
swift build && swift test && swift format lint --strict -r Sources Tests Package.swift
```

All three must pass before a pull request is reviewed. To fix formatting, run `swift format format -i -r` over the folders you changed (formatting settings are in `.swift-format`). To build the app bundle, run `make app` (see the [README](README.md#build-it-yourself)).

Edgy logs under the subsystem `com.garavit.edgy`, one category per module:

```bash
/usr/bin/log show --last 10m --predicate 'subsystem == "com.garavit.edgy"' --info
```

Use the full path to `log`; zsh has a built-in with the same name.

## Rules

- **Tests never touch your real system.** Volume, brightness, mute, media keys, the on-screen indicator, haptics, Shortcuts, event taps and the cursor each sit behind a protocol. Tests use mocks only. A test that changes the volume of the Mac it runs on is a bug.
- **Units.** Gesture geometry is in millimetres (the sensor size comes from the device), time in settings is in milliseconds, and timestamps are in seconds.
- **Private system frameworks** are loaded at runtime by name, never linked, and every failed lookup degrades gracefully with a logged reason.
- **Your own work only.** Other open-source code can teach you how something works. Don't copy or port it; write it fresh.
- **No other products' names.** Not in code, comments, docs, commit messages or screenshots. Describe what a thing does instead ("a third-party display", "the system's app switcher"). Apple's own system names, such as macOS, Accessibility, Shortcuts and Mission Control, are fine.
- **Design.** UI, copy and icon changes follow `docs/BRIEF.md` § Design. Use the exported glyph and icon in `docs/design/assets/`; never redraw them.

## Record a touch trace

A misfire you can replay is a misfire we can fix and keep fixed. `edgy-trace` records what the trackpad reported, as JSON, without running any action. `scripts/record-traces.md` walks through it; the short version:

```bash
swift build --product edgy-trace
swift run edgy-trace devices
swift run edgy-trace record --label my-misfire --seconds 6 --out my-misfire.json \
  --expect "What you did, and what Edgy should have done."
```

Attach the file to the issue. It holds your label and description, the trackpad's model and size, and finger positions and timings, nothing else.

## A good issue

- One problem per issue.
- What you did, what happened and what you expected, in that order.
- For a gesture: what the Test Mode plate said.
- Your macOS version, Mac model, trackpad and Edgy version.
- The log from the command above, and a trace if it's a misfire.

The issue templates ask for all of this.
