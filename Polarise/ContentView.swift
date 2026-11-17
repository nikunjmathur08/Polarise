//
//  ContentView.swift
//  Polarise
//
//  Created by Nikunj Mathur on 15/11/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var overlayManager: OverlayManager
    @EnvironmentObject var settings: OverlaySettings
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Polarise")
                .font(.headline)
            Toggle("", isOn: $overlayManager.isOverlayEnabled)
                .toggleStyle(.switch)
                .labelsHidden()

            Divider()
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Blur Radius")
                Spacer()
                Text("\(Int(settings.blurRadius))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.blurRadius, in: 0...80, step: 1)
        }
        
        HStack {
            Text("Tint Colour")
            Spacer()
            ColorPicker("", selection: $settings.tintColor, supportsOpacity: false)
                .labelsHidden()
        }
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Tint Opacity")
                Spacer()
                Text("\(Int(settings.tintOpacity * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.tintOpacity, in: 0...0.85, step: 0.01)
        }
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Grain Opacity")
                Spacer()
                Text("\(Int(settings.grainOpacity * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.grainOpacity, in: 0...0.25, step: 0.005)
        }
    }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    ContentView()
}
