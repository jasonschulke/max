# Contributing

Thanks for helping out. Bug reports, fixes, and ideas are all welcome.

## Reporting a bug

Max leans on how macOS lays out the Dock, so the details of your setup matter. Please include your macOS
version, your displays and their arrangement, your Dock settings (position, size, auto-hide,
magnification), and whether *Draw over the Dock* is on. A screenshot helps a lot.

## Building and testing

You need macOS 26 and either Xcode 26 or the Command Line Tools.

```bash
make test     # model tests
make run      # build and launch
```

Run `Tools/make-signing-identity.sh` once so rebuilds keep Max's Accessibility access.

## Code

- Match the code around you: its naming, comment style, and structure.
- Geometry and parsing go in `Max/Models` as pure functions, with tests in `Tests/`. Code that talks to
  the system goes in `Max/Services`.
- Anything undocumented (private calls, preferences, Dock layout measurements) needs a fallback for when
  a macOS update changes it, and a note on which macOS version it was measured on.
- The model tests use a small runner instead of XCTest, so they run with just the Command Line Tools.

## License

Contributions are released under the MIT license, like the rest of the code. The Max name and icon
stay reserved; see the README.
