cask "kuati" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/arielmendz/kuati/releases/download/v#{version}/Kuati-#{version}.zip"
  name "Kuati"
  desc "Automatically maximize or cascade windows in the current workspace"
  homepage "https://github.com/arielmendz/kuati"

  depends_on macos: :ventura

  app "Kuati.app"

  zap trash: "~/Library/Preferences/dev.arielmendez.kuati.plist"

  caveats do
    unsigned_accessibility
  end
end
