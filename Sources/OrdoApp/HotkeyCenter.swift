// OrdoApp — HotkeyCenter: the global summon hotkey (ARCHITECTURE §4.4).
// Uses Carbon's RegisterEventHotKey — needs no Accessibility permission and works for
// an accessory app. Registration failure degrades gracefully to unbound (never crashes).

import AppKit
import Carbon.HIToolbox
import OrdoUI

@MainActor
final class HotkeyCenter {

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?

    private static let signature: OSType = {
        // Four-char code 'ORDO'.
        let chars = Array("ORDO".utf8)
        return (OSType(chars[0]) << 24) | (OSType(chars[1]) << 16) | (OSType(chars[2]) << 8) | OSType(chars[3])
    }()
    private static let hotKeyID: UInt32 = 1

    /// Register `binding` as a global hotkey firing `action`. Returns false on failure
    /// (already unregisters any previous binding first).
    @discardableResult
    func register(_ binding: HotkeyBinding, action: @escaping () -> Void) -> Bool {
        unregister()
        guard binding.hasModifiers else { return false } // unmodified keys are rejected

        self.action = action

        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(binding.keyCode),
            Self.carbonModifiers(from: binding.flags),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref)

        guard status == noErr, let ref else {
            self.action = nil
            return false
        }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        action = nil
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData, let event else { return noErr }
                var hkID = EventHotKeyID()
                let err = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                            EventParamType(typeEventHotKeyID), nil,
                                            MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                guard err == noErr, hkID.id == HotkeyCenter.hotKeyID else { return noErr }
                let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { center.fire() }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandler)
    }

    private func fire() {
        action?()
    }

    /// Map device-independent NSEvent modifier flags to Carbon modifier bits.
    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
    }
}
