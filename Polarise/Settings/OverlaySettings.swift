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

final class OverlaySettings: ObservableObject {
    private enum Keys {
        static let blurRadius = "polarise.blurRadius"
        static let tintRed = "polarise.tintRed"
        static let tintGreen = "polarise.tintGreen"
        static let tintBlue = "polarise.tintBlue"
        static let tintOpacity = "polarise.tintOpacity"
        static let grainOpacity = "polarise.grainOpactiy"
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
    
    init() {
        let defaults = UserDefaults.standard
        
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
