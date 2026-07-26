// OrdoApp — executable entry point (PLAN.md phase 3, ARCHITECTURE §6.1).
// Menu-bar-only (accessory) NSApplication; drives the run loop directly (no @main) so
// the same code path works under `swift run` and the bundled app. Wiring lives in AppController.

import AppKit

// The process starts on the main thread == the main actor; everything the shell
// touches (store, model, AppKit) is main-actor confined.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    // Accessory: no Dock icon, no menu bar; the app lives entirely in the status bar
    // and its NSPanel. Works identically with or without a bundle (Info.plist also
    // sets LSUIElement for the bundled case).
    app.setActivationPolicy(.accessory)

    let controller = AppController()
    app.delegate = controller

    // run() blocks until termination, keeping `controller` (held only weakly by
    // NSApp.delegate) alive for the app's lifetime.
    app.run()
}
