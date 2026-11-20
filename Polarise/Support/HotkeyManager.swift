//
//  HotkeyManager.swift
//  Polarise
//
//  Created by Nikunj Mathur on 19/11/26.
//

import Foundation
import AppKit
import Carbon

// MARK: - Hotkey identifiers

enum PolariseHotkey: UInt32, CaseIterable {
    case toggleOverlay    = 1
    case ignoreCurrentApp = 2
    case blurUp           = 3
    case blurDown         = 4
    case toggleAppFocus   = 5
}

// MARK: - Stored binding

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon modifier flags (cmdKey, optionKey, etc.)
    var keyLabel: String? = nil
}

// MARK: - HotkeyManager

final class HotkeyManager {

    // MARK: Singleton

    static let shared = HotkeyManager()

    // MARK: Handlers

    /// Registered action handlers, keyed by PolariseHotkey.
    var handlers: [PolariseHotkey: () -> Void] = [:]

    // MARK: Private state

    /// Maps each registered hotkey to its Carbon EventHotKeyRef.
    private var registeredRefs: [PolariseHotkey: EventHotKeyRef] = [:]

    /// The single application-level Carbon event handler installed in init.
    private var eventHandlerRef: EventHandlerRef?

    // MARK: - Init

    private init() {
        installCarbonEventHandler()
    }

    // MARK: - Carbon event handler installation

    private func installCarbonEventHandler() {
        // We need a pointer to self so the C callback can reach us.
        // We store it as an unretained raw pointer — the manager lives for
        // the whole app lifetime, so this is safe.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )

        // The C callback: reads the EventHotKeyID and routes to the Swift handler.
        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return OSStatus(eventNotHandledErr) }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handleHotKeyPressed(id: hotKeyID.id)
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
    }

    // MARK: - Hot-key dispatch (called from C callback, already on main thread)

    private func handleHotKeyPressed(id: UInt32) {
        guard let hotkey = PolariseHotkey(rawValue: id) else { return }
        // Carbon callbacks fire on the main thread, but dispatch to be explicit.
        DispatchQueue.main.async { [weak self] in
            self?.handlers[hotkey]?()
        }
    }

    // MARK: - Registration

    /// Registers `hotkey` with the given `binding`. If a previous registration
    /// exists for this hotkey, it is unregistered first.
    func register(_ hotkey: PolariseHotkey, binding: HotkeyBinding) {
        // Always unregister old Carbon ref first to avoid duplicates.
        unregister(hotkey)

        var hotKeyID = EventHotKeyID(signature: fourCharCode("PLRS"), id: hotkey.rawValue)
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            registeredRefs[hotkey] = ref
        } else {
            NSLog("[HotkeyManager] Failed to register hotkey \(hotkey) — OSStatus \(status)")
        }
    }

    /// Unregisters the Carbon hotkey for `hotkey` (if any). Does NOT remove
    /// the entry from `handlers`.
    func unregister(_ hotkey: PolariseHotkey) {
        guard let ref = registeredRefs[hotkey] else { return }
        UnregisterEventHotKey(ref)
        registeredRefs.removeValue(forKey: hotkey)
    }

    /// Unregisters every Carbon hotkey and clears the internal ref map.
    /// Does NOT clear `handlers`.
    func unregisterAll() {
        for (hotkey, ref) in registeredRefs {
            UnregisterEventHotKey(ref)
            registeredRefs.removeValue(forKey: hotkey)
        }
    }

    // MARK: - Bulk load

    /// Reads all saved bindings from UserDefaults and registers each one.
    /// Only hotkeys that the user has explicitly saved are registered.
    func loadAndRegisterAll() {
        for hotkey in PolariseHotkey.allCases {
            if let binding = loadBinding(for: hotkey) {
                register(hotkey, binding: binding)
            }
        }
    }

    // MARK: - Persistence

    private func defaultsKey(for hotkey: PolariseHotkey) -> String {
        "polarise.hotkey.\(hotkey.rawValue)"
    }

    /// Persists `binding` to UserDefaults for the given hotkey.
    func saveBinding(_ binding: HotkeyBinding, for hotkey: PolariseHotkey) {
        if let data = try? JSONEncoder().encode(binding) {
            UserDefaults.standard.set(data, forKey: defaultsKey(for: hotkey))
        }
    }

    /// Returns the user-saved binding for `hotkey`, or `nil` if none has been saved.
    func loadBinding(for hotkey: PolariseHotkey) -> HotkeyBinding? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey(for: hotkey)) else {
            return nil
        }
        return try? JSONDecoder().decode(HotkeyBinding.self, from: data)
    }

    /// Returns the factory-default binding for `hotkey`.
    /// These are for UI display only; they are NOT auto-registered.
    func defaultBinding(for hotkey: PolariseHotkey) -> HotkeyBinding? {
        let cmdOpt = UInt32(cmdKey) | UInt32(optionKey)
        switch hotkey {
        case .toggleOverlay:    return HotkeyBinding(keyCode: 11, modifiers: cmdOpt) // ⌥⌘B
        case .ignoreCurrentApp: return HotkeyBinding(keyCode: 34, modifiers: cmdOpt) // ⌥⌘I
        case .blurUp:           return HotkeyBinding(keyCode: 30, modifiers: cmdOpt) // ⌥⌘]
        case .blurDown:         return HotkeyBinding(keyCode: 33, modifiers: cmdOpt) // ⌥⌘[
        case .toggleAppFocus:   return HotkeyBinding(keyCode:  3, modifiers: cmdOpt) // ⌥⌘F
        }
    }

    // MARK: - NSEvent modifier conversion

    /// Converts NSEvent modifier flags to their Carbon equivalents.
    func carbonModifiers(from nsFlags: NSEvent.ModifierFlags) -> UInt32 {
        var c: UInt32 = 0
        if nsFlags.contains(.command) { c |= UInt32(cmdKey) }
        if nsFlags.contains(.option)  { c |= UInt32(optionKey) }
        if nsFlags.contains(.control) { c |= UInt32(controlKey) }
        if nsFlags.contains(.shift)   { c |= UInt32(shiftKey) }
        return c
    }
}

// MARK: - FourCharCode helper

/// Converts a 4-character string literal into a Carbon FourCharCode / OSType.
private func fourCharCode(_ string: StaticString) -> FourCharCode {
    assert(string.utf8CodeUnitCount == 4, "fourCharCode requires exactly 4 characters")
    let bytes = string.utf8Start
    return FourCharCode(bytes[0]) << 24
         | FourCharCode(bytes[1]) << 16
         | FourCharCode(bytes[2]) << 8
         | FourCharCode(bytes[3])
}
