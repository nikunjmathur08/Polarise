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
    private var panel: FloatingPopoverPanel!
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    
    let overlaySettings = OverlaySettings()
    lazy var overlayManager = OverlayManager(settings: overlaySettings)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView(onResize: { [weak self] in
            self?.repositionPanel()
        })
            .environmentObject(overlayManager)
            .environmentObject(overlaySettings)
        
        panel = FloatingPopoverPanel(rootView: contentView)
        panel.onDismiss = { [weak self] in
            self?.closePanel()
        }
        
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
            togglePanel()
        }
    }
    
    private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }
    
    private func openPanel() {
        repositionPanel()
        panel.makeKeyAndOrderFront(nil)
        startEventMonitors()
    }
    
    func closePanel() {
        panel.orderOut(nil)
        stopEventMonitors()
    }
    
    func repositionPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let contentView = panel.contentView else { return }
        
        let size =  contentView.fittingSize
        let screen = buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        
        let edgeMargin: CGFloat = 10
        let topGap: CGFloat = 6
        
        let x = visible.maxX - size.width - edgeMargin
        let y = visible.maxY - size.height - topGap
        
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
    
    private func startEventMonitors() {
        stopEventMonitors()
        
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return }
            
            // Ignore clicks that land on the status-bar button itself —
            // those are handled by togglePanel() via the button action.
            if let button = self.statusItem.button,
               let buttonWindow = button.window {
                let locationInWindow = buttonWindow.convertPoint(fromScreen: NSEvent.mouseLocation)
                let buttonFrame = button.convert(button.bounds, to: nil)
                if buttonFrame.contains(locationInWindow) { return }
            }
            
            if NSColorPanel.shared.isVisible && NSColorPanel.shared.frame.contains(NSEvent.mouseLocation) {
                return
            }
            self.closePanel()
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.closePanel()
                return nil
            }
            return event
        }
    }
    
    private func stopEventMonitors() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }
    
    private func showRightClickMenu() {
        if panel.isVisible {
            closePanel()
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
