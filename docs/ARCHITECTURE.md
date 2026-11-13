# How Dock Max works

## Placing the bar

- **Geometry.** The Dock's strip is the gap between `NSScreen.frame` and `NSScreen.visibleFrame` on the
  Dock's edge; the display that reserves it is the Dock's display. Orientation, auto-hide, and tile size
  come from the `com.apple.dock` preferences domain. Dock Max refreshes on `com.apple.dock.prefchanged` and on
  screen-parameter changes.
- **Window.** A borderless, click-through `NSWindow` on every Space, stationary in Mission Control. Behind
  the Dock it sits at `kCGDockWindowLevel - 1`; drawing over it, at `kCGDockWindowLevel + 1`. The window
  stays inside its screen. The material runs `cornerRadius` points past the screen edge and is clipped
  there, so only the inward corners show their radius.
- **Auto-hide.** macOS reserves no strip for an auto-hiding Dock, so the bar's thickness is estimated
  from the tile size (tile size + 13 pt). A global mouse monitor reveals the bar when the pointer reaches
  the Dock's edge and dismisses it when the pointer leaves.
- **Material.** `NSGlassEffectView` for the glass styles, `NSVisualEffectView` for blur. Drawing over
  the Dock, the material sits on an opaque base so the Dock never shows through.

## Drawing over the Dock

Apple's Dock stays on, so macOS keeps reserving its strip. Dock Max reads the Dock's items (position, size,
URL, running state, badge) from its Accessibility tree and draws each icon where the Dock does, centered
across the bar. Its window stays click-through, so the Dock gets every click, hover, and drag.

- **Keeping current.** Dock Max re-reads the Dock when apps launch or quit, Dock preferences change, or
  displays change, several times as the layout animates, and every 2 seconds for badges. It finds the
  Dock again after a restart.
- **Where the Dock really is.** The Dock can sit on another display, or hidden below an edge, while a
  strip stays reserved. Dock Max reads the frame of the Dock's whole list and hides the bar while the Dock
  isn't on its display.
- **Drags.** While something is dragged in the Dock (reordering, dropping files), the bar fades out so
  the Dock's own feedback shows.
- **Live details.** Launches come from `NSWorkspace`'s will-launch and did-launch notifications; a
  launching app's icon hops into clear headroom above the bar. Calendar's icon gets today's weekday and
  date drawn over its static grid. The Trash folder is watched with a file-system event source, which
  needs Full Disk Access.
- **Icon geometry.** Measured on macOS 26 and 27: the Dock draws an icon image at 96.25% of its slot's
  length, and macOS app icons fill 80.5% of their image.

## Screen care

A bar that never moves holds the same high-contrast edges for hours, which leaves image retention on
LCDs (and burn-in on OLEDs). Dock Max shifts everything it draws over the Dock around a two-point square, one
step every three minutes. Dimming darkens the bar with an opaque overlay after the configured idle time,
read from `CGEventSource.secondsSinceLastEventType` once a second.

## Changing the Dock

- **Profiles and spacers.** A profile is a saved copy of `persistent-apps` and `persistent-others` in
  `com.apple.dock`, the Dock's own entries kept intact. Using one, or adding a spacer, writes the lists
  back and restarts the Dock (`killall Dock`), as `dockutil` does. The first write keeps a backup of the
  original Dock.
- **Dock size.** Set live through `CoreDockSetTileSize`, the private call System Settings uses, looked up
  at run time so the control disappears if a macOS update removes it.
- **Keeping the Dock on a display.** macOS moves the Dock to whichever display's Dock edge the pointer is
  pushed against (with *Displays have separate Spaces* on). An event tap stops the pointer two points
  short of that edge on every other display, except where another display continues past it.

## Window corners

AppKit reads the undocumented global default `NSConvolutionOverride1` as the window corner radius when
an app launches (verified on macOS 27). Zero and negative values are ignored, so *Square* stores 0.01.
It's the same as `defaults write -g NSConvolutionOverride1 -float 0.01`; turning the setting off
deletes the key. An exception writes the key to one app's own domain, which takes precedence. Each app
reads it once at launch for all its windows.

## State

One `@Observable` settings store, saved as a JSON value under `configuration` in Dock Max's preferences.
The overlay controller consumes an `Observations` stream of the store, the Dock observer, the Dock
reader, and the reveal tracker, and applies each snapshot to the window. Settings from Max 1.0 migrate
on first launch.

## Project layout

```
Max/
├── App/        MaxApp (menu bar extra + Settings scene), AppDelegate
├── Models/     Pure, tested: OverlayConfiguration, DockGeometry, DockSkin, DockPinning, WindowCornerRadius, RGBAColor
├── Services/   SettingsStore, DockObserver, DockSkinTracker, DockProfiles, DockSize, DockPinner, TrashWatcher, IdleWatcher,
│               WindowCornerOverride, DockRevealTracker, GlobalHotKey, LaunchAtLogin
├── Overlay/    OverlayWindow, OverlayBackdropView, OverlayController, DockSkinView
├── Settings/   SettingsView (with its section dock), DockProfilesView
└── Resources/  Info.plist, Assets.xcassets, Max.icns
Tests/          Model tests with a small runner (no XCTest needed)
Tools/          make-icon.swift draws the app icon; make-signing-identity.sh creates a local signing certificate
Packaging/      Homebrew cask template
Makefile        Command Line Tools build, DMG, and release
```
