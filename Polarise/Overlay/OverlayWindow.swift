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
    private var visibilityAnimationGeneration = 0
    private var gradientMaskLayer: CAGradientLayer?
    
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
            .throttle(for: .milliseconds(16), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] radius in
                self?.applyBlurRadius(Int(radius.rounded()))
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest(settings.$tintColor, settings.$tintOpacity)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.applyTint()
            }
            .store(in: &cancellables)

        settings.$grainOpacity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] opacity in
                self?.applyGrainOpacity(opacity)
            }
            .store(in: &cancellables)

        // Skip initial value — preset mask is applied synchronously in applyAllSettings during init.
        settings.$currentPreset
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] preset in
                self?.applyPresetMask(preset)
            }
            .store(in: &cancellables)
    }
    
    func applyAllSettings(forceBlur: Bool = false) {
        applyBlurRadius(Int(settings.blurRadius.rounded()), force: forceBlur)
        applyTint()
        applyGrainOpacity(settings.grainOpacity)
        applyPresetMask(settings.currentPreset)
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

    func showBelow(windowNumber: Int) {
        visibilityAnimationGeneration += 1

        // Always start from zero so the fade-in plays every time
        alphaValue = 0
        orderFront(nil)
        order(.below, relativeTo: windowNumber)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    func hideWithFade(completion: (() -> Void)? = nil) {
        guard isVisible else {
            completion?()
            return
        }

        visibilityAnimationGeneration += 1
        let animationGeneration = visibilityAnimationGeneration

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.visibilityAnimationGeneration == animationGeneration else { return }
            self.orderOut(nil)
            completion?()
        }
    }
    
    private func applyPresetMask(_ preset: PolarisePreset) {
        switch preset {
        case .medium: applyGradientMask()
        case .deep:   removeGradientMask()
        }
    }

    /// Applies a gradient mask that keeps the blur fully opaque at the bottom
    /// and fades it progressively to transparent toward the menu bar.
    ///
    /// CALayer mask convention: black (alpha = 1) → content visible,
    ///                          clear (alpha = 0) → content hidden.
    ///
    /// CAGradientLayer unit coordinates on a non-flipped NSView layer:
    ///   (0.5, 0) = bottom centre,  (0.5, 1) = top centre.
    private func applyGradientMask() {
        let mask = CAGradientLayer()

        // Three stops: solid for the bottom ~65 %, then a smooth ease-out
        // fade through the top 35 % toward the menu bar.
        mask.colors    = [NSColor.black.cgColor,
                          NSColor.black.cgColor,
                          NSColor.clear.cgColor]
        mask.locations = [0.0, 0.65, 1.0]
        mask.startPoint = CGPoint(x: 0.5, y: 0.0)  // bottom
        mask.endPoint   = CGPoint(x: 0.5, y: 1.0)  // top (menu bar)
        mask.frame = rootView.bounds

        rootView.layer?.mask = mask
        gradientMaskLayer = mask
    }

    private func removeGradientMask() {
        rootView.layer?.mask = nil
        gradientMaskLayer = nil
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
