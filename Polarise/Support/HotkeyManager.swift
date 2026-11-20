//
//  HotkeyManager.swift
//  Polarise
//
//  Created by Nikunj Mathur on 19/11/26.
//

import Foundation
import AppKit
import Carbon

enum PolariseHotkey: UInt32, CaseIterable {
    case toggleOverlay    = 1
    case switchMode       = 2
    case ignoreCurrentApp = 3
    case toggleControls   = 4
}

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String? = nil
}

final class HotkeyManager {
    static let shared = HotkeyManager()

    var handlers: [PolariseHotkey: () -> Void] = [:]

    private var registeredRefs: [PolariseHotkey: EventHotKeyRef] = [:]

    private var eventHandlerRef: EventHandlerRef?

    private init() {
        installCarbonEventHandler()
    }

    private func installCarbonEventHandler() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )

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

    private func handleHotKeyPressed(id: UInt32) {
        guard let hotkey = PolariseHotkey(rawValue: id) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.handlers[hotkey]?()
        }
    }
    
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

    func unregister(_ hotkey: PolariseHotkey) {
        guard let ref = registeredRefs[hotkey] else { return }
        UnregisterEventHotKey(ref)
        registeredRefs.removeValue(forKey: hotkey)
    }

    func unregisterAll() {
        for (hotkey, ref) in registeredRefs {
            UnregisterEventHotKey(ref)
            registeredRefs.removeValue(forKey: hotkey)
        }
    }

    func loadAndRegisterAll() {
        migrateLegacyBindingsIfNeeded()
        for hotkey in PolariseHotkey.allCases {
            let binding = loadBinding(for: hotkey) ?? defaultBinding(for: hotkey)
            guard let binding else { continue }
            if loadBinding(for: hotkey) == nil { saveBinding(binding, for: hotkey) }
            register(hotkey, binding: binding)
        }
    }

    private func migrateLegacyBindingsIfNeeded() {
        let migrationKey = "polarise.hotkey.schemaVersion"
        guard UserDefaults.standard.integer(forKey: migrationKey) < 2 else { return }
        for identifier in 1...5 {
            UserDefaults.standard.removeObject(forKey: "polarise.hotkey.\(identifier)")
        }
        UserDefaults.standard.set(2, forKey: migrationKey)
    }

    private func defaultsKey(for hotkey: PolariseHotkey) -> String {
        "polarise.hotkey.\(hotkey.rawValue)"
    }

    func saveBinding(_ binding: HotkeyBinding, for hotkey: PolariseHotkey) {
        if let data = try? JSONEncoder().encode(binding) {
            UserDefaults.standard.set(data, forKey: defaultsKey(for: hotkey))
        }
    }

    func loadBinding(for hotkey: PolariseHotkey) -> HotkeyBinding? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey(for: hotkey)) else {
            return nil
        }
        return try? JSONDecoder().decode(HotkeyBinding.self, from: data)
    }

    func removeBinding(for hotkey: PolariseHotkey) {
        UserDefaults.standard.removeObject(forKey: defaultsKey(for: hotkey))
        unregister(hotkey)
    }

    func defaultBinding(for hotkey: PolariseHotkey) -> HotkeyBinding? {
        let modifiers = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)
        switch hotkey {
        case .toggleOverlay:    return HotkeyBinding(keyCode:  3, modifiers: modifiers, keyLabel: "F")
        case .switchMode:       return HotkeyBinding(keyCode: 46, modifiers: modifiers, keyLabel: "M")
        case .ignoreCurrentApp: return HotkeyBinding(keyCode: 14, modifiers: modifiers, keyLabel: "E")
        case .toggleControls:   return HotkeyBinding(keyCode:  8, modifiers: modifiers, keyLabel: "C")
        }
    }

    func carbonModifiers(from nsFlags: NSEvent.ModifierFlags) -> UInt32 {
        var c: UInt32 = 0
        if nsFlags.contains(.command) { c |= UInt32(cmdKey) }
        if nsFlags.contains(.option)  { c |= UInt32(optionKey) }
        if nsFlags.contains(.control) { c |= UInt32(controlKey) }
        if nsFlags.contains(.shift)   { c |= UInt32(shiftKey) }
        return c
    }
}

private func fourCharCode(_ string: StaticString) -> FourCharCode {
    assert(string.utf8CodeUnitCount == 4, "fourCharCode requires exactly 4 characters")
    let bytes = string.utf8Start
    return FourCharCode(bytes[0]) << 24
         | FourCharCode(bytes[1]) << 16
         | FourCharCode(bytes[2]) << 8
         | FourCharCode(bytes[3])
}
