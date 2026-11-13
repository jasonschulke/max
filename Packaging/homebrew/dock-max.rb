# Template for a cask in jasonschulke/homebrew-tap, for once Dock Max is notarized (see RELEASING.md).
cask "dock-max" do
  version "2.0.0"
  sha256 "REPLACE_WITH_SHA256_OF_THE_DMG"

  url "https://github.com/jasonschulke/max/releases/download/v#{version}/DockMax-#{version}.dmg"
  name "Dock Max"
  desc "Full-width Dock"
  homepage "https://github.com/jasonschulke/max"

  depends_on macos: ">= :tahoe"

  app "Dock Max.app"

  zap trash: "~/Library/Preferences/co.prepwork.dockmax.plist"
end
