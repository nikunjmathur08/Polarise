//
//  PolariseApp.swift
//  Polarise
//
//  Created by Nikunj Mathur on 15/11/26.
//

import SwiftUI

@main
struct PolariseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
