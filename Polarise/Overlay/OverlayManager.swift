//
//  OverlayManager.swift
//  Polarise
//
//  Created by Nikunj Mathur on 16/11/26.
//

import Foundation
import AppKit
import Combine
import ApplicationServices

final class OverlayManager: ObservableObject {
    @Published var isOverlayEnabled: Bool = false {
        didSet {
            NSLog("[OverlayManager] Overlay enabled state changed: %@", isOverlayEnabled ? "on" : "off")
            if isOverlayEnabled {
                rebuildWindows()
            } else {
                tearDownWindowsAnimated()
            }
        }
    }
    
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    @Published private(set) var lastExternalApp: NSRunningApplication?
    private var screenObserver: Any?
    private var appActivationObserver: Any?
    private var lastTargetWindowNumber: Int?
    private var isCurrentlyHidden: Bool = false
    private var pollTimer: Timer?
    private var cornerPeekTimer: Timer?
    private var modifierPeekTimer: Timer?
    private var isCornerEffectSuppressed = false
    private var spaceObserver: Any?
    private let shakeDetector: ShakeDetector
    let settings: OverlaySettings
    
    init(settings: OverlaySettings) {
        self.settings = settings
        let detector = ShakeDetector(settings: settings)
        shakeDetector = detector
        detector.onShake = { [weak self] in
            guard let self else { return }
            NSLog("[OverlayManager] Shake callback received; current overlay state=%@", self.isOverlayEnabled ? "on" : "off")
            (NSApp.delegate as? AppDelegate)?.flashStatusItem()
            self.isOverlayEnabled.toggle()
        }
        detector.onPeek = { [weak self] modifier in self?.beginModifierPeek(whileHolding: modifier) }
        detector.start()

        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastExternalApp = frontApp
        }
        
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isOverlayEnabled else { return }
            self.rebuildWindows()
        }
        
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            
            if let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               activatedApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.lastExternalApp = activatedApp
            }
            
            guard self.isOverlayEnabled else { return }
            self.repositionOverlaysBelowActiveWindow(force: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.repositionOverlaysBelowActiveWindow(force: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.repositionOverlaysBelowActiveWindow(force: true)
            }
        }
        
        cornerPeekTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.updateCornerPeek()
        }

        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isOverlayEnabled else { return }
            self.repositionOverlaysBelowActiveWindow(force: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.repositionOverlaysBelowActiveWindow(force: true)
            }
        }
    }
    
    deinit {
        shakeDetector.stop()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
        
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
        }
        stopPollTimer()
        cornerPeekTimer?.invalidate()
        modifierPeekTimer?.invalidate()
        tearDownWindows()
    }
    
    func rebuildWindows() {
        tearDownWindows()
        
        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let displayID = CGDirectDisplayID(screenNumber.uint32Value)
            let window = OverlayWindow(screen: screen, settings: settings)
            window.setFrame(screen.frame, display: true)
            windows[displayID] = window
        }
        
        startPollTimer()
        repositionOverlaysBelowActiveWindow()
    }
    
    func tearDownWindows() {
        for (_, window) in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }

    /// Fades all overlay windows out, then tears them down.
    func tearDownWindowsAnimated() {
        stopPollTimer()
        isCurrentlyHidden = true

        let captured = windows
        windows.removeAll()

        let group = DispatchGroup()
        for (_, window) in captured {
            group.enter()
            window.hideWithFade {
                window.close()
                group.leave()
            }
        }
    }
    
    private func startPollTimer() {
        stopPollTimer()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.isOverlayEnabled else { return }
            self.repositionOverlaysBelowActiveWindow(force: false)
        }
    }
    
    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func beginModifierPeek(whileHolding modifier: NSEvent.ModifierFlags) {
        guard !isOverlayEnabled else { return }
        NSLog("[OverlayManager] Starting modifier peek")
        (NSApp.delegate as? AppDelegate)?.flashStatusItem()
        isOverlayEnabled = true
        modifierPeekTimer?.invalidate()
        modifierPeekTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if !NSEvent.modifierFlags.contains(modifier) {
                timer.invalidate()
                self.modifierPeekTimer = nil
                self.isOverlayEnabled = false
                NSLog("[OverlayManager] Modifier released; ending peek")
            }
        }
    }

    private func updateCornerPeek() {
        guard settings.peekAtCorners else {
            restoreCornerSuppressedEffect()
            return
        }

        let point = NSEvent.mouseLocation
        let isInCorner = NSScreen.screens.contains { screen in
            let frame = screen.frame
            let inset: CGFloat = 12
            let isAtLeftOrRightEdge = point.x <= frame.minX + inset || point.x >= frame.maxX - inset
            let isAtTopOrBottomEdge = point.y <= frame.minY + inset || point.y >= frame.maxY - inset
            return isAtLeftOrRightEdge && isAtTopOrBottomEdge
        }

        if isInCorner {
            guard isOverlayEnabled, !isCornerEffectSuppressed else { return }
            isCornerEffectSuppressed = true
            isOverlayEnabled = false
            NSLog("[OverlayManager] Corner entered; temporarily suppressing the overlay effect")
        } else {
            restoreCornerSuppressedEffect()
        }
    }

    private func restoreCornerSuppressedEffect() {
        guard isCornerEffectSuppressed else { return }
        isCornerEffectSuppressed = false
        isOverlayEnabled = true
        NSLog("[OverlayManager] Corner exited; restoring the overlay effect")
    }

    func repositionOverlaysBelowActiveWindow(force: Bool = false) {
        guard isOverlayEnabled, !windows.isEmpty else { return }
        
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        
        if isMissionControlActive(in: windowInfoList) || isFullScreenSpaceActive(in: windowInfoList) {
            hideOverlays()
            return
        }
        
        let targetApp: NSRunningApplication?
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApp = frontApp
            lastExternalApp = frontApp
        } else {
            targetApp = lastExternalApp
        }
        
        guard let activeApp = targetApp else {
            hideOverlays()
            return
        }
        
        // --- Ignored apps check (before window walk) ---
        let polariseBundleID = Bundle.main.bundleIdentifier ?? ""
        let activeBundleID   = activeApp.bundleIdentifier ?? ""
        if activeBundleID == polariseBundleID ||
           (!activeBundleID.isEmpty && settings.ignoredBundleIDs.contains(activeBundleID)) {
            hideOverlays()
            return
        }
        
        // --- Build the "sharp PID" set ---
        var sharpPIDs = Set<pid_t>([activeApp.processIdentifier])
        
        // App-wide focus: all processes of the same bundleID
        if settings.appWideFocus {
            for app in NSWorkspace.shared.runningApplications
                where app.bundleIdentifier == activeBundleID {
                sharpPIDs.insert(app.processIdentifier)
            }
        }
        
        // App groups: resolve every peer bundleID to running PIDs
        if !activeBundleID.isEmpty {
            let groupBundleIDs = settings.groupMembers(for: activeBundleID)
            for peerID in groupBundleIDs where peerID != activeBundleID {
                for app in NSWorkspace.shared.runningApplications
                    where app.bundleIdentifier == peerID {
                    sharpPIDs.insert(app.processIdentifier)
                }
            }
        }
        
        // --- Walk windowInfoList front-to-back for a contiguous run ---
        var lastSharpWindowNumber: Int? = nil
        
        for info in windowInfoList {
            guard let ownerPID   = info[kCGWindowOwnerPID as String]    as? pid_t,
                  let layer      = info[kCGWindowLayer as String]        as? Int,
                  layer == 0 else { continue }
            
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1.0
            guard alpha > 0.01 else { continue }
            
            if let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
               let width  = boundsDict["Width"],
               let height = boundsDict["Height"] {
                guard width > 50, height > 50 else { continue }
            }
            
            if sharpPIDs.contains(ownerPID) {
                // This window belongs to a sharp app — extend the run
                if let winNum = info[kCGWindowNumber as String] as? Int {
                    lastSharpWindowNumber = winNum
                }
            } else {
                // First window outside the sharp set — stop the contiguous run
                break
            }
        }
        
        // --- Determine the target window number ---
        let windowNumber: Int
        if let runEnd = lastSharpWindowNumber {
            // Contiguous run found — place overlay below the last sharp window
            windowNumber = runEnd
        } else {
            // No sharp window at the front — fall back to old single-window logic
            guard let fallback = frontmostWindowNumber(for: activeApp.processIdentifier, in: windowInfoList) else {
                hideOverlays()
                return
            }
            windowNumber = fallback
        }
        
        if !force, !isCurrentlyHidden, windowNumber == lastTargetWindowNumber {
            return
        }
        
        let wasHidden = isCurrentlyHidden
        lastTargetWindowNumber = windowNumber
        isCurrentlyHidden = false
        
        for (_, overlayWindow) in windows {
            overlayWindow.showBelow(windowNumber: windowNumber, animated: wasHidden || !overlayWindow.isVisible)
            overlayWindow.applyAllSettings(forceBlur: true)
        }
    }
    
    private func frontmostWindowNumber(for pid: pid_t, in windowInfoList: [[String: Any]]) -> Int? {
        for info in windowInfoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let windowNumber = info[kCGWindowNumber as String] as? Int else {
                continue
            }
            
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1.0
            guard alpha > 0.01 else { continue }
            
            if let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
               let width = boundsDict["Width"],
               let height = boundsDict["Height"] {
                guard width > 50, height > 50 else { continue }
            }
            
            return windowNumber
        }
        
        return nil
    }
    
    private func isMissionControlActive(in windowInfoList: [[String: Any]]) -> Bool {
        for info in windowInfoList {
            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  let _ = info[kCGWindowBounds as String] as? [String: CGFloat] else {
                continue
            }
            
            if ownerName == "WindowManager" && layer == 14 {
                return true
            }
        }
        return false
    }
    
    private func hideOverlays() {
        guard !isCurrentlyHidden else { return }
        for (_, window) in windows {
            window.hideWithFade(completion: nil)
        }
        isCurrentlyHidden = true
        lastTargetWindowNumber = nil
    }
    
    private func isFullScreenSpaceActive(in windowInfoList: [[String: Any]]) -> Bool {
        guard let activeApp = lastExternalApp else { return false }
        
        let targetPID = activeApp.processIdentifier
        
        for info in windowInfoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == targetPID,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let height = bounds["Height"],
                  let width = bounds["Width"],
                  let _ = bounds["X"],
                  let _ = bounds["Y"] else {
                continue
            }
            
            let looksFullScreen = NSScreen.screens.contains { screen in
                abs(width - screen.frame.width) < 2 && height >= screen.frame.height - 60
            }
            guard looksFullScreen else { continue }
            
            if AXIsProcessTrusted() {
                return isAXFullScreen(pid: targetPID)
            }
            return true
        }
        return false
    }
    
    private func isAXFullScreen(pid: pid_t) -> Bool {
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, 0.05)
        
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return false }
        
        var fsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowRef as! AXUIElement, "AXFullScreen" as CFString, &fsRef) == .success else {
            return false
        }
        return (fsRef as? Bool) ?? false
    }
}
