# This cask is auto-updated by the update-casks workflow (pipelines/fredtv/).
# Do not edit the version or sha256 lines manually.
cask "fredtv" do
  version "1.9.1"
  sha256 "7266c11cfafa9bc6b42835db6ab3ec3fd0a7516557f1f43eb867852563523465"

  url "https://github.com/engels74/homebrew-taps/releases/download/fredtv-latest/FredTV-#{version}.dmg"
  name "Fred TV"
  desc "Ultra-fast, simple and powerful cross-platform IPTV app"
  homepage "https://github.com/Fredolx/open-tv"

  depends_on :macos
  depends_on formula: "mpv"

  app "Fred TV.app"

  postflight do
    app_path = File.join(appdir, "Fred TV.app")

    ohai "Removing quarantine attribute from #{app_path}"
    system_command "/usr/bin/xattr",
                   args:         ["-r", "-d", "com.apple.quarantine", app_path],
                   sudo:         false,
                   must_succeed: false
  end

  zap trash: [
    "~/Library/Application Support/dev.fredol.open-tv",
    "~/Library/Caches/dev.fredol.open-tv",
    "~/Library/HTTPStorages/dev.fredol.open-tv",
    "~/Library/Preferences/dev.fredol.open-tv.plist",
    "~/Library/Saved Application State/dev.fredol.open-tv.savedState",
    "~/Library/WebKit/dev.fredol.open-tv",
  ]

  caveats <<~EOS
    Enjoying Fred TV? Remember to donate to the developer who builds it:
      GitHub Sponsors: https://github.com/sponsors/Fredolx
      PayPal:          https://paypal.me/fredolx
      Crypto:          https://github.com/Fredolx/open-tv#donate-crypto-thank-you
  EOS
end
