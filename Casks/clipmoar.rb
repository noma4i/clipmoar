cask "clipmoar" do
  version "1.5.2"
  sha256 "92540a1027e4a00e4ee7606fde6abec27ad9c98e791194ca2527648561827e66"

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
