//
//  FloatingPopoverPanel.swift
//  Polarise
//
//  Created by Nikunj Mathur on 17/11/26.
//

import Foundation
import AppKit
import SwiftUI

final class FloatingPopoverPanel: NSPanel {
    var onDismiss: (() -> Void)?
    
    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.hidesOnDeactivate = false
        
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView = hostingView
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }
}
