# Max

A menu bar utility that stretches the macOS Dock into a full-width bar. Max draws a Liquid Glass
(or blur) strip across the Dock's edge of the display it is on, sized to the Dock itself, so the Dock
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
- **Draw over the Dock (optional)** — Max covers Apple's Dock and draws its icons, running indicators,
  and badges exactly where the Dock draws them, so no floating pill shows. The Dock still handles
  every click, menu, label, and drag, and Max follows it as it changes. Needs Accessibility access.
- **Dock item editor** — reorder, add, and remove the Dock's apps, folders, and spacers from Max's
  settings.
- **Global shortcut** — ⌃⌥⌘M toggles the bar from any app.
- **Light and dark** — the material adapts on its own.
- **Launch at login** via `SMAppService`.

## Building

### With Xcode 26

Open `Max.xcodeproj` and run the `Max` scheme. The `MaxTests` scheme runs the model tests.

### Without Xcode (Command Line Tools only)

```bash
make          # builds Max.app (universal, ad-hoc signed; SIGN_IDENTITY=… to sign with a certificate)
make test     # runs the model tests
make run      # builds and launches
make install  # copies Max.app to /Applications
```

`Max.app` is built in the repository root and is ignored by git.

macOS ties Accessibility access to the app's signature, and an ad-hoc signature changes with every
build, so after rebuilding, turn Max off and on again under System Settings › Privacy & Security ›
Accessibility (or sign with a stable identity: `make SIGN_IDENTITY="Apple Development: …"`).

## Usage

Max lives in the menu bar (the dock icon). The menu toggles the bar, opens Settings, and quits.

| Setting | What it does |
|---|---|
| Draw over the Dock | Covers Apple's Dock and draws its items where it draws them. Until Max has Accessibility access, the bar stays behind the Dock. |
| Dock items › Edit… | Reorder (drag), add (apps, folders, spacers), and remove the Dock's items. Apply restarts the Dock; the first Apply keeps a backup you can restore. |
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
  on the Dock's edge. The display whose strip is reserved is the Dock's display, so the bar follows
  the Dock between displays; while it auto-hides, the bar stays on the last display that reserved
  one (the primary display at first). Orientation,
  auto-hide, and tile size come from the `com.apple.dock` preferences domain; Max refreshes on
  `com.apple.dock.prefchanged` and on screen-parameter changes.
- **Auto-hide** — while the Dock auto-hides, macOS reserves no strip, so the bar's thickness is
  estimated from the Dock's tile size (tile size + 13 pt, measured on macOS 26). A global
  mouse-moved monitor reveals the bar when the pointer touches the Dock's edge and dismisses it
  when the pointer leaves.
- **Window** — a borderless, click-through `NSWindow` one level below the Dock
  (`kCGDockWindowLevel - 1`), on every Space, stationary in Mission Control. The window stays inside
  the screen; the material inside it runs `cornerRadius` points past the screen edge and is clipped
  there, so only the inward corners show their radius and nothing spills onto a neighboring display.
- **Drawing over the Dock** — Apple's Dock stays on, so macOS keeps reserving its strip and windows
  stop above it. Max's window moves one level above it (`kCGDockWindowLevel + 1`) but stays
  click-through, so the Dock still gets every click, hover, and drag. Max reads the Dock's items
  (position, size, URL, running state, badge) from its Accessibility tree and draws each icon where
  the Dock does, over an opaque base so the Dock never shows through. It re-reads the Dock when apps
  launch or quit, Dock preferences change, or displays change, a few times as the layout animates,
  and every 2 seconds for badges. While something is dragged in the Dock, the bar fades out so the
  Dock's own drag feedback shows.
- **Dock item editor** — edits `persistent-apps` and `persistent-others` in `com.apple.dock`, keeping
  the Dock's own entries intact, then restarts the Dock (`killall Dock`), as `dockutil` does.
- **Material** — `NSGlassEffectView` for the glass styles, `NSVisualEffectView` for blur. Tints go
  through the glass view's `tintColor`, or a gradient layer when fading.
- **State** — one `@Observable` store. The overlay controller consumes an `Observations` stream of
  the store, the Dock observer, and the reveal tracker, and applies each snapshot. Changes animate
  unless a slider is being dragged.

## Limitations

- While the Dock auto-hides, the bar cannot tell when the Dock moves to another display; it stays on
  the display the Dock last reserved space on.
- The auto-hide thickness is an estimate; use *Custom* height if it does not line up.
- Drawing over the Dock, Max shows each app's standard icon: live Dock tiles (Calendar's date,
  minimized-window thumbnails, launch bounces, magnification) stay under the bar. The Trash always
  looks empty.
- The global shortcut is fixed at ⌃⌥⌘M.

## Project layout

```
Max/
├── App/        MaxApp (SwiftUI MenuBarExtra + Settings scene), AppDelegate
├── Models/     OverlayConfiguration, DockGeometry, DockSkin, RGBAColor — pure, tested
├── Services/   SettingsStore, DockObserver, DockSkinTracker, DockEditor, DockRevealTracker, GlobalHotKey, LaunchAtLogin
├── Overlay/    OverlayWindow, OverlayBackdropView, OverlayController, DockSkinView
├── Settings/   SettingsView, DockEditorView
└── Resources/  Info.plist, Assets.xcassets
Tests/          Model tests with a small runner (no XCTest dependency)
Makefile        Command Line Tools build
```

## License

MIT — see `LICENSE`.
