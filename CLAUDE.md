# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Install

**Regenerate Xcode project** (required after editing `project.yml`):
```bash
xcodegen generate
```

**Build release and install locally:**
```bash
xcodebuild \
  -project DumbosRadio.xcodeproj \
  -scheme DumbosRadio \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$(pwd)/build" \
  build

# Re-sign with --deep after build (fixes Sparkle framework Team ID mismatch for ad-hoc signing)
codesign --force --deep --sign - "build/Not My First Radio.app"

# Use ditto, not cp -r — Sparkle.framework contains symlinks cp can't handle
rm -rf "/Applications/Not My First Radio.app" && ditto "build/Not My First Radio.app" "/Applications/Not My First Radio.app"
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

## Releasing

**Build DMG for distribution** (run after the release build above):
```bash
VERSION=1.x  # set this

create-dmg \
  --volname "Not My First Radio" \
  --volicon "DumbosRadio/Assets.xcassets/AppIcon.appiconset/icon_512.png" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "Not My First Radio.app" 140 190 \
  --hide-extension "Not My First Radio.app" \
  --app-drop-link 400 190 \
  "build/NotMyFirstRadio-${VERSION}.dmg" \
  "build/Not My First Radio.app"

codesign --force --sign - "build/NotMyFirstRadio-${VERSION}.dmg"

# Outputs edSignature + length — paste both into appcast.xml enclosure
SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/sparkle/Sparkle/bin/sign_update" 2>/dev/null | head -1)
"$SPARKLE_BIN" "build/NotMyFirstRadio-${VERSION}.dmg"

gh release upload "v${VERSION}" "build/NotMyFirstRadio-${VERSION}.dmg" --repo brainnews/nmfr --clobber
```

**`appcast.xml`** must be updated and pushed to `main` for Sparkle to detect the new version. The `SUFeedURL` is `https://raw.githubusercontent.com/brainnews/nmfr/main/appcast.xml`. The EdDSA private key is stored in Keychain under "Sparkle Key" — don't lose it.

**Critical:** In `appcast.xml`, `sparkle:version` must be the **`CFBundleVersion` integer** (e.g. `6`), not the marketing version string (e.g. `1.5`). Sparkle compares this against the installed app's `CFBundleVersion` to decide if an update is available. Using the marketing version string causes Sparkle to think the installed build number (e.g. `5`) is newer than the appcast version (e.g. `1.5`).

**`project.yml` owns `Info.plist`** — xcodegen regenerates it on every run. Always set `CFBundleShortVersionString` and `CFBundleVersion` in `project.yml`'s `info.properties` block, not directly in `Info.plist`.

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

### Auto-update (Sparkle)

`SPUStandardUpdaterController` is held as a stored property on `NMFRApp` and started on init. It checks `appcast.xml` on launch automatically. "Check for Updates…" in the app menu and About window both use `NSApp.sendAction(#selector(SPUStandardUpdaterController.checkForUpdates(_:)), to: nil, from: nil)` — this travels the responder chain to reach the controller without needing a direct reference.

Sparkle ships pre-signed with Apple's Team ID. Because the app uses ad-hoc signing, the `codesign --force --deep --sign -` step after build is required to re-sign Sparkle's embedded framework, XPC services, and Updater.app with a consistent identity. Skipping this causes a "damaged" Gatekeeper error on downloaded builds.

### Country display

`Station.country` stores raw API data which may be a full English name ("The United Kingdom...") from old saved data or a 2-letter ISO code from the current API. `Station.countryCode` (computed, with a static reverse-mapping cache built from `Locale`) normalises both to the ISO code for display. Always use `countryCode` in UI, not `country` directly.

### Search persistence

`StationBrowserView` uses a `ZStack` with `.opacity`/`.allowsHitTesting` rather than a `switch` to show/hide tabs. This keeps `SearchView` in the SwiftUI hierarchy when the My Stations tab is active, preserving its search results and scroll position.

### Key constraints

- `SWIFT_STRICT_CONCURRENCY: minimal` — concurrency warnings are suppressed. The audio tap callback has a benign data race with the main thread reading `latestWaveform`; this is intentional and safe on ARM64.
- App sandbox is enabled; entitlements: `network.client`, `files.user-selected.read-write`, and Sparkle's mach-lookup temporary exceptions (`com.miles.NotMyFirstRadio-spks` / `-spki`).
- Deployment target is macOS 13.0. Any API newer than 13.0 needs `#available` guards.
