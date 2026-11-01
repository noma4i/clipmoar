cask "clipmoar" do
  version "1.8.0"
  sha256 "a429c884cc40d01c53c6bad8977e6bdc0cac4e246060a645859dd64a12d5724a"

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
