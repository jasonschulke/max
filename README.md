# Max

A menu bar utility that stretches the macOS Dock into a full-width bar. Max draws a Liquid Glass
(or blur) strip across the Dock's edge of the primary display, sized to the Dock itself, so the Dock
reads as one continuous bar instead of a floating pill.

Requires macOS 26 or later.

## Features

- **Liquid Glass** — the same material the Dock uses on macOS 26, with Clear Glass and classic
  blur materials as alternatives.
- **Sized from the Dock** — the bar matches the strip macOS reserves for the Dock and follows it
  when the Dock is resized, moved to another edge, or set to auto-hide. A manual height is available too.
- **Auto-hide aware** — when the Dock auto-hides, the bar slides in and out with it, using the Dock's
  own reveal delay. No Accessibility permission needed.
- **Tint** — flat or fading color wash over the material.
- **Rounded corners** — only the corners facing into the screen are rounded.
- **Global shortcut** — ⌃⌥⌘M toggles the bar from any app.
- **Light and dark** — the material adapts on its own.
- **Launch at login** via `SMAppService`.

## Building

### With Xcode 26

Open `Max.xcodeproj` and run the `Max` scheme. The `MaxTests` scheme runs the model tests.

### Without Xcode (Command Line Tools only)

```bash
make          # builds Max.app (universal, ad-hoc signed)
make test     # runs the model tests
make run      # builds and launches
make install  # copies Max.app to /Applications
```

`Max.app` is built in the repository root and is ignored by git.

## Usage

Max lives in the menu bar (the dock icon). The menu toggles the bar, opens Settings, and quits.

| Setting | What it does |
|---|---|
| Style | Liquid Glass, Clear Glass, or Blur (with a material picker) |
| Opacity | Whole-bar alpha |
| Corner radius | Rounds the inward-facing corners |
| Height | *Match Dock* follows the Dock's reserved strip, with an adjustment slider. *Custom* is an absolute height. |
| Tint | Color wash, with strength and an optional fade toward the screen |
| Animate changes | Fade and resize smoothly. Sliders always track the pointer without animation. |
| Follow the Dock when it auto-hides | Mirror the Dock's reveal. When off, the bar stays hidden while the Dock auto-hides. |
| Toggle with ⌃⌥⌘M | Enables the global shortcut |
| Launch at login | Registers Max as a login item |

Settings are stored as a single JSON value under `configuration` in `~/Library/Preferences/jasonschulke.Max.plist`.
Settings from Max 1.0 migrate automatically on first launch.

## How it works

- **Geometry** — the Dock's strip is the gap between `NSScreen.frame` and `NSScreen.visibleFrame`
  on the Dock's edge of the primary display (the screen whose origin is `0,0`). Orientation,
  auto-hide, and tile size come from the `com.apple.dock` preferences domain; Max refreshes on
  `com.apple.dock.prefchanged` and on screen-parameter changes.
- **Auto-hide** — while the Dock auto-hides, macOS reserves no strip, so the bar's thickness is
  estimated from the Dock's tile size (tile size + 13 pt, measured on macOS 26). A global
  mouse-moved monitor reveals the bar when the pointer touches the Dock's edge and dismisses it
  when the pointer leaves.
- **Window** — a borderless, click-through `NSWindow` one level below the Dock
  (`kCGDockWindowLevel - 1`), on every Space, stationary in Mission Control. It hangs
  `cornerRadius` points off the screen edge so only the inward corners show their radius.
- **Material** — `NSGlassEffectView` for the glass styles, `NSVisualEffectView` for blur. Tints go
  through the glass view's `tintColor`, or a gradient layer when fading.
- **State** — one `@Observable` store. The overlay controller consumes an `Observations` stream of
  the store, the Dock observer, and the reveal tracker, and applies each snapshot. Changes animate
  unless a slider is being dragged.

## Limitations

- The bar lives on the primary display. If the Dock is summoned on another display, the bar does
  not follow it.
- The auto-hide thickness is an estimate; use *Custom* height if it does not line up.
- The global shortcut is fixed at ⌃⌥⌘M.

## Project layout

```
Max/
├── App/        MaxApp (SwiftUI MenuBarExtra + Settings scene), AppDelegate
├── Models/     OverlayConfiguration, DockGeometry, RGBAColor — pure, tested
├── Services/   SettingsStore, DockObserver, DockRevealTracker, GlobalHotKey, LaunchAtLogin
├── Overlay/    OverlayWindow, OverlayBackdropView, OverlayController
├── Settings/   SettingsView
└── Resources/  Info.plist, Assets.xcassets
Tests/          Model tests with a small runner (no XCTest dependency)
Makefile        Command Line Tools build
```

## License

MIT — see `LICENSE`.
