# SPDX-FileCopyrightText: 2026 Ariel Mendez
# SPDX-License-Identifier: GPL-3.0-only

cask "kuati" do
  version "0.1.3"
  sha256 "5ebace050909378f638db6a1065725f08b20a2cf5e21d8ce07df2795baf7e0d5"

  url "https://github.com/arielmendz/kuati/releases/download/v#{version}/Kuati-#{version}.zip"
  name "Kuati"
  desc "Automatically maximize or cascade windows in the current workspace"
  homepage "https://github.com/arielmendz/kuati"

  depends_on macos: :ventura

  app "Kuati.app"

  uninstall quit: "dev.arielmendez.kuati"

  zap trash: "~/Library/Preferences/dev.arielmendez.kuati.plist"

  caveats do
    unsigned_accessibility
    free_license "https://github.com/arielmendz/kuati/blob/main/LICENSE"
  end
  caveats <<~EOS
    Kuati is currently ad-hoc signed and not notarized by Apple. Gatekeeper may
    block it from opening. Do not disable Gatekeeper globally. See the first-run
    instructions at:
      https://github.com/arielmendz/kuati#first-launch
  EOS
end
