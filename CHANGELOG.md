# Changelog

## 2.0.0 — unreleased

A rewrite for macOS 26 and Liquid Glass.

- **Draw over the Dock.** Max covers Apple's Dock with a full-width bar and draws the Dock's icons,
  running indicators, and badges where the Dock draws them; the Dock still handles every click, menu,
  label, and drag. Needs Accessibility access; without it the bar sits behind the Dock.
- **Live details.** Launch bounces, today's date on Calendar, and a full Trash (with Full Disk
  Access). Running dots, badges, and bounces can each be turned off.
- **Size.** Dock size (resizes the Dock itself), icon size, and extra height with the icons centered.
- **Dock Items.** Rearrange, add, and remove the Dock's apps, folders, and spacers from Settings, with a
  backup of the original Dock. Profiles save arrangements to switch between from the menu bar.
- **Keep the Dock on one display.**
- **Window corners.** Set every app's window corner radius, down to square, with per-app exceptions.
- **Looks.** Liquid Glass, Clear Glass, Blur, or Solid, with color, opacity, and corner radius.
- **Settings** redesigned with a tab per area, a live preview, and light and dark themes.
- Follows the Dock across displays and when it auto-hides; ⌃⌥⌘M toggles the bar; launch at login.
- New app icon and menu bar icon.
- Settings from 1.0 migrate on first launch.

## 1.0.0

The first version: a blurred overlay behind the Dock with selectable materials, blending modes,
opacity, an optional color and gradient, and launch at login.
