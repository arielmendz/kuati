# Kuati

Kuati is a tiny macOS menu-bar window manager. It watches the visible windows in
your current workspace, maximizes a window when it is alone, and distributes
multiple windows in an overlapping diagonal cascade. Two windows use 95% of
their maximized size; three or more use 90%.

## First version

- Uses a compact native macOS menu with standard clickable items
- Includes a custom two-window Kuati application icon
- Cascades the visible, movable windows on every display
- Maximizes a window when it is the only one in its workspace
- Keeps two windows at 95% and three or more at 90% of maximized size
- Animates window movement and resizing with a short eased transition
- Re-cascades automatically when windows are opened, closed, or moved between displays
- Can launch automatically when you log in to macOS
- Keeps the menu bar and Dock clear by using each display's visible workspace
- Lets you trigger the cascade manually
- Ignores minimized, full-screen, hidden, and non-resizable windows
- Filters out windows on other macOS Spaces

## Requirements

- macOS 13 or newer
- Swift 5.10 or newer (Xcode Command Line Tools is sufficient)
- Accessibility permission, requested on first launch

## Install with Homebrew

Kuati is distributed from this repository as a Homebrew Cask.

### Standard installation

```sh
brew tap arielmendz/kuati https://github.com/arielmendz/kuati.git
brew install --cask arielmendz/kuati/kuati
open /Applications/Kuati.app
```

### Installation without administrator access

Install the app in your user Applications directory when you cannot write to
`/Applications`:

```sh
mkdir -p "$HOME/Applications"
brew tap arielmendz/kuati https://github.com/arielmendz/kuati.git
brew install --cask --appdir="$HOME/Applications" arielmendz/kuati/kuati
open "$HOME/Applications/Kuati.app"
```

Use `$HOME/Applications`, not `~/Applications`, as the value of Homebrew's
[`--appdir`](https://docs.brew.sh/Manpage.html#global-cask-options) option. Some
shells preserve the tilde literally when it appears after `=`.

If Kuati was previously installed in another location, move the Homebrew-managed
installation with:

```sh
brew reinstall --cask --appdir="$HOME/Applications" kuati
```

### First launch

> [!IMPORTANT]
> Current releases are ad-hoc signed and are not notarized by Apple. Gatekeeper
> may block them even though Homebrew verifies the archive checksum. Do not
> disable Gatekeeper globally. A normal, warning-free installation requires a
> [Developer ID-signed and notarized](https://developer.apple.com/support/developer-id/)
> Kuati release.

When Kuati opens, its two-window icon appears in the menu bar. Complete the
one-time setup:

1. Select **Grant Accessibility Access** from the Kuati menu.
2. In **System Settings → Privacy & Security → Accessibility**, enable the exact
   Kuati copy you installed.
3. Return to Kuati and select **Check Accessibility Access**.
4. Optionally enable **Start at Login**. If macOS asks for approval, enable Kuati
   under **System Settings → General → Login Items**.

Because current releases use an ad-hoc signature, macOS may require Accessibility
access to be granted again after an upgrade. Developer ID signing will also fix
this upgrade experience by giving releases a stable signing identity.

### Upgrade and uninstall

Homebrew remembers the application directory used for the original install:

```sh
brew update
brew upgrade --cask kuati
brew uninstall --cask kuati
```

Disable **Start at Login** from the Kuati menu before uninstalling so macOS can
unregister the login item cleanly.

To also remove Kuati's saved preferences:

```sh
brew uninstall --cask --zap kuati
```

## Build and run

```sh
make test
make app
open build/Kuati.app
```

Kuati appears in the menu bar. On first launch, select **Grant Accessibility
Access**, enable Kuati in **System Settings → Privacy & Security → Accessibility**,
then return to Kuati and select **Check Again**.

Select **Start at Login** in the Kuati menu to have macOS launch the app on
subsequent logins. If macOS requires approval, Kuati opens **System Settings →
General → Login Items** so you can enable it there.

To copy it into Applications:

```sh
make install
```

For a non-administrator user:

```sh
make install APPDIR="$HOME/Applications"
```

The app is ad-hoc signed for local use. A distributable release can later replace
that step with Developer ID signing and notarization.

## Development

This repository uses Swift Package Manager and has no third-party dependencies:

```sh
swift build
make test
```

## Release

Releases are built as universal Apple Silicon and Intel applications. Update the
version in `support/Info.plist`, commit it, and push a matching tag:

```sh
git tag v0.1.3
git push origin v0.1.3
```

The release workflow tests the project, publishes `Kuati-<version>.zip`, and
updates the version and SHA-256 in `Casks/kuati.rb`.

Before Homebrew installation can provide a polished first-run experience, the
release workflow must sign Kuati with a stable Developer ID Application
certificate, enable the hardened runtime, submit the archive to Apple's notary
service, and staple the resulting ticket. After that is configured, verify each
release with `spctl` and remove the unsigned-release caveats from the Cask and
this README.

## License

Copyright © 2026 Ariel Mendez.

Kuati—including its source code, documentation, and project-owned icons and
assets—is licensed under the [GNU General Public License v3.0 only](LICENSE).
You may use, study, modify, distribute, and sell Kuati. If you distribute a
modified version or derivative work, you must make its corresponding source
available to its recipients under the same GPLv3 terms. Changes used only
privately or within an organization do not have to be published.

Contributions to this repository are accepted under `GPL-3.0-only`.
