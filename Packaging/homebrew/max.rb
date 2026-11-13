# Template for the cask in your own tap (jasonschulke/homebrew-tap). Homebrew's main repository already
# has a "max" cask (Cycling '74), so publish this from the tap, or rename it with the app.
cask "max" do
  version "2.0.0"
  sha256 "REPLACE_WITH_SHA256_OF_THE_DMG"

  url "https://github.com/jasonschulke/max/releases/download/v#{version}/Max-#{version}.dmg"
  name "Max"
  desc "Full-width Dock for macOS"
  homepage "https://github.com/jasonschulke/max"

  depends_on macos: ">= :tahoe"

  app "Max.app"

  zap trash: "~/Library/Preferences/jasonschulke.Max.plist"
end
