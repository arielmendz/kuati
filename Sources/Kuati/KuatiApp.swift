import SwiftUI

@main
struct KuatiApp: App {
    @StateObject private var windowManager = WindowManager()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(windowManager: windowManager)
        } label: {
            Image(systemName: "rectangle.3.group")
                .accessibilityLabel("Kuati")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuContent: View {
    @ObservedObject var windowManager: WindowManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.3.group.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Kuati")
                        .font(.headline)
                    Text(windowManager.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if windowManager.hasAccessibilityPermission {
                Button {
                    windowManager.arrangeNow()
                } label: {
                    Label("Cascade Windows", systemImage: "rectangle.stack")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)

                Toggle("Arrange automatically", isOn: $windowManager.isAutomatic)

                Label("1 fills the workspace; 2+ cascade at 90%", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Kuati needs Accessibility access to move and resize windows.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Grant Accessibility Access") {
                    windowManager.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)

                Button("Check Again") {
                    windowManager.refreshPermission()
                }
            }

            Divider()

            HStack {
                Button("About") {
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

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
