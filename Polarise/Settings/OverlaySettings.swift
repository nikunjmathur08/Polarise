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
    case deep = "Deep"
    
    var id: String { rawValue }
}

final class OverlaySettings: ObservableObject {
    private enum Keys {
        static let blurRadius = "polarise.blurRadius"
        static let tintRed = "polarise.tintRed"
        static let tintGreen = "polarise.tintGreen"
        static let tintBlue = "polarise.tintBlue"
        static let tintOpacity = "polarise.tintOpacity"
        static let grainOpacity = "polarise.grainOpactiy"
        static let preset = "polarise.preset"
        static let ignoredBundleIDs = "polarise.ignoredBundleIDs"
    }
    
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
        didSet { UserDefaults.standard.set(tintOpacity, forKey: Keys.tintOpacity)}
    }
    
    @Published var grainOpacity: Double {
        didSet { UserDefaults.standard.set(grainOpacity, forKey: Keys.grainOpacity) }
    }
    
    @Published var ignoredBundleIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(ignoredBundleIDs), forKey: Keys.ignoredBundleIDs)
        }
    }
    
    init() {
        let defaults = UserDefaults.standard
        
        let savedPreset = defaults.string(forKey: Keys.preset).flatMap(PolarisePreset.init(rawValue:)) ?? .deep
        self.currentPreset = savedPreset
        
        self.blurRadius = defaults.object(forKey: Keys.blurRadius) as? Double ?? 24.0
        self.tintOpacity = defaults.object(forKey: Keys.tintOpacity) as? Double ?? 0.25
        self.grainOpacity = defaults.object(forKey: Keys.grainOpacity) as? Double ?? 0.04
        
        if defaults.object(forKey: Keys.tintRed) != nil {
            let r = defaults.double(forKey: Keys.tintRed)
            let g = defaults.double(forKey: Keys.tintGreen)
            let b = defaults.double(forKey: Keys.tintBlue)
            self.tintColor = Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
        } else {
            self.tintColor = Color(.sRGB, red: 0.08, green: 0.09, blue: 0.12, opacity: 1.0)
        }
        
        let savedIgnored = defaults.stringArray(forKey: Keys.ignoredBundleIDs) ?? []
        self.ignoredBundleIDs = Set(savedIgnored)
    }
    
    func applyPreset(_ preset: PolarisePreset) {
        currentPreset = preset
        switch preset {
        case .medium:
            blurRadius = 34
            tintOpacity = 0.18
            grainOpacity = 0.05
        case .deep:
            blurRadius = 56
            tintOpacity = 0.30
            grainOpacity = 0.08
        }
    }
    
    func toggleIgnored(bundleID: String) {
        if ignoredBundleIDs.contains(bundleID) {
            ignoredBundleIDs.remove(bundleID)
        } else {
            ignoredBundleIDs.insert(bundleID)
        }
    }
    
    var nsTintColor: NSColor {
        let converted = NSColor(tintColor).usingColorSpace(.sRGB) ?? .black
        return converted.withAlphaComponent(CGFloat(tintOpacity))
    }
    
    private func saveTintColor(_ color: Color) {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        UserDefaults.standard.set(Double(srgb.redComponent), forKey: Keys.tintRed)
        UserDefaults.standard.set(Double(srgb.greenComponent), forKey: Keys.tintGreen)
        UserDefaults.standard.set(Double(srgb.blueComponent), forKey: Keys.tintBlue)
    }
}
