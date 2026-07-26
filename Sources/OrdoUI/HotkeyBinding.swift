// OrdoUI — the global summon hotkey binding (ARCHITECTURE §4.4, §6.4, C5). UI captures
// a keyCode + modifier flags; the shell observes `AppSettings.hotkey` and does the
// actual Carbon/Cocoa registration. Codable so it round-trips through UserDefaults.

import Foundation
import AppKit

/// A key combination: a virtual key code plus modifier flags. `modifiers` stores
/// `NSEvent.ModifierFlags.rawValue` masked to the device-independent flags.
public struct HotkeyBinding: Codable, Equatable, Sendable, Hashable {
    /// Virtual key code (kVK_* / `NSEvent.keyCode`).
    public var keyCode: UInt16
    /// `NSEvent.ModifierFlags` raw value (device-independent subset).
    public var modifiers: UInt

    public init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public init(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = flags.intersection(.deviceIndependentFlagsMask).rawValue
    }

    /// The flags as an `NSEvent.ModifierFlags` value.
    public var flags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.deviceIndependentFlagsMask)
    }

    /// The default summon hotkey: ⌃⌥Space (Control-Option-Space), key code 49 = Space.
    public static let `default` = HotkeyBinding(
        keyCode: 49,
        flags: [.control, .option]
    )

    /// True when a binding actually carries modifiers (an unmodified key is rejected
    /// by the recorder as a valid global hotkey).
    public var hasModifiers: Bool {
        !flags.intersection([.command, .control, .option, .shift]).isEmpty
    }

    /// A human-readable representation, e.g. "⌃⌥Space".
    public var displayString: String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        s += HotkeyBinding.keyName(for: keyCode)
        return s
    }

    /// A best-effort printable name for a virtual key code.
    static func keyName(for keyCode: UInt16) -> String {
        if let named = specialKeyNames[keyCode] { return named }
        return literalKeyNames[keyCode] ?? "Key \(keyCode)"
    }

    private static let specialKeyNames: [UInt16: String] = [
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
    ]

    private static let literalKeyNames: [UInt16: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H",
        34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P",
        12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9",
    ]
}
