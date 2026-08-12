// SPDX-FileCopyrightText: 2026 Ariel Mendez
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Combine
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled = false

    private let service = SMAppService.mainApp

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = service.status == .enabled
    }

    func setEnabled(_ shouldEnable: Bool) {
        do {
            if shouldEnable {
                try enable()
            } else {
                try service.unregister()
            }
        } catch {
            present(error)
        }

        refresh()
    }

    private func enable() throws {
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }

        if service.status != .enabled {
            try service.register()
        }

        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func present(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "Unable to Change Start at Login"
        alert.informativeText = "Kuati could not update its login item. \(error.localizedDescription)"
        alert.runModal()
    }
}
