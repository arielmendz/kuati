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
    @Published var isAutomatic: Bool = WindowManager.storedAutomaticPreference {
        didSet {
            UserDefaults.standard.set(isAutomatic, forKey: Self.automaticDefaultsKey)
            if isAutomatic {
                arrangeNow()
            } else {
                updateStatus(windowCount: nil)
            }
        }
    }

    private static let automaticDefaultsKey = "automaticArrangement"
    private static let animationSteps = 16
    private static let animationFrameNanoseconds: UInt64 = 16_666_667
    private static let messagingTimeout: Float = 0.5
    private static let permissionPollInterval: TimeInterval = 1
    private static let eventSettlingInterval: TimeInterval = 0.15
    /// Accessibility notification coverage varies between applications, so a
    /// slow sweep reconciles anything the observers missed. It is a safety net,
    /// not the mechanism: real changes are handled by notification, in a
    /// fraction of a second, long before this fires.
    private static let reconciliationInterval: TimeInterval = 30

    /// Reads the saved preference without routing through `isAutomatic`.
    /// `@Published` properties run their `didSet` even when assigned inside
    /// `init`, so restoring the value there would arrange windows — and so
    /// prompt for Accessibility access — before `refreshPermission()` had run.
    private static var storedAutomaticPreference: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: automaticDefaultsKey) != nil else { return true }
        return defaults.bool(forKey: automaticDefaultsKey)
    }

    private var permissionTimer: Timer?
    private var reconciliationTimer: Timer?
    private var settlingTimer: Timer?
    private var animationTask: Task<Void, Never>?
    private var notificationObservers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var applicationObservers: [pid_t: ApplicationObserver] = [:]
    private var previousWindowSignature = ""

    init() {
        // Bound how long an unresponsive application can block the main thread
        // inside a synchronous accessibility call. Applying this to the
        // system-wide element sets the default for every element this process
        // creates, so a hung application costs a fraction of a second instead
        // of stalling the menu bar.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), Self.messagingTimeout)
        refreshPermission()
    }

    func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        apply(permission: AXIsProcessTrustedWithOptions(options))
    }

    func refreshPermission() {
        apply(permission: AXIsProcessTrusted())
    }

    func arrangeNow() {
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            return
        }

        let windows = currentWorkspaceWindows()
        observe(windows)
        arrange(windows)
        previousWindowSignature = signature(for: windows)
        updateStatus(windowCount: windows.count)
    }

    // MARK: - Accessibility permission

    private func apply(permission granted: Bool) {
        hasAccessibilityPermission = granted

        guard granted else {
            stopObserving()
            startPermissionPolling()
            updateStatus(windowCount: nil)
            return
        }

        stopPermissionPolling()
        startObservingWorkspace()
        startReconciling()
        refreshApplicationObservers()

        if isAutomatic {
            arrangeNow()
        } else {
            updateStatus(windowCount: nil)
        }
    }

    /// Accessibility trust has no change notification, so it is polled — but
    /// only while the grant is still missing. Once it arrives the timer stops
    /// and the app is entirely event driven.
    private func startPermissionPolling() {
        guard permissionTimer == nil else { return }
        let timer = Timer(timeInterval: Self.permissionPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.hasAccessibilityPermission, AXIsProcessTrusted() else { return }
                self.apply(permission: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    private func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    // MARK: - Change notifications

    private func startObservingWorkspace() {
        guard notificationObservers.isEmpty else { return }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let workspaceNotifications: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ]

        for name in workspaceNotifications {
            let token = workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleWorkspaceChange() }
            }
            notificationObservers.append((workspaceCenter, token))
        }

        let screenToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleScreenChange() }
        }
        notificationObservers.append((NotificationCenter.default, screenToken))
    }

    private func startReconciling() {
        guard reconciliationTimer == nil else { return }
        let timer = Timer(timeInterval: Self.reconciliationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scheduleLayoutCheck() }
        }
        timer.tolerance = Self.reconciliationInterval / 2
        RunLoop.main.add(timer, forMode: .common)
        reconciliationTimer = timer
    }

    private func stopObserving() {
        settlingTimer?.invalidate()
        settlingTimer = nil
        reconciliationTimer?.invalidate()
        reconciliationTimer = nil
        applicationObservers.removeAll()

        for observer in notificationObservers {
            observer.center.removeObserver(observer.token)
        }
        notificationObservers.removeAll()
    }

    /// Keeps one accessibility observer per managed application, adding
    /// observers for applications that launched and dropping those that quit.
    private func refreshApplicationObservers() {
        guard hasAccessibilityPermission else { return }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        let livePIDs = Set(
            NSWorkspace.shared.runningApplications
                .filter {
                    $0.processIdentifier != ownPID &&
                        $0.activationPolicy == .regular &&
                        !$0.isTerminated
                }
                .map(\.processIdentifier)
        )

        applicationObservers = applicationObservers.filter { livePIDs.contains($0.key) }
        for pid in livePIDs where applicationObservers[pid] == nil {
            applicationObservers[pid] = ApplicationObserver(pid: pid) { [weak self] in
                Task { @MainActor in self?.scheduleLayoutCheck() }
            }
        }
    }

    /// Window move and resize notifications are posted by the window elements
    /// themselves, so the observed set follows the windows Kuati manages.
    private func observe(_ windows: [ManagedWindow]) {
        let windowsByApplication = Dictionary(grouping: windows, by: \.pid)
        for (pid, observer) in applicationObservers {
            observer.observe(windows: windowsByApplication[pid]?.map(\.element) ?? [])
        }
    }

    private func handleWorkspaceChange() {
        guard hasAccessibilityPermission else { return }
        refreshApplicationObservers()
        scheduleLayoutCheck()
    }

    private func handleScreenChange() {
        guard hasAccessibilityPermission else { return }
        // A display change alters every usable frame, so the layout has to be
        // recomputed even when the same windows are on the same screens.
        previousWindowSignature = ""
        scheduleLayoutCheck()
    }

    /// Coalesces bursts of accessibility notifications — a window drag emits a
    /// steady stream of them — into a single layout check.
    private func scheduleLayoutCheck() {
        guard isAutomatic, animationTask == nil else { return }

        settlingTimer?.invalidate()
        let timer = Timer(timeInterval: Self.eventSettlingInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.applyLayoutIfChanged() }
        }
        RunLoop.main.add(timer, forMode: .common)
        settlingTimer = timer
    }

    private func applyLayoutIfChanged() {
        settlingTimer?.invalidate()
        settlingTimer = nil
        guard isAutomatic else { return }
        guard AXIsProcessTrusted() else {
            apply(permission: false)
            return
        }

        let windows = currentWorkspaceWindows()
        observe(windows)

        let newSignature = signature(for: windows)
        guard newSignature != previousWindowSignature else { return }

        arrange(windows)
        previousWindowSignature = newSignature
        updateStatus(windowCount: windows.count)
    }

    // MARK: - Layout

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
            // Layout checks are suppressed while animating, so pick up anything
            // that changed during the transition.
            self?.scheduleLayoutCheck()
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

/// Watches one application for the accessibility notifications that change how
/// its windows should be laid out. Notifications arrive on the main run loop,
/// which is where `onChange` is invoked.
private final class ApplicationObserver {
    private static let applicationNotifications = [
        kAXWindowCreatedNotification,
        kAXFocusedWindowChangedNotification,
        kAXMainWindowChangedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
        kAXApplicationHiddenNotification,
        kAXApplicationShownNotification
    ]

    /// Miniaturize notifications are posted by the window element in some
    /// applications and by the application element in others, so both are
    /// registered. Duplicate deliveries coalesce into one layout check.
    private static let windowNotifications = [
        kAXUIElementDestroyedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification
    ]

    private let observer: AXObserver
    private let applicationElement: AXUIElement
    private let onChange: () -> Void
    private var observedWindows: [AXUIElement] = []

    init?(pid: pid_t, onChange: @escaping () -> Void) {
        var createdObserver: AXObserver?
        guard
            AXObserverCreate(pid, applicationObserverCallback, &createdObserver) == .success,
            let createdObserver
        else { return nil }

        self.observer = createdObserver
        self.applicationElement = AXUIElementCreateApplication(pid)
        self.onChange = onChange

        let context = Unmanaged.passUnretained(self).toOpaque()
        for notification in Self.applicationNotifications {
            AXObserverAddNotification(observer, applicationElement, notification as CFString, context)
        }

        // Common modes keep notifications flowing while a menu is tracking.
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
    }

    deinit {
        removeWindowNotifications()
        for notification in Self.applicationNotifications {
            AXObserverRemoveNotification(observer, applicationElement, notification as CFString)
        }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
    }

    func observe(windows: [AXUIElement]) {
        guard !isObserving(windows) else { return }

        removeWindowNotifications()
        observedWindows = windows

        let context = Unmanaged.passUnretained(self).toOpaque()
        for window in windows {
            for notification in Self.windowNotifications {
                AXObserverAddNotification(observer, window, notification as CFString, context)
            }
        }
    }

    fileprivate func notifyChange() {
        onChange()
    }

    private func isObserving(_ windows: [AXUIElement]) -> Bool {
        windows.count == observedWindows.count &&
            zip(observedWindows, windows).allSatisfy { CFEqual($0, $1) }
    }

    private func removeWindowNotifications() {
        for window in observedWindows {
            for notification in Self.windowNotifications {
                AXObserverRemoveNotification(observer, window, notification as CFString)
            }
        }
        observedWindows = []
    }
}

private func applicationObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else { return }
    Unmanaged<ApplicationObserver>.fromOpaque(context).takeUnretainedValue().notifyChange()
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
