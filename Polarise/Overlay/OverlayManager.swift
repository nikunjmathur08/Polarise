//
//  OverlayManager.swift
//  Polarise
//
//  Created by Nikunj Mathur on 16/11/26.
//

import Foundation
import AppKit
import Combine

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
    private var screenObserver: Any?
    
    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isOverlayEnabled else { return }
            self.rebuildWindows()
        }
    }
    
    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
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
    }
    
    func tearDownWindows() {
        for (_, window) in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}
