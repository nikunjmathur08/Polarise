//
//  AppDelegate.swift
//  Polarise
//
//  Created by Nikunj Mathur on 16/11/26.
//

import Foundation
import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let overlaySettings = OverlaySettings()
    lazy var overlayManager = OverlayManager(settings: overlaySettings)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView()
            .environmentObject(overlayManager)
            .environmentObject(overlaySettings)
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 290)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Polarise")
            button.action = #selector(handleMouseClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc private func handleMouseClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            showRightClickMenu()
        } else {
            togglePopover(sender)
        }
    }
    
    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func showRightClickMenu() {
        if popover.isShown {
            popover.performClose(nil)
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Quit Polarise",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}
