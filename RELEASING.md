# Releasing

Max ships outside the App Store: a Developer ID–signed, notarized DMG on GitHub Releases, plus a cask in
a Homebrew tap. Everything runs with the Command Line Tools.

## Before the first public release

1. **Settle the name.** "Max" collides with other software (Homebrew's `max` cask is Cycling '74's Max).
   If the name changes, update `APP_NAME` and `BUNDLE_ID` in the `Makefile`, the Xcode project's
   product name and bundle identifier, the README and its brand note, and the cask.
2. **Settle the bundle identifier.** Use reverse DNS, for example `com.jasonschulke.max`. Changing it
   later resets users' settings and permissions, so do it before release; to keep your own settings,
   copy them over once with `defaults export jasonschulke.Max - | defaults import <new id> -`.
3. **Join the Apple Developer Program** and create a *Developer ID Application* certificate (Xcode, or
   developer.apple.com → Certificates).
4. **Store notarization credentials** in the keychain:

   ```bash
   xcrun notarytool store-credentials max-notary --apple-id <you@example.com> --team-id <TEAMID>
   ```

## Each release

1. Bump `VERSION` and `BUILD_NUMBER` in the `Makefile` (and `MARKETING_VERSION` /
   `CURRENT_PROJECT_VERSION` in the Xcode project), and move the changes in `CHANGELOG.md` under the new
   version.
2. Build, sign with the hardened runtime, package, notarize, and staple:

   ```bash
   make release DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=max-notary
   ```

   This writes `build.noindex/Max-<version>.dmg`.
3. Check it: `spctl --assess --type open --context context:primary-signature -v build.noindex/Max-<version>.dmg`.
4. Tag and publish:

   ```bash
   git tag v<version> && git push origin v<version>
   gh release create v<version> build.noindex/Max-<version>.dmg --title "Max <version>" --notes-file <notes>
   ```

5. Update the cask in your tap (`jasonschulke/homebrew-tap`, starting from `Packaging/homebrew/max.rb`):
   set `version` and `sha256` (`shasum -a 256 build.noindex/Max-<version>.dmg`), then push.

## Later

- **Automatic updates.** Add [Sparkle](https://sparkle-project.org): embed the framework, generate an
  EdDSA key, publish an appcast with each release, and add a "Check for Updates…" menu item.
- **CI.** Run `make test` on a GitHub Actions macOS runner once one with the macOS 26 SDK is available.
