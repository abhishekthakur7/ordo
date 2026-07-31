// OrdoUI — UI-chrome strings the C1 Theme protocol does not vend (the theme owns its
// voice; these structural strings have no token). Centralized here so a future
// localization or theme-voice pass has one place to move them from.

import Foundation

enum UIStrings {
    // Composer
    static let composerPlaceholder = "Add a task…"

    // Planning rail (mockup copy)
    static let railKicker = "Overview"
    static let railCompleted = "Completed"
    static let railRemaining = "Remaining"
    static let railTotal = "Total"
    static let railQuote = "Order is the shape\ncalm takes."

    // Triage affordance (§3.5)
    static let triagePrompt = "Carried a while."
    static let triageMoveToLongterm = "Move to Long-term"
    static let triageKeep = "Keep"
    static let triageDelete = "Delete"

    // Row actions / accessibility
    static let actionComplete = "Complete"
    static let actionReopen = "Reopen"
    static let actionDelete = "Delete"
    static let actionDoToday = "Do today"
    static let actionMoveToLongterm = "Move to Long-term"
    static let actionEdit = "Edit"
    static let actionPin = "Pin"
    static let actionUnpin = "Unpin"

    // Undo toast
    static let undoDeletedPrefix = "Deleted"
    static let undo = "Undo"

    // Settings
    static let settingsTitle = "Settings"
    static let settingsDone = "Done"
    static let launchAtLogin = "Launch at login"
    static let launchAtLoginConsent = "Open Ordo automatically when you log in. You can change this anytime."
    static let summonHotkey = "Summon hotkey"
    static let hotkeyRecordPrompt = "Click to record"
    static let hotkeyRecording = "Type a shortcut…"
    static let dayStartTitle = "Day starts at"
    static let dayStartHelp = "Advanced: when your logical day begins. Late-night tasks before this hour count as the previous day."
    static let themeTitle = "Theme"
    static let appearanceLabel = "Appearance"
    static let soundLabel = "Sound"

    // Large-paste confirm (§4.1)
    static func confirmPaste(_ count: Int) -> String { "Add \(count) tasks?" }
    static let confirmAdd = "Add all"
    static let confirmCancel = "Cancel"

    // Appearance segmented control
    static let appearanceAuto = "Auto"
    static let appearanceLight = "Light"
    static let appearanceDark = "Dark"

    static func deletedToast(_ title: String) -> String {
        let clipped = title.count > 32 ? String(title.prefix(32)) + "…" : title
        return "Deleted “\(clipped)”"
    }
}
