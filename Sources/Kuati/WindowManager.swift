// SPDX-FileCopyrightText: 2026 Ariel Mendez
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import ApplicationServices
import Combine
import KuatiCore

@MainActor
final class WindowManager: ObservableObject {
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var statusText = "Checking permissions…"
    @Published var isAutomatic: Bool = true {
        didSet {
            UserDefaults.standard.set(isAutomatic, forKey: Self.automaticDefaultsKey)
            if isAutomatic { arrangeNow() }
        }
    }

    private static let automaticDefaultsKey = "automaticArrangement"
    private static let animationSteps = 16
    private static let animationFrameNanoseconds: UInt64 = 16_666_667

    private var timer: Timer?
    private var animationTask: Task<Void, Never>?
    private var previousWindowSignature = ""

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.automaticDefaultsKey) != nil {
            isAutomatic = defaults.bool(forKey: Self.automaticDefaultsKey)
        }

        refreshPermission()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollWorkspace()
            }
        }
    }

    func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
        updateStatus(windowCount: nil)
    }

    func refreshPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        updateStatus(windowCount: nil)
        if hasAccessibilityPermission, isAutomatic {
            arrangeNow()
        }
    }

    func arrangeNow() {
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            return
        }

        let windows = currentWorkspaceWindows()
        arrange(windows)
        previousWindowSignature = signature(for: windows)
        updateStatus(windowCount: windows.count)
    }

    private func pollWorkspace() {
        let permission = AXIsProcessTrusted()
        if permission != hasAccessibilityPermission {
            hasAccessibilityPermission = permission
            updateStatus(windowCount: nil)
        }

        guard permission, isAutomatic else { return }
        let windows = currentWorkspaceWindows()
        let newSignature = signature(for: windows)
        guard newSignature != previousWindowSignature else { return }

        arrange(windows)
        previousWindowSignature = newSignature
        updateStatus(windowCount: windows.count)
    }

    private func arrange(_ windows: [ManagedWindow]) {
        let screens = ScreenGeometry.currentScreens()
        var transitions: [ManagedWindowTransition] = []

        for screen in screens {
            let screenWindows = windows
                .filter { screen.frame.contains($0.frame.center) }
                .sorted(by: ManagedWindow.cascadeOrder)
            let targetFrames = LayoutPlanner.frames(
                in: screen.visibleFrame,
                count: screenWindows.count
            )

            transitions.append(contentsOf: zip(screenWindows, targetFrames).map {
                ManagedWindowTransition(window: $0.0, targetFrame: $0.1)
            })
        }

        animate(transitions)
    }

    private func animate(_ transitions: [ManagedWindowTransition]) {
        animationTask?.cancel()
        guard !transitions.isEmpty else { return }

        animationTask = Task { @MainActor [weak self] in
            for step in 1...Self.animationSteps {
                guard !Task.isCancelled else { return }
                let progress = CGFloat(step) / CGFloat(Self.animationSteps)

                for transition in transitions {
                    transition.window.set(
                        frame: FrameInterpolator.easeOut(
                            from: transition.window.frame,
                            to: transition.targetFrame,
                            progress: progress
                        )
                    )
                }

                guard step < Self.animationSteps else { continue }
                do {
                    try await Task.sleep(nanoseconds: Self.animationFrameNanoseconds)
                } catch {
                    return
                }
            }

            self?.animationTask = nil
        }
    }

    private func currentWorkspaceWindows() -> [ManagedWindow] {
        let visibleWindows = OnScreenWindowSnapshot.capture()
        let ownPID = ProcessInfo.processInfo.processIdentifier

        return NSWorkspace.shared.runningApplications
            .filter {
                $0.processIdentifier != ownPID &&
                    $0.activationPolicy == .regular &&
                    !$0.isHidden &&
                    !$0.isTerminated
            }
            .flatMap { application in
                ManagedWindow.windows(
                    for: application.processIdentifier,
                    visibleWindows: visibleWindows
                )
            }
    }

    private func signature(for windows: [ManagedWindow]) -> String {
        windows
            .sorted(by: ManagedWindow.cascadeOrder)
            .map { "\($0.pid):\($0.title):\(ScreenGeometry.screenIndex(containing: $0.frame.center))" }
            .joined(separator: "|")
    }

    private func updateStatus(windowCount: Int?) {
        guard hasAccessibilityPermission else {
            statusText = "Accessibility access required"
            return
        }
        if let windowCount {
            statusText = windowCount == 1 ? "1 window maximized" : "\(windowCount) windows cascaded"
        } else {
            statusText = isAutomatic ? "Watching this workspace" : "Ready"
        }
    }
}

private struct ManagedWindowTransition {
    let window: ManagedWindow
    let targetFrame: CGRect
}

private struct ManagedWindow {
    let element: AXUIElement
    let pid: pid_t
    let title: String
    let frame: CGRect
    let frontToBackIndex: Int

    static func windows(
        for pid: pid_t,
        visibleWindows: [OnScreenWindowSnapshot]
    ) -> [ManagedWindow] {
        let application = AXUIElementCreateApplication(pid)
        guard let windowElements: [AXUIElement] = application.value(for: kAXWindowsAttribute) else {
            return []
        }

        let visibleForApplication = visibleWindows.filter { $0.pid == pid }

        return windowElements.compactMap { element in
            guard
                element.boolValue(for: kAXMinimizedAttribute) != true,
                element.boolValue(for: "AXFullScreen") != true,
                element.isSettable(kAXPositionAttribute),
                element.isSettable(kAXSizeAttribute),
                let position: CGPoint = element.value(for: kAXPositionAttribute),
                let size: CGSize = element.value(for: kAXSizeAttribute),
                size.width >= 80,
                size.height >= 60
            else { return nil }

            let frame = CGRect(origin: position, size: size)
            let title: String = element.value(for: kAXTitleAttribute) ?? ""
            guard let snapshot = visibleForApplication.first(where: {
                $0.matches(frame: frame, title: title)
            }) else {
                return nil
            }

            return ManagedWindow(
                element: element,
                pid: pid,
                title: title,
                frame: frame,
                frontToBackIndex: snapshot.frontToBackIndex
            )
        }
    }

    static func cascadeOrder(_ lhs: ManagedWindow, _ rhs: ManagedWindow) -> Bool {
        if lhs.frontToBackIndex != rhs.frontToBackIndex {
            return lhs.frontToBackIndex < rhs.frontToBackIndex
        }
        if lhs.pid != rhs.pid { return lhs.pid < rhs.pid }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    func set(frame: CGRect) {
        element.setValue(frame.origin, for: kAXPositionAttribute)
        element.setValue(frame.size, for: kAXSizeAttribute)
        // Some applications constrain size based on the old position. A second
        // position write makes the requested frame settle consistently.
        element.setValue(frame.origin, for: kAXPositionAttribute)
    }
}

private struct OnScreenWindowSnapshot {
    let pid: pid_t
    let title: String
    let frame: CGRect
    let frontToBackIndex: Int

    static func capture() -> [OnScreenWindowSnapshot] {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        return rawWindows.enumerated().compactMap { index, info in
            guard
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0,
                let pidValue = info[kCGWindowOwnerPID as String] as? Int,
                let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                let x = bounds["X"],
                let y = bounds["Y"],
                let width = bounds["Width"],
                let height = bounds["Height"]
            else { return nil }

            return OnScreenWindowSnapshot(
                pid: pid_t(pidValue),
                title: info[kCGWindowName as String] as? String ?? "",
                frame: CGRect(x: x, y: y, width: width, height: height),
                frontToBackIndex: index
            )
        }
    }

    func matches(frame candidateFrame: CGRect, title candidateTitle: String) -> Bool {
        let frameTolerance: CGFloat = 6
        let framesMatch = abs(frame.minX - candidateFrame.minX) <= frameTolerance &&
            abs(frame.minY - candidateFrame.minY) <= frameTolerance &&
            abs(frame.width - candidateFrame.width) <= frameTolerance &&
            abs(frame.height - candidateFrame.height) <= frameTolerance
        let titlesMatch = title.isEmpty || candidateTitle.isEmpty || title == candidateTitle
        return framesMatch && titlesMatch
    }
}

private struct ScreenGeometry {
    let frame: CGRect
    let visibleFrame: CGRect

    static func currentScreens() -> [ScreenGeometry] {
        NSScreen.screens.map { screen in
            ScreenGeometry(
                frame: convertToAccessibilityCoordinates(screen.frame),
                visibleFrame: convertToAccessibilityCoordinates(screen.visibleFrame)
            )
        }
    }

    static func screenIndex(containing point: CGPoint) -> Int {
        currentScreens().firstIndex(where: { $0.frame.contains(point) }) ?? -1
    }

    private static func convertToAccessibilityCoordinates(_ rect: CGRect) -> CGRect {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(
            x: rect.minX,
            y: primaryScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private extension AXUIElement {
    func value<T>(for attribute: String) -> T? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &rawValue) == .success else {
            return nil
        }

        if let typedValue = rawValue as? T { return typedValue }
        guard
            let rawValue,
            CFGetTypeID(rawValue) == AXValueGetTypeID()
        else { return nil }
        let axValue = unsafeBitCast(rawValue, to: AXValue.self)

        if T.self == CGPoint.self {
            var point = CGPoint.zero
            guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
            return point as? T
        }
        if T.self == CGSize.self {
            var size = CGSize.zero
            guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
            return size as? T
        }
        return nil
    }

    func boolValue(for attribute: String) -> Bool? {
        value(for: attribute)
    }

    func isSettable(_ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(self, attribute as CFString, &settable) == .success &&
            settable.boolValue
    }

    func setValue(_ point: CGPoint, for attribute: String) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(self, attribute as CFString, value)
    }

    func setValue(_ size: CGSize, for attribute: String) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(self, attribute as CFString, value)
    }
}
