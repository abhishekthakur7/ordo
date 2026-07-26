// OrdoApp — Notices: builds the calm, one-shot launch NSAlerts (store diagnostics,
// first-run launch-at-login consent §4.2, hotkey-unavailable note §4.4). AppController
// presents them as sheets (never a blocking runModal) so a headless launch never hangs.

import AppKit
import OrdoCore
import OrdoUI

enum Notices {

    /// A single diagnostic alert if the store loaded with a notable condition, else nil.
    static func storeNoticeAlert(store: TaskStore) -> NSAlert? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        if store.corruptionNotice {
            alert.messageText = "Your task file couldn't be read"
            alert.informativeText = store.restoredFromBackup
                ? "Ordo restored the most recent good backup. A copy of the unreadable file was set aside."
                : "The unreadable file was set aside and Ordo started fresh. A copy was kept in case you need it."
        } else if store.restoredFromBackup {
            alert.messageText = "Restored from a backup"
            alert.informativeText = "Ordo recovered your tasks from the most recent backup."
        } else if let from = store.migratedFrom {
            alert.messageText = "Your tasks were upgraded"
            alert.informativeText = "Ordo updated your task file from an earlier format (v\(from)). A pre-upgrade backup was kept."
        } else {
            return nil
        }
        alert.addButton(withTitle: "OK")
        return alert
    }

    /// The first-run launch-at-login consent alert.
    static func firstRunConsentAlert() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Open Ordo automatically at login?"
        alert.informativeText = "Ordo lives quietly in the menu bar. You can change this anytime in Settings."
        alert.addButton(withTitle: "Yes, launch at login")
        alert.addButton(withTitle: "Not now")
        return alert
    }

    /// The hotkey-unavailable note.
    static func hotkeyUnavailableAlert(binding: HotkeyBinding) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Couldn't set the summon shortcut"
        alert.informativeText = "\(binding.displayString) is already in use by another app, so Ordo left the shortcut unset. Pick a different one in Settings."
        alert.addButton(withTitle: "OK")
        return alert
    }
}
