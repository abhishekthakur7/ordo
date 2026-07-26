# Ordo

A native macOS **menu bar** task tracker. Ordo lives as a glyph in the menu bar — no Dock icon, no app switcher entry. Click the glyph (or press **⌃⌥Space**) and a glass panel drops down with two lists: **Today** and **Horizon** (long-term). Unfinished tasks quietly carry over at each day boundary and visibly age; nothing is ever auto-deleted.

## Requirements

- macOS 14 or later (Apple Silicon or Intel)
- To build from source: Xcode 16+ command line tools (Swift 6 toolchain)

## Quick start

```sh
make run          # build the release bundle and launch it
make install      # build and copy Ordo.app into /Applications
```

After installing, launch **Ordo** from /Applications (Spotlight: "Ordo"). It appears only in the menu bar — look for the ordered-list glyph on the right side. On first launch Ordo asks once whether to open automatically at login.

## Build & test

| Command | What it does |
|---|---|
| `make build` | Debug build of all modules |
| `make test` | Full test suite (149 tests) |
| `make app` | Release build + assemble `dist/Ordo.app` (ad-hoc signed) |
| `make run` | `make app`, then open the bundle |
| `make install` | `make app`, then copy into /Applications |
| `make xcodebuild-check` | Build the `OrdoApp` scheme via xcodebuild |
| `make clean` | Remove build artifacts and `dist/` |

If a debug test run ever crashes with a segfault right after editing struct layouts, it is stale SwiftPM incremental state — run `make clean && make test`.

## Using Ordo

- **Summon**: click the menu bar glyph, or **⌃⌥Space** (rebindable in settings). Esc or click outside closes.
- **Add**: type in the field at the bottom, ⏎. Pasting multiple lines creates one task per line.
- **Complete**: click the checkbox. Unchecking works until the day rolls over; after that, completions are archived for good.
- **Keyboard**: ↑/↓ select · ⏎ edit · Space toggle done · ⌫ delete (10 s undo toast, no confirmation dialogs) · ⌘1/⌘2 tabs · ⌘E expand the planning view · ⌘N or `/` focus the add field.
- **Expand**: the arrows button (or ⌘E) morphs the panel into a wider planning view with a progress ring and day stats.
- **Aging & triage**: carried-over tasks show a subtle age marker (`2d`). At 7 days a quiet nudge offers *Move to Long-term · Keep · Delete* — you decide, Ordo never acts alone.
- **Settings**: gear in the panel footer — appearance (System/Light/Dark), sounds, summon hotkey, launch at login, day-start offset (for night owls: finishing at 1 a.m. can still count as "today"). Right-click the glyph for Settings/Quit.

## Data

Everything lives in plain, human-readable JSON:

```
~/Library/Application Support/Ordo/
├── store.json      # live tasks + semantic settings (agent/scriptable surface)
├── history/        # append-only monthly archives (feeds streaks/stats)
└── backups/        # daily rolling backups, last 7 days
```

Writes are atomic; a corrupted store is quarantined and auto-restored from the newest backup. Editing `store.json` externally is supported — the app reloads live.

## Project layout

```
Sources/
├── OrdoCore/     # pure Swift engine: models, task store, day rollover, persistence, stats
├── OrdoThemes/   # Theme protocol + the macOS theme (palettes, motion, sound recipes)
├── OrdoSound/    # AVAudioEngine playback of synthesized theme sounds
├── OrdoUI/       # SwiftUI panel interior
└── OrdoApp/      # AppKit shell: status item, panel window, hotkey, triggers
```

The V1 theme is **macOS** (vibrancy, SF type, spring physics, marimba confirmations). Four more art directions — Arcade, Zen Ink, Swiss, Instrument — are finalized in [REQUIREMENTS.md](REQUIREMENTS.md) and slot into the same Theme protocol. Mockups for all directions are in [`mockups/`](mockups/).
