//
//  OverlaySettings.swift
//  Polarise
//
//  Created by Nikunj Mathur on 17/11/26.
//

import Foundation
import SwiftUI
import AppKit
import Combine

enum PolarisePreset: String, CaseIterable, Identifiable {
    case medium = "Medium"
    case deep   = "Deep"

    var id: String { rawValue }
}

final class OverlaySettings: ObservableObject {

    // MARK: - UserDefaults keys

    private enum Keys {
        static let blurRadius       = "polarise.blurRadius"
        static let tintRed          = "polarise.tintRed"
        static let tintGreen        = "polarise.tintGreen"
        static let tintBlue         = "polarise.tintBlue"
        static let tintOpacity      = "polarise.tintOpacity"
        static let grainOpacity     = "polarise.grainOpacity"
        static let preset           = "polarise.preset"
        static let ignoredBundleIDs = "polarise.ignoredBundleIDs"
        static let fadeInDuration   = "polarise.fadeInDuration"
        static let fadeOutDuration  = "polarise.fadeOutDuration"
        static let shakeEnabled     = "polarise.shakeEnabled"
        static let shakeSensitivity = "polarise.shakeSensitivity"
        static let shakeModifiers   = "polarise.shakeModifiers"
        static let peekModifier     = "polarise.peekModifier"
        static let peekAtCorners    = "polarise.peekAtCorners"
        static let appWideFocus     = "polarise.appWideFocus"
        static let appGroups        = "polarise.appGroups"
    }

    // MARK: - JSON helpers

    private static func loadJSON<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func saveJSON<T: Encodable>(_ value: T, forKey key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }

    // MARK: - Visual properties

    @Published var currentPreset: PolarisePreset {
        didSet { UserDefaults.standard.set(currentPreset.rawValue, forKey: Keys.preset) }
    }

    @Published var blurRadius: Double {
        didSet { UserDefaults.standard.set(blurRadius, forKey: Keys.blurRadius) }
    }

    @Published var tintColor: Color {
        didSet { saveTintColor(tintColor) }
    }

    @Published var tintOpacity: Double {
        didSet { UserDefaults.standard.set(tintOpacity, forKey: Keys.tintOpacity) }
    }

    @Published var grainOpacity: Double {
        didSet { UserDefaults.standard.set(grainOpacity, forKey: Keys.grainOpacity) }
    }

    // MARK: - Fade durations

    @Published var fadeInDuration: Double {
        didSet { UserDefaults.standard.set(fadeInDuration, forKey: Keys.fadeInDuration) }
    }

    @Published var fadeOutDuration: Double {
        didSet { UserDefaults.standard.set(fadeOutDuration, forKey: Keys.fadeOutDuration) }
    }

    // MARK: - Shake gesture

    @Published var shakeEnabled: Bool {
        didSet { UserDefaults.standard.set(shakeEnabled, forKey: Keys.shakeEnabled) }
    }

    /// 0 = low sensitivity (high thresholds), 1 = high sensitivity (low thresholds).
    @Published var shakeSensitivity: Double {
        didSet { UserDefaults.standard.set(shakeSensitivity, forKey: Keys.shakeSensitivity) }
    }

    /// Required modifier keys that must be held during the shake gesture.
    /// Stored as the UInt rawValue of NSEvent.ModifierFlags.
    @Published var shakeModifiers: NSEvent.ModifierFlags {
        didSet { UserDefaults.standard.set(shakeModifiers.rawValue, forKey: Keys.shakeModifiers) }
    }

    @Published var peekModifier: NSEvent.ModifierFlags {
        didSet { UserDefaults.standard.set(peekModifier.rawValue, forKey: Keys.peekModifier) }
    }

    @Published var peekAtCorners: Bool {
        didSet { UserDefaults.standard.set(peekAtCorners, forKey: Keys.peekAtCorners) }
    }

    // MARK: - Focus behaviour

    /// When true the overlay stays up for ALL windows of the active app, not just the frontmost one.
    @Published var appWideFocus: Bool {
        didSet { UserDefaults.standard.set(appWideFocus, forKey: Keys.appWideFocus) }
    }

    // MARK: - Ignored apps

    /// Bundle IDs of apps for which the overlay should be hidden when they are frontmost.
    @Published var ignoredBundleIDs: Set<String> {
        didSet { OverlaySettings.saveJSON(Array(ignoredBundleIDs), forKey: Keys.ignoredBundleIDs) }
    }

    // MARK: - App groups

    /// Each element is a group: an array of bundle IDs whose windows all stay sharp together.
    @Published var appGroups: [[String]] {
        didSet { OverlaySettings.saveJSON(appGroups, forKey: Keys.appGroups) }
    }

    // MARK: - Init

    init() {
        let ud = UserDefaults.standard

        self.currentPreset   = ud.string(forKey: Keys.preset).flatMap(PolarisePreset.init(rawValue:)) ?? .deep
        self.blurRadius      = ud.object(forKey: Keys.blurRadius)      as? Double ?? 24.0
        self.tintOpacity     = ud.object(forKey: Keys.tintOpacity)     as? Double ?? 0.25
        self.grainOpacity    = ud.object(forKey: Keys.grainOpacity)    as? Double ?? 0.025
        self.fadeInDuration  = ud.object(forKey: Keys.fadeInDuration)  as? Double ?? 0.24
        self.fadeOutDuration = ud.object(forKey: Keys.fadeOutDuration) as? Double ?? 0.18
        self.shakeEnabled    = ud.object(forKey: Keys.shakeEnabled) as? Bool ?? true
        self.shakeSensitivity = ud.object(forKey: Keys.shakeSensitivity) as? Double ?? 0.5
        self.shakeModifiers  = NSEvent.ModifierFlags(rawValue: ud.object(forKey: Keys.shakeModifiers) as? UInt ?? 0)
        self.peekModifier    = NSEvent.ModifierFlags(rawValue: ud.object(forKey: Keys.peekModifier) as? UInt ?? NSEvent.ModifierFlags.shift.rawValue)
        self.peekAtCorners   = ud.bool(forKey: Keys.peekAtCorners)
        self.appWideFocus    = ud.bool(forKey: Keys.appWideFocus)

        // Tint colour
        if ud.object(forKey: Keys.tintRed) != nil {
            self.tintColor = Color(.sRGB,
                                   red:   ud.double(forKey: Keys.tintRed),
                                   green: ud.double(forKey: Keys.tintGreen),
                                   blue:  ud.double(forKey: Keys.tintBlue),
                                   opacity: 1.0)
        } else {
            self.tintColor = Color(.sRGB, red: 0.08, green: 0.09, blue: 0.12, opacity: 1.0)
        }

        // ignoredBundleIDs — try JSON first, fall back to legacy stringArray
        if let saved = OverlaySettings.loadJSON([String].self, forKey: Keys.ignoredBundleIDs) {
            self.ignoredBundleIDs = Set(saved).union(["com.apple.ColorMeter"])
        } else if let legacy = ud.stringArray(forKey: Keys.ignoredBundleIDs) {
            self.ignoredBundleIDs = Set(legacy).union(["com.apple.ColorMeter"])
            // migrate to JSON
            OverlaySettings.saveJSON(Array(Set(legacy)), forKey: Keys.ignoredBundleIDs)
        } else {
            self.ignoredBundleIDs = ["com.apple.ColorMeter"]
        }

        // appGroups
        self.appGroups = (OverlaySettings.loadJSON([[String]].self, forKey: Keys.appGroups) ?? [])
            .map { $0.filter { $0 != "com.apple.finder" } }
            .filter { !$0.isEmpty }
    }

    // MARK: - Presets

    func applyPreset(_ preset: PolarisePreset) {
        currentPreset = preset
        switch preset {
        case .medium:
            blurRadius   = 34
            tintOpacity  = 0.18
            grainOpacity = 0.025
        case .deep:
            blurRadius   = 56
            tintOpacity  = 0.30
            grainOpacity = 0.04
        }
    }

    // MARK: - Ignored apps

    func addIgnored(bundleID: String) {
        guard !bundleID.isEmpty else { return }
        ignoredBundleIDs.insert(bundleID)
    }

    func toggleIgnored(bundleID: String) {
        if ignoredBundleIDs.contains(bundleID) {
            ignoredBundleIDs.remove(bundleID)
        } else {
            ignoredBundleIDs.insert(bundleID)
        }
    }

    // MARK: - App groups

    /// Returns the other bundle IDs in the same group as `bundleID`, or [] if not in any group.
    func groupPeers(for bundleID: String) -> [String] {
        (appGroups.first { $0.contains(bundleID) } ?? []).filter { $0 != bundleID }
    }

    /// All bundle IDs that are "protected" (same group) alongside `bundleID`, including itself.
    func groupMembers(for bundleID: String) -> [String] {
        appGroups.first { $0.contains(bundleID) } ?? [bundleID]
    }

    func addGroup(_ bundleIDs: [String]) {
        let selectedIDs = Array(Set(bundleIDs.filter { $0 != "com.apple.finder" }))
        guard !selectedIDs.isEmpty else { return }

        let matchingGroups = appGroups.filter { group in
            !Set(group).isDisjoint(with: selectedIDs)
        }
        let mergedIDs = Set(matchingGroups.flatMap { $0 }).union(selectedIDs)
        appGroups.removeAll { group in !Set(group).isDisjoint(with: selectedIDs) }
        appGroups.append(Array(mergedIDs).sorted())
    }

    func removeGroup(at index: Int) {
        guard appGroups.indices.contains(index) else { return }
        appGroups.remove(at: index)
    }

    func addBundleID(_ newID: String, toGroupContaining existingID: String) {
        guard let idx = appGroups.firstIndex(where: { $0.contains(existingID) }) else { return }
        if !appGroups[idx].contains(newID) {
            appGroups[idx].append(newID)
        }
    }

    func removeFromGroup(_ bundleID: String) {
        for idx in appGroups.indices {
            appGroups[idx].removeAll { $0 == bundleID }
        }
        appGroups.removeAll { $0.isEmpty }
    }

    // MARK: - Colour helpers

    var nsTintColor: NSColor {
        let converted = NSColor(tintColor).usingColorSpace(.sRGB) ?? .black
        return converted.withAlphaComponent(CGFloat(tintOpacity))
    }

    private func saveTintColor(_ color: Color) {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        UserDefaults.standard.set(Double(srgb.redComponent),   forKey: Keys.tintRed)
        UserDefaults.standard.set(Double(srgb.greenComponent), forKey: Keys.tintGreen)
        UserDefaults.standard.set(Double(srgb.blueComponent),  forKey: Keys.tintBlue)
    }
}
