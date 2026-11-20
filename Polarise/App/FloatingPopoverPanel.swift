//
//  FloatingPopoverPanel.swift
//  Polarise
//

import Foundation
import AppKit
import SwiftUI
import QuartzCore

final class FloatingPopoverPanel: NSPanel {
    var onDismiss: (() -> Void)?
    private let backdropPanel = FloatingPopoverBackdropPanel()
    private let belowMenuBarLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)

    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = belowMenuBarLevel
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.hidesOnDeactivate = false

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView = hostingView
    }

    func showBackdrop(from panelFrame: NSRect, screenFrame: NSRect, menuBarBottom: CGFloat) {
        let leadIn: CGFloat = 360
        
        let minX = max(screenFrame.minX, panelFrame.minX - leadIn)
        
        let backdropFrame = NSRect(
            x: minX,
            y: screenFrame.minY,
            width: max(1, screenFrame.maxX - minX),
            height: screenFrame.height
        )
        backdropPanel.setFrame(backdropFrame, display: true)
        backdropPanel.order(.below, relativeTo: windowNumber)
    }

    func hideBackdrop() {
        backdropPanel.orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }
}

private final class FloatingPopoverBackdropPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true

        let effectView = GradientBackdropEffectView()
        effectView.frame = .zero
        effectView.autoresizingMask = [.width, .height]
        contentView = effectView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class GradientBackdropEffectView: NSVisualEffectView {
    private var lastMaskSize: NSSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .popover
        blendingMode = .behindWindow
        state = .active
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        updateMask()
    }

    private func updateMask() {
        let size = bounds.size
        guard size.width > 1, size.height > 1, size != lastMaskSize else { return }
        lastMaskSize = size

        let stops: [(CGFloat, CGFloat)] = [
            (0.00, 0.00), (0.25, 0.20), (0.50, 0.50), (0.75, 0.80), (1.00, 1.00)
        ]
        let gradient = NSGradient(
            colors: stops.map { NSColor.white.withAlphaComponent($0.1) },
            atLocations: stops.map { $0.0 },
            colorSpace: .deviceRGB
        )!

        maskImage = NSImage(size: size, flipped: false) { rect in
            gradient.draw(in: rect, angle: 0)
            return true
        }
    }
}

private final class MaskedHostingView<Content: View>: NSHostingView<Content> {
    private let fadeMask = CAGradientLayer()
    
    required init(rootView: Content) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.mask = fadeMask
    }
    
    @MainActor @preconcurrency required init?(coder: NSCoder) {
        fatalError("init(coder): has not been implemented")
    }
    
    override func layout() {
        super.layout()
        updateFadeMask()
    }
    
    private func updateFadeMask() {
        let h = bounds.height
        guard h > 1 else { return }
        
        let screen = window?.screen ?? NSScreen.main
        let menuBar = screen.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 24
        let f = min(0.5, (menuBar + 36) / h)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fadeMask.frame = bounds
        fadeMask.startPoint = CGPoint(x: 0.5, y: 1)
        fadeMask.endPoint = CGPoint(x: 0.5, y: 0)
        fadeMask.colors = [
            NSColor.black.withAlphaComponent(0.0).cgColor,
            NSColor.black.withAlphaComponent(0.10).cgColor,
            NSColor.black.withAlphaComponent(0.45).cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor
        ]
        fadeMask.locations = [0, NSNumber(value: f * 0.45), NSNumber(value: f * 0.75), NSNumber(value: f), 1]
        CATransaction.commit()
    }
}
