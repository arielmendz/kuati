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
                    Label("Arrange Windows", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)

                Toggle("Arrange automatically", isOn: $windowManager.isAutomatic)

                HStack {
                    Text("Window gap")
                    Spacer()
                    Stepper(
                        "\(Int(windowManager.gap)) pt",
                        value: $windowManager.gap,
                        in: 0...32,
                        step: 2
                    )
                    .labelsHidden()
                    Text("\(Int(windowManager.gap)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
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
                                string: "A small, automatic workspace tiler for macOS."
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
