# Max

A menu bar utility that stretches the macOS Dock into a full-width bar. Max draws a Liquid Glass
(or blur) strip across the Dock's edge of the display it is on, sized to the Dock itself, so the Dock
reads as one continuous bar instead of a floating pill.

Requires macOS 26 or later.

## Features

- **Liquid Glass** — the same material the Dock uses on macOS 26, with Clear Glass and classic
  blur materials as alternatives.
- **Sized from the Dock** — the bar matches the strip macOS reserves for the Dock and follows it
  when the Dock is resized, moved to another edge, or set to auto-hide. Max can resize the Dock itself,
  and make the bar taller than the Dock with the icons kept centered.
- **Auto-hide aware** — when the Dock auto-hides, the bar slides in and out with it, using the Dock's
  own reveal delay. No Accessibility permission needed.
- **Color** — a Solid style or a material over the bar's color, with a flat or fading tint.
- **Rounded corners** — only the corners facing into the screen are rounded.
- **Draw over the Dock (optional)** — Max covers Apple's Dock and draws its icons, running indicators,
  and badges exactly where the Dock draws them, so no floating pill shows. The Dock still handles
  every click, menu, label, and drag, and Max follows it as it changes. Needs Accessibility access.
- **Live Dock details** — running indicators, badges, icons that bounce while apps launch, today's
  date on Calendar, and a full Trash (with Full Disk Access), each of which can be turned off.
- **Dock item editor and profiles** — reorder, add, and remove the Dock's apps, folders, and spacers
  from Max's settings, and save arrangements as profiles to switch between from the menu bar.
- **Window corners** — set the corner radius of every app's windows, down to square, with per-app
  exceptions, and relaunch open apps to apply it.
- **Keep the Dock on one display** — pin the Dock to a chosen display.
- **Global shortcut** — ⌃⌥⌘M toggles the bar from any app.
- **Light and dark** — the material adapts on its own.
- **Launch at login** via `SMAppService`.

## Building

### With Xcode 26

Open `Max.xcodeproj` and run the `Max` scheme. The `MaxTests` scheme runs the model tests.

### Without Xcode (Command Line Tools only)

```bash
make          # builds build.noindex/Max.app (universal; SIGN_IDENTITY=… picks the signing identity)
make test     # runs the model tests
make run      # builds and launches
make install  # copies Max.app to /Applications and refreshes its icon and Spotlight entry
```

`Max.app` is built in `build.noindex/` (ignored by git; Spotlight skips `.noindex` folders, so only the
installed copy shows up in search). The command-line build has no asset catalog compiler, so it ships
the icon as `Max.icns`; Xcode builds use the asset catalog. The app icon is drawn by
`swift Tools/make-icon.swift`, which writes `Max/Resources/Max.icns` and the asset catalog's PNGs.

macOS ties Accessibility and Full Disk Access to the app's signature, and an ad-hoc signature changes
with every build. `Tools/make-signing-identity.sh` creates a self-signed "Max Local Signing"
certificate in the login keychain; `make` signs with it whenever it exists, so access survives
rebuilds (`make SIGN_IDENTITY=…` picks another identity). Without it, Max clears its own stale
Accessibility entry and asks again at launch.

## Usage

Max lives in the menu bar. The menu toggles the bar, opens Settings, and quits. Settings has a tab per area:

| Tab | Settings |
|---|---|
| General | Show the bar, launch at login, animate changes, the ⌃⌥⌘M shortcut, reset to defaults |
| Dock | *Draw over the Dock* (with Accessibility status). *Dock size* resizes Apple's Dock itself; *Icon size* scales the icons Max draws; *Extra height* makes the bar taller than the Dock, icons kept centered (behind the Dock: *Match Dock* or *Custom* height). Running indicators (optionally marking the frontmost app), badges, launch bounces, and the full Trash icon. *Keep the Dock on* pins the Dock to one display. Follow the Dock when it auto-hides. |
| Appearance | A live preview; style (Liquid Glass, Clear Glass, Blur, Solid), opacity, and corner radius; a custom color with intensity and an optional fade toward the screen |
| Dock Items | The Dock's apps, folders, and spacers, with a miniature of the result. Drag to rearrange, add, and remove; *Save* writes them to the Dock and restarts it, and the first save keeps a backup you can restore. *Profiles* saves arrangements by name; switch between them here or from the menu bar. |
| Windows | The corner radius every app's windows use (macOS: 16 pt), down to *Square*, plus *Relaunch Finder* and *Relaunch Apps…* (which lists the apps and asks first). *Exceptions* give single apps their own radius. |
| About | Version and links |

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
- **Live details** — launches come from `NSWorkspace`'s will-launch and did-launch notifications; a
  launching app's icon hops into clear headroom above the bar until the launch finishes. Calendar's
  icon gets today's weekday and date drawn over its static grid. The Trash folder is watched with a
  file-system event source, which needs Full Disk Access.
- **Dock item editor** — edits `persistent-apps` and `persistent-others` in `com.apple.dock`, keeping
  the Dock's own entries intact, then restarts the Dock (`killall Dock`), as `dockutil` does.
- **Dock size** — set live through `CoreDockSetTileSize`, the private call System Settings uses, looked
  up at run time so the control simply disappears if a macOS update removes it. A Dock too full for the
  screen is already shrunk to fit its width, so it can only get smaller.
- **Keeping the Dock on a display** — macOS moves the Dock to whichever display's Dock edge the
  pointer is pushed against (with *Displays have separate Spaces* on). Max installs an event tap that
  stops the pointer two points short of that edge on every other display, except where another display
  continues past it, and drops the push. Needs Accessibility access.
- **Window corners** — AppKit reads the undocumented global default `NSConvolutionOverride1` as the
  window corner radius when an app launches (verified on macOS 27). Zero and negative values are
  ignored, so *Square* stores 0.01. Equivalent to `defaults write -g NSConvolutionOverride1 -float 0.01`;
  turning the setting off deletes the key. An exception writes the same key to one app's own domain,
  which takes precedence. Each app reads it once at launch for all its windows, so a window's radius
  cannot follow where the window is.
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
- Window corners rely on an undocumented macOS default; an update could change or drop it. Apps that
  draw their own window frames are not affected, and sandboxed apps (most App Store apps) read their
  settings from their own container, so per-app exceptions may not reach them.
- The full Trash icon needs Full Disk Access; without it the Trash always looks empty.
- Max cannot move the Dock to the pinned display itself (simulated pushes do not move it); push the
  pointer against that display's edge once, and Max keeps it there.
- The global shortcut is fixed at ⌃⌥⌘M.

## Project layout

```
Max/
├── App/        MaxApp (SwiftUI MenuBarExtra + Settings scene), AppDelegate
├── Models/     OverlayConfiguration, DockGeometry, DockSkin, DockPinning, WindowCornerRadius, RGBAColor — pure, tested
├── Services/   SettingsStore, DockObserver, DockSkinTracker, DockEditor, DockSize, DockPinner, TrashWatcher, WindowCornerOverride, DockRevealTracker, GlobalHotKey, LaunchAtLogin
├── Overlay/    OverlayWindow, OverlayBackdropView, OverlayController, DockSkinView
├── Settings/   SettingsView, DockEditorView
└── Resources/  Info.plist, Assets.xcassets, Max.icns
Tests/          Model tests with a small runner (no XCTest dependency)
Tools/          make-icon.swift draws the app icon; make-signing-identity.sh creates the signing certificate
Makefile        Command Line Tools build
```

## License

MIT — see `LICENSE`.
