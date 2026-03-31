cask "clipmoar" do
  version "1.5.0"
  sha256 "44ea6d5f775b621aeaf583d354797cf9756544e804504947efe26d0b96ab021c"

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
