cask "clipmoar" do
  version "1.7.1"
  sha256 "dc24644801286eb6dfdc16c38ff44de44ed1f16c2d3790627539793f989b85a1"

  url "https://github.com/noma4i/clipmoar/releases/download/v#{version}/ClipMoar.app.zip"
  name "ClipMoar"
  desc "Highly opinionated clipboard manager for macOS"
  homepage "https://github.com/noma4i/clipmoar"

  depends_on macos: ">= :sonoma"

  app "ClipMoar.app"

  zap trash: [
    "~/Library/Preferences/com.noma4i.ClipMoar.plist",
    "~/Library/Application Support/ClipMoar",
  ]
end
