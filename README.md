# Kuati

Kuati is a tiny macOS menu-bar window manager. It watches the visible windows in
your current workspace, maximizes a window when it is alone, and distributes
multiple windows in an overlapping diagonal cascade at 90% of maximized size.

## First version

- Uses a compact native macOS menu with standard clickable items
- Includes a custom two-window Kuati application icon
- Cascades the visible, movable windows on every display
- Maximizes a window when it is the only one in its workspace
- Keeps every window at 90% of maximized size when two or more are present
- Animates window movement and resizing with a short eased transition
- Re-cascades automatically when windows are opened, closed, or moved between displays
- Keeps the menu bar and Dock clear by using each display's visible workspace
- Lets you trigger the cascade manually
- Ignores minimized, full-screen, hidden, and non-resizable windows
- Filters out windows on other macOS Spaces

## Requirements

- macOS 13 or newer
- Swift 5.10 or newer (Xcode Command Line Tools is sufficient)
- Accessibility permission, requested on first launch

## Install with Homebrew

Kuati is distributed as a Homebrew Cask from this repository. The repository
and its GitHub release assets must be public for this unauthenticated install:

```sh
brew tap arielmendz/kuati https://github.com/arielmendz/kuati.git
brew install --cask arielmendz/kuati/kuati
open /Applications/Kuati.app
```

After opening Kuati, grant it access in **System Settings → Privacy & Security →
Accessibility**. Releases are currently ad-hoc signed, so macOS may require
Accessibility access to be enabled again after an upgrade.

Upgrade or uninstall with:

```sh
brew upgrade --cask kuati
brew uninstall --cask kuati
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

To copy it into Applications:

```sh
make install
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
git tag v0.1.1
git push origin v0.1.1
```

The release workflow tests the project, publishes `Kuati-<version>.zip`, and
updates the version and SHA-256 in `Casks/kuati.rb`.

## License

Copyright © 2026 Ariel Mendez.

Kuati—including its source code, documentation, and project-owned icons and
assets—is licensed under the [GNU General Public License v3.0 only](LICENSE).
You may use, study, modify, distribute, and sell Kuati. If you distribute a
modified version or derivative work, you must make its corresponding source
available to its recipients under the same GPLv3 terms. Changes used only
privately or within an organization do not have to be published.

Contributions to this repository are accepted under `GPL-3.0-only`.
