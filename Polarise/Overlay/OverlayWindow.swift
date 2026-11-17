//
//  OverlayWindow.swift
//  Polarise
//
//  Created by Nikunj Mathur on 16/11/26.
//

import Foundation
import AppKit
import Combine

final class OverlayWindow: NSWindow {
    private let settings: OverlaySettings
    private var cancellables = Set<AnyCancellable>()
    private let rootView = NSView()
    private let tintView = NSView()
    private let grainView = NSView()
    private var fallbackBlurView: NSVisualEffectView?
    private var lastAppliedRadius: Int = -1
    
    init(screen: NSScreen, settings: OverlaySettings) {
        self.settings = settings
        
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.hasShadow = false
        self.level = .normal
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isReleasedWhenClosed = false
        
        setupLayers(size: screen.frame.size)
        bindSettings()
        applyAllSettings(forceBlur: true)
    }
    
    private func setupLayers(size: NSSize) {
        let bounds = NSRect(origin: .zero, size: size)
        
        rootView.frame = bounds
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        rootView.autoresizingMask = [.width, .height]
        
        if !PrivateBlurBridge.isSupported {
            let blur = NSVisualEffectView(frame: bounds)
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.material = .hudWindow
            blur.autoresizingMask = [.width, .height]
            rootView.addSubview(blur)
            fallbackBlurView = blur
        }
        
        tintView.frame = bounds
        tintView.wantsLayer = true
        tintView.autoresizingMask = [.width, .height]
        rootView.addSubview(tintView)
        
        grainView.frame = bounds
        grainView.wantsLayer = true
        grainView.layer?.backgroundColor = GrainTile.patternColor.cgColor
        grainView.autoresizingMask = [.width, .height]
        rootView.addSubview(grainView)
        
        self.contentView = rootView
    }
    
    private func bindSettings() {
        settings.$blurRadius
            .throttle(for: .milliseconds(16), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] radius in
                self?.applyBlurRadius(Int(radius.rounded()))
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest(settings.$tintColor, settings.$tintOpacity)
            .sink { [weak self] _, _ in
                self?.applyTint()
            }
            .store(in: &cancellables)
        settings.$grainOpacity
            .sink { [weak self] opacity in
                self?.applyGrainOpacity(opacity)
            }
            .store(in: &cancellables)
    }
    
    func applyAllSettings(forceBlur: Bool = false) {
        applyBlurRadius(Int(settings.blurRadius.rounded()), force: forceBlur)
        applyTint()
        applyGrainOpacity(settings.grainOpacity)
    }
    
    private func applyBlurRadius(_ radius: Int, force: Bool = false) {
        guard force || radius != lastAppliedRadius else { return }
        lastAppliedRadius = radius
        
        if PrivateBlurBridge.isSupported {
            PrivateBlurBridge.setBlurRadius(radius, forWindowNumber: self.windowNumber)
        } else {
            fallbackBlurView?.alphaValue = radius > 0 ? 1.0 : 0.0
        }
    }
    
    private func applyTint() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tintView.layer?.backgroundColor = settings.nsTintColor.cgColor
        CATransaction.commit()
    }
    
    private func applyGrainOpacity(_ opacity: Double) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        grainView.layer?.opacity = Float(opacity)
        CATransaction.commit()
    }
}
