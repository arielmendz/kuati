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
            Image(systemName: "rectangle.3.group")
                .accessibilityLabel("Kuati")
        }
        .menuBarExtraStyle(.menu)
    }
}
