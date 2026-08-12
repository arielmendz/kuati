import SwiftUI

@main
struct KuatiApp: App {
    @StateObject private var windowManager = WindowManager()

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

            Button("About Kuati") {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [
                        .applicationName: "Kuati",
                        .applicationVersion: "0.1.0",
                        .credits: NSAttributedString(
                            string: "A small, automatic cascading window manager for macOS."
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
