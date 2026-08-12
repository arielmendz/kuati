cask "kuati" do
  version "0.1.0"
  sha256 "dd6f2d0b1488a0266227163d10bf59e81027892f354e5a371574536c512f6a34"

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
