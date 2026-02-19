# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Install

**Regenerate Xcode project** (required after editing `project.yml`):
```bash
xcodegen generate
```

**Build release and install:**
```bash
xcodebuild \
  -project DumbosRadio.xcodeproj \
  -scheme DumbosRadio \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$(pwd)/build" \
  build

cp -r "build/Not My First Radio.app" /Applications/
```

**Debug build** (faster, for testing):
```bash
xcodebuild -project DumbosRadio.xcodeproj -scheme DumbosRadio -configuration Debug build
```

If `xcodebuild` fails with "requires Xcode", fix with:
```bash
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
```

There are no tests and no linter configured.

## Architecture

The app is a macOS 13+ SwiftUI internet radio player. The source lives entirely in `DumbosRadio/` (the directory name is legacy — the app is branded "Not My First Radio" / NMFR).

### State ownership

Two `@MainActor ObservableObject`s are injected at the root as `@EnvironmentObject` and flow down to every view:

- **`PersistenceManager`** (singleton) — all persisted state: station library, 6 preset slots, volume, mute, collapse state, preferences. Every `@Published` property auto-saves to `UserDefaults` via `didSet`. Station identity is always compared by `url`, not `id`.

- **`RadioPlayer`** — playback state machine (`idle / loading / playing / error`). Owns the `AVPlayer`, `AVPlayerItem`, and `AudioTapProcessor`. Only publishes `state` and `currentStation` — **not** waveform data (see Visualizer section below).

### Audio pipeline

`RadioPlayer.play()` attaches an `AVMutableAudioMixInputParameters` with **no track specified** (`trackID = kCMPersistentTrackID_Invalid`), which applies the tap to all audio tracks without needing to discover them first. This is what makes it work for ICY/Shoutcast/HLS streams where tracks aren't known upfront.

`AudioTapProcessor` runs entirely on the real-time audio thread using pre-allocated buffers (no heap allocation). It writes two shared arrays:
- `latestWaveform` — 128 signed float samples for the oscilloscope display
- `latestMagnitudes` — 64 peak-amplitude bins used only for signal-presence detection

### Visualizer (critical pattern — do not break)

`VisualizerView` takes a direct `RadioPlayer` reference and reads `player.currentWaveform` / `player.hasAudioSignal` **inside the `Canvas` closure**, which is re-executed every frame by `TimelineView(.animation(minimumInterval: 1/30))`.

This is intentional: waveform data is **not `@Published`**. Publishing it would fire `objectWillChange` 30×/sec and cause every view in the tree to re-render. The Canvas reads the values as plain properties on a reference type — SwiftUI doesn't observe them, but `TimelineView` drives the redraw anyway.

### Country display

`Station.country` stores raw API data which may be a full English name ("The United Kingdom...") from old saved data or a 2-letter ISO code from the current API. `Station.countryCode` (computed, with a static reverse-mapping cache built from `Locale`) normalises both to the ISO code for display. Always use `countryCode` in UI, not `country` directly.

### Search persistence

`StationBrowserView` uses a `ZStack` with `.opacity`/`.allowsHitTesting` rather than a `switch` to show/hide tabs. This keeps `SearchView` in the SwiftUI hierarchy when the My Stations tab is active, preserving its search results and scroll position.

### Key constraints

- `SWIFT_STRICT_CONCURRENCY: minimal` — concurrency warnings are suppressed. The audio tap callback has a benign data race with the main thread reading `latestWaveform`; this is intentional and safe on ARM64.
- App sandbox is enabled; only `network.client` and `files.user-selected.read-only` entitlements are granted.
- Deployment target is macOS 13.0. Any API newer than 13.0 needs `#available` guards.
