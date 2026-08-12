# Kuati

Kuati is a tiny macOS menu-bar window manager. It watches the visible windows in
your current workspace, maximizes a window when it is alone, and distributes
multiple windows in an overlapping diagonal cascade at 90% of maximized size.

## First version

- Uses a compact native macOS menu with standard clickable items
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
