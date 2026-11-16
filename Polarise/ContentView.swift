//
//  ContentView.swift
//  Polarise
//
//  Created by Nikunj Mathur on 15/11/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var overlayManager: OverlayManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Polarise")
                .font(.headline)
            
            Toggle("Enable Screen Blur", isOn: $overlayManager.isOverlayEnabled)
                .toggleStyle(.switch)
        }
        .padding()
        .frame(width: 280, height: 160)
    }
}

#Preview {
    ContentView()
}
