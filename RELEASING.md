# Releasing

Dock Max ships outside the App Store as a DMG on GitHub Releases. For now it is signed with a self-signed
certificate, not an Apple Developer ID, so macOS asks users to approve it once per version (the README's
Install steps). Everything runs with the Command Line Tools.

## Once

1. **Create the signing certificate:** `Tools/make-signing-identity.sh`. It adds "Prep Work Code Signing" to
   your login keychain.
2. **Back it up.** In Keychain Access, find "Prep Work Code Signing" under My Certificates, export it as a
   .p12 with a password, and keep it with your other secrets. macOS ties each user's Accessibility access to
   this certificate. A release signed with a different one (a new certificate, or none) makes every user
   grant access again.

## Each release

1. Bump `VERSION` and `BUILD_NUMBER` in the `Makefile` (and `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`
   in the Xcode project). In `CHANGELOG.md`, give the version a date in place of "unreleased".
2. Build the DMG. This refuses to run without the certificate, and prints the DMG's SHA-256 at the end:

   ```bash
   make release
   ```

3. Check it: open `build.noindex/DockMax-<version>.dmg`, drag Dock Max to Applications, and open it.
4. Tag and publish, with that version's CHANGELOG section as the notes:

   ```bash
   git tag v<version> && git push origin v<version>
   gh release create v<version> build.noindex/DockMax-<version>.dmg --title "Dock Max <version>" --notes-file <notes>
   ```

## Later

- **Developer ID and notarization.** With the Apple Developer Program, macOS opens Dock Max without the
  approval steps. Create a *Developer ID Application* certificate, store notarization credentials with
  `xcrun notarytool store-credentials dockmax-notary --apple-id <you@example.com> --team-id <TEAMID>`, then
  `make notarized DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=dockmax-notary`
  and check it with `spctl --assess --type open --context context:primary-signature -v build.noindex/DockMax-<version>.dmg`.
  Switching certificates makes users grant Accessibility access once more, so mention it in that release's
  notes. Then update the README's Install steps.
- **Homebrew.** Homebrew's main cask repository no longer accepts apps that fail Apple's notarization
  check, and its own tap would still leave users with the approval steps, so wait for notarization. Then
  publish `Packaging/homebrew/dock-max.rb` from a `jasonschulke/homebrew-tap` repository with the DMG's
  `version` and `sha256`.
- **Automatic updates.** Add [Sparkle](https://sparkle-project.org): embed the framework, generate an
  EdDSA key, publish an appcast with each release, and add a "Check for Updates…" menu item.
- **CI.** Run `make test` on a GitHub Actions macOS runner with the macOS 26 SDK.
