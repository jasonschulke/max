# Changelog

## 2.0.0 — 2026-11-13

A rewrite for macOS 26 and Liquid Glass, and a new name: Max is now Dock Max.

- **Draw over the Dock.** Dock Max covers Apple's Dock with a full-width bar and draws the Dock's icons,
  running indicators, and badges where the Dock draws them; the Dock still handles every click, menu,
  label, and drag. Needs Accessibility access; without it the bar sits behind the Dock.
- **Live details.** Launch bounces, today's date on Calendar, and a full Trash (with Full Disk
  Access). Running dots, badges, and bounces can each be turned off.
- **Size.** Dock size (resizes the Dock itself), icon size, and extra height with the icons centered.
- **Dock profiles.** Save the Dock's arrangement and switch between profiles from Settings or the menu
  bar; add spacers; restore the original Dock from a backup.
- **Keep the Dock on one display.**
- **Screen care.** Icons shift by a pixel every few minutes, and the bar can dim when you're idle, to
  avoid image retention from a bar that never moves.
- **Window corners.** Set every app's window corner radius, down to square, with per-app exceptions.
- **Looks.** Liquid Glass, Clear Glass, Blur, or Solid, with color, opacity, and corner radius.
- **Settings** redesigned: a 4:3 window with a dock of sections along the bottom, a live preview, and
  light and dark themes after the app icon.
- Follows the Dock across displays and when it auto-hides; ⌃⌥⌘M toggles the bar; launch at login.
- New app icon and menu bar icon.
- Settings from 1.0, and from builds under the old name, carry over on first launch.

## 1.0.0

The first version: a blurred overlay behind the Dock with selectable materials, blending modes,
opacity, an optional color and gradient, and launch at login.
