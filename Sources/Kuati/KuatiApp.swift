// SPDX-FileCopyrightText: 2026 Ariel Mendez
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

@main
struct KuatiApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var windowManager = WindowManager()
    @StateObject private var loginItemManager = LoginItemManager()

    var body: some Scene {
        MenuBarExtra {
            if windowManager.hasAccessibilityPermission {
                Button("Cascade Windows") {
                    windowManager.arrangeNow()
                }

                Toggle("Arrange Automatically", isOn: $windowManager.isAutomatic)
            } else {
                Button("Grant Accessibility Access") {
                    windowManager.requestAccessibilityPermission()
                }

                Button("Check Accessibility Access") {
                    windowManager.refreshPermission()
                }
            }

            Divider()

            Toggle(
                "Start at Login",
                isOn: Binding(
                    get: { loginItemManager.isEnabled },
                    set: { loginItemManager.setEnabled($0) }
                )
            )

            Divider()

            Button("About Kuati") {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [
                        .applicationName: "Kuati",
                        .credits: NSAttributedString(
                            string: "A small, automatic cascading window manager for macOS.\n\nLicensed under GNU GPLv3."
                        )
                    ]
                )
            }

            Divider()

            Button("Quit Kuati") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("Kuati")
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                loginItemManager.refresh()
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

private enum MenuBarIcon {
    /// A template image lets macOS apply the correct monochrome menu-bar tint
    /// for light mode, dark mode, selection, and increased contrast.
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(rect: NSRect(x: 2, y: 6, width: 9, height: 8)).fill()
            NSBezierPath(rect: NSRect(x: 5, y: 2, width: 9, height: 8)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
