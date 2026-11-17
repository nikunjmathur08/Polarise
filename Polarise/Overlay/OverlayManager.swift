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
            if isOverlayEnabled {
                rebuildWindows()
            } else {
                tearDownWindows()
            }
        }
    }
    
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var lastExternalApp: NSRunningApplication?
    private var screenObserver: Any?
    private var appActivationObserver: Any?
    private var lastTargetWindowNumber: Int?
    private var isCurrentlyHidden: Bool = false
    private var pollTimer: Timer?
    private var spaceObserver: Any?
    
    init() {
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
        tearDownWindows()
    }
    
    func rebuildWindows() {
        tearDownWindows()
        
        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let displayID = CGDirectDisplayID(screenNumber.uint32Value)
            let window = OverlayWindow(screen: screen)
            window.setFrame(screen.frame, display: true)
            window.orderFront(nil)
            windows[displayID] = window
        }
        
        startPollTimer()
        repositionOverlaysBelowActiveWindow()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.debugDumpWindowList()
        }
    }
    
    func tearDownWindows() {
        for (_, window) in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
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
        
        guard let windowNumber = frontmostWindowNumber(for: activeApp.processIdentifier, in: windowInfoList) else {
            hideOverlays()
            return
        }
        
        if !force, !isCurrentlyHidden, windowNumber == lastTargetWindowNumber {
            return
        }
        
        lastTargetWindowNumber = windowNumber
        isCurrentlyHidden = false
        
        for (_, overlayWindow) in windows {
            overlayWindow.order(.below, relativeTo: windowNumber)
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
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else {
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
            window.orderOut(nil)
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
                  let x = bounds["X"],
                  let y = bounds["Y"] else {
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
    
    // MARK: TEMPORARY FUNCTION FOR TESTING
    private func debugDumpWindowList() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        
        print("WINDOW LIST DUMP")
        for info in windowInfoList {
            let owner = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let name = info[kCGWindowName as String] as? String ?? "No Name"
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            let bounds = info[kCGWindowBounds as String] ?? [:]
            
            if owner == "Dock" || layer != 0 {
                print("Owner: \(owner) | Name: \(name) | Layer: \(layer) | Bounds: \(bounds)")
            }
        }
    }
}
