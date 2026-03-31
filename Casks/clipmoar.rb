cask "clipmoar" do
  version "1.4.0"
  sha256 "355864a56a2f8bf75c855ba608267769b1e574d43f8b5a40e2fdf95c577aeb1c"

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
