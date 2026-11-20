//
//  ShakeDetector.swift
//  Polarise
//
//  Created by Nikunj Mathur on 17/11/26.
//

import AppKit
import Foundation

/// Detects a horizontal mouse shake through a global mouse-movement monitor.
final class ShakeDetector {
    var onShake: (() -> Void)?
    var onPeek: ((NSEvent.ModifierFlags) -> Void)?

    private weak var settings: OverlaySettings?
    private struct Sample {
        let x: CGFloat
        let timestamp: TimeInterval
    }

    private var buffer: [Sample] = []
    private var monitor: Any?
    private var lastTriggerTime: TimeInterval = 0
    private var lastDiagnosticTime: TimeInterval = 0

    private static let windowDuration: TimeInterval = 0.7
    private static let cooldown: TimeInterval = 1.0
    private static let requiredReversals = 3

    init(settings: OverlaySettings) {
        self.settings = settings
    }

    func start() {
        stop()
        NSLog("[ShakeDetector] Starting cursor monitor; enabled=%@", settings?.shakeEnabled == true ? "yes" : "no")
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }
        NSLog("[ShakeDetector] Global mouseMoved monitor %@", monitor == nil ? "FAILED to install" : "installed")
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        buffer.removeAll(keepingCapacity: true)
    }

    private func handleMouseMoved() {
        guard let settings else {
            NSLog("[ShakeDetector] Missing settings; ignoring cursor samples")
            return
        }
        guard settings.shakeEnabled else {
            if !buffer.isEmpty { NSLog("[ShakeDetector] Shake disabled; clearing samples") }
            buffer.removeAll(keepingCapacity: true)
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        buffer.append(Sample(x: NSEvent.mouseLocation.x, timestamp: now))
        let cutoff = now - Self.windowDuration
        buffer.removeAll { $0.timestamp < cutoff }
        guard buffer.count >= 3 else { return }

        let sensitivity = min(max(settings.shakeSensitivity, 0), 1)
        let strictness = 1 - sensitivity
        let minimumDistance = CGFloat(20 + strictness * 60)
        let minimumSpeed = 150 + strictness * 300
        let reversals = qualifyingReversals(minimumDistance: minimumDistance, minimumSpeed: minimumSpeed)
        if now - lastDiagnosticTime >= 1 {
            NSLog("[ShakeDetector] Sampling x=%.1f reversals=%d/%d enabled=YES sensitivity=%.2f", Double(buffer.last?.x ?? 0), reversals, Self.requiredReversals, sensitivity)
            lastDiagnosticTime = now
        }
        guard reversals >= Self.requiredReversals else { return }

        guard NSEvent.pressedMouseButtons == 0 else {
            NSLog("[ShakeDetector] Shake pattern detected but ignored: mouse button is held")
            return
        }

        let relevantModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command, .capsLock, .function]
        let requiredModifiers = settings.shakeModifiers.intersection(relevantModifiers)
        let peekModifier = settings.peekModifier.intersection(relevantModifiers)
        let currentModifiers = NSEvent.modifierFlags.intersection(relevantModifiers)
        let isPeekGesture = !peekModifier.isEmpty && currentModifiers.contains(peekModifier)

        guard isPeekGesture || requiredModifiers.isEmpty || currentModifiers == requiredModifiers else {
            NSLog("[ShakeDetector] Shake pattern detected but required modifiers do not match (toggle=%lu peek=%lu current=%lu)", requiredModifiers.rawValue, peekModifier.rawValue, currentModifiers.rawValue)
            return
        }
        guard now - lastTriggerTime >= Self.cooldown else { return }

        NSLog("[ShakeDetector] Shake recognized; action=%@", isPeekGesture ? "peek" : "toggle")
        lastTriggerTime = now
        buffer.removeAll(keepingCapacity: true)
        DispatchQueue.main.async { [weak self] in
            if isPeekGesture {
                self?.onPeek?(peekModifier)
            } else {
                self?.onShake?()
            }
        }
    }

    /// Counts completed swings, measuring speed across each full swing instead of
    /// the tiny event-to-event step at the instant direction changes.
    private func qualifyingReversals(minimumDistance: CGFloat, minimumSpeed: Double) -> Int {
        guard let first = buffer.first else { return 0 }
        var pivot = first
        var extreme = first
        var direction: CGFloat = 0
        var count = 0

        for sample in buffer.dropFirst() {
            let delta = sample.x - extreme.x
            guard delta != 0 else { continue }
            let movementDirection: CGFloat = delta > 0 ? 1 : -1

            if direction == 0 || movementDirection == direction {
                direction = movementDirection
                extreme = sample
                continue
            }

            // A reversal is accepted only after the cursor has moved far enough
            // back from the previous extreme, filtering small tracking jitter.
            let reverseDistance = abs(sample.x - extreme.x)
            guard reverseDistance >= minimumDistance else { continue }

            let swingDistance = abs(extreme.x - pivot.x)
            let swingDuration = extreme.timestamp - pivot.timestamp
            if swingDistance >= minimumDistance, swingDuration > 0,
               Double(swingDistance) / swingDuration >= minimumSpeed {
                count += 1
            }

            pivot = extreme
            extreme = sample
            direction = movementDirection
        }

        return count
    }
}
