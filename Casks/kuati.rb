# SPDX-FileCopyrightText: 2026 Ariel Mendez
# SPDX-License-Identifier: GPL-3.0-only

cask "kuati" do
  version "0.1.1"
  sha256 "3c99ef1801134f0a785fc847a11b976062e7215eeb07248b4159157be523eaa0"

  url "https://github.com/arielmendz/kuati/releases/download/v#{version}/Kuati-#{version}.zip"
  name "Kuati"
  desc "Automatically maximize or cascade windows in the current workspace"
  homepage "https://github.com/arielmendz/kuati"

  depends_on macos: :ventura

  app "Kuati.app"

  zap trash: "~/Library/Preferences/dev.arielmendez.kuati.plist"

  caveats do
    unsigned_accessibility
    free_license "https://github.com/arielmendz/kuati/blob/main/LICENSE"
  end
end
