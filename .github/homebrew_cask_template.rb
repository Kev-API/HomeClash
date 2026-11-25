cask "homeclash" do
  version "VERSION"

  on_macos do
    arch arm: "arm64", intel: "amd64"

    sha256 arm:   "ARM_SHA256",
           intel: "AMD_SHA256"

    url "https://github.com/Kev-API/HomeClash/releases/download/v#{version}/HomeClash-#{version}-macos-#{arch}.dmg"
  end

  name "HomeClash"
  desc "Application-level egress policy for mihomo, a fork of FlClash"
  homepage "https://github.com/Kev-API/HomeClash"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  app "HomeClash.app"

  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-rd", "com.apple.quarantine", "{{appdir}}/HomeClash.app"],
        writable_paths: ["HomeClash.app"],
        writable_base:  :appdir
  end

  uninstall quit: "com.home.clash"

  zap trash: [
    "~/Library/Application Support/com.home.clash",
    "~/Library/Caches/com.home.clash",
    "~/Library/Preferences/com.home.clash.plist",
    "~/Library/Saved Application State/com.home.clash.savedState",
  ]
end
