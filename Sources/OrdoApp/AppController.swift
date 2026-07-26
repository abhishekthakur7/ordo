// OrdoApp — AppController: the NSApplicationDelegate that assembles the modules into
// a running menu-bar app and owns every long-lived collaborator.
// The whole app is main-actor confined (the store + model require it).

import AppKit
import SwiftUI
import Observation
import OrdoCore
import OrdoThemes
import OrdoSound
import OrdoUI

@MainActor
final class AppController: NSObject, NSApplicationDelegate {

    // Distributed notification a second instance uses to ask the first to reveal.
    static let showPanelNotification = Notification.Name("com.ordo.Ordo.showPanel")

    // Long-lived collaborators.
    let clock: OrdoClock
    let store: TaskStore
    let settings: AppSettings
    let sounds: any SoundPlaying
    let model: AppModel

    private(set) var theme: any Theme

    // Sub-controllers.
    private var statusItem: StatusItemController!
    private var panel: PanelController!
    private var triggers: TriggerCenter!
    private var hotkey: HotkeyCenter!
    private var loginItem: LoginItemCenter!

    private var appearanceObservation: NSKeyValueObservation?

    // Exclusive advisory lock proving single-instance ownership (held for the app's life).
    private var instanceLockFD: Int32 = -1

    // Snapshot of settings used to detect *what* changed on each observation tick.
    private var lastHotkey: HotkeyBinding
    private var lastAppearance: AppAppearance
    private var lastThemeID: ThemeID
    private var lastLaunchEnabled: Bool
    private var lastLaunchConsented: Bool
    private var lastSoundEnabled: Bool

    override init() {
        // Clock is shared by the store and the model so time is single-sourced (C6).
        let clock = SystemClock()
        self.clock = clock
        self.store = TaskStore(directory: Persistence.defaultDirectory, clock: clock)
        self.settings = AppSettings()

        let theme = ThemeRegistry.shared.theme(idOrDefault: settings.themeID)
        self.theme = theme

        // Real audio engine off the bundle; isEnabled synced from the saved pref.
        let engine = SoundEngine(soundSet: theme.soundSet)
        engine.isEnabled = settings.soundEnabled
        self.sounds = engine

        self.model = AppModel(store: store, clock: clock, theme: theme, settings: settings, sounds: engine)

        self.lastHotkey = settings.hotkey
        self.lastAppearance = settings.appearance
        self.lastThemeID = settings.themeID
        self.lastLaunchEnabled = settings.launchAtLoginEnabled
        self.lastLaunchConsented = settings.launchAtLoginConsented
        self.lastSoundEnabled = settings.soundEnabled

        super.init()
    }

    // MARK: NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard (skipped gracefully under `swift run`, where there
        // is no bundle identifier).
        if enforceSingleInstance() == .terminate { return }

        // Edit menu: an accessory app shows no menu bar, but without it the standard
        // ⌘X/⌘C/⌘V/⌘A key equivalents have nowhere to dispatch, so text fields can't
        // cut/copy/paste. nil targets route to the focused field editor.
        installMainMenu()

        // Seed the model's live appearance from the real system before first show.
        model.systemIsDark = Self.systemIsDark

        // Build the shell.
        panel = PanelController(controller: self)
        statusItem = StatusItemController(controller: self)
        hotkey = HotkeyCenter()
        loginItem = LoginItemCenter()
        triggers = TriggerCenter(model: model, store: store, clock: clock)

        // Rollover triggers (§3.3) + external-edit watcher.
        triggers.start()

        // Global summon hotkey (§4.4).
        registerHotkey()

        // Appearance: observe both the system effective appearance and the setting.
        observeAppearance()
        applyAppearance()

        // React to in-panel settings changes (hotkey, login item, sound, theme, appearance).
        observeSettings()

        // Launch-at-login: only acts once the user has consented (§4.2/§6.4).
        syncLoginItem()

        // Distributed reveal from a second launch.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleRemoteShow),
            name: Self.showPanelNotification, object: nil)

        // One-shot store notices (corruption / restored / migrated) — non-blocking sheet.
        if let notice = Notices.storeNoticeAlert(store: store) {
            presentNotice(notice, ensureVisible: true)
        }

        // Launch diagnostic (stderr) — lets a headless smoke confirm the shell came up
        // and the status item was created without asserting the menu bar visually.
        FileHandle.standardError.write(Data(
            "OrdoApp: shell up — statusItem=\(statusItem.button != nil), firstLaunch=\(store.isFirstLaunch), hotkey=\(settings.hotkey.displayString)\n".utf8))

        // First run: reveal the panel so the empty state greets the user, then ask
        // once (as a calm sheet) about launching at login.
        if store.isFirstLaunch {
            showPanel()
            if !settings.launchAtLoginConsented {
                presentNotice(Notices.firstRunConsentAlert(), ensureVisible: true) { [weak self] response in
                    guard let self else { return }
                    self.settings.launchAtLoginEnabled = (response == .alertFirstButtonReturn)
                    self.settings.launchAtLoginConsented = true
                    self.syncLoginItem()
                }
            }
        }

        // Debug-only: reveals the panel on launch when this env var is set.
        if ProcessInfo.processInfo.environment["ORDO_DEBUG_OPEN_PANEL"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showPanel()
            }
        }
    }

    /// Present a calm NSAlert as a sheet on the panel window (never a blocking runModal,
    /// so a headless launch never hangs). Optionally reveals the panel first.
    private func presentNotice(_ alert: NSAlert,
                               ensureVisible: Bool,
                               handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        if ensureVisible { showPanel() }
        panel.beginSheet(alert) { response in handler?(response) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Drain deferred work + flush to disk through the model (never the store
        // directly), then stop watchers.
        model.panelDidClose()
        store.flush()
        triggers.stop()
        hotkey.unregister()
        store.stopWatchingExternalEdits()
        releaseInstanceLock()
    }

    // MARK: Main menu (Edit-menu key equivalents for text fields)

    private func installMainMenu() {
        let mainMenu = NSMenu()

        // App menu — gives the bar a valid first submenu and a ⌘Q.
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Ordo",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Edit menu — first-responder dispatch (nil target) to the field editor.
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    // MARK: Panel toggle (status item, hotkey, remote reveal)

    func togglePanel() {
        if panel.isVisible {
            panel.requestClose()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard !panel.isVisible else { return }
        panel.show(from: statusItem.button)
        statusItem.setActive(true)
        sounds.play(.panelOpen)
    }

    /// Called by the panel once its exit animation finishes hiding it.
    func panelDidHide() {
        statusItem.setActive(false)
    }

    func openSettingsSurface() {
        showPanel()
        model.settingsOpen = true
    }

    @objc private func handleRemoteShow() {
        showPanel()
    }

    // MARK: Single-instance guard

    private enum InstanceDecision { case proceed, terminate }

    private func enforceSingleInstance() -> InstanceDecision {
        guard Bundle.main.bundleIdentifier != nil else { return .proceed } // swift run
        // Acquire an exclusive advisory lock BEFORE the NSRunningApplication check to
        // close its read-then-decide TOCTOU race (two launches can each observe zero
        // others and both proceed). The flock is atomic; whoever loses bows out.
        if !acquireInstanceLock() {
            DistributedNotificationCenter.default().postNotificationName(
                Self.showPanelNotification, object: nil, userInfo: nil, deliverImmediately: true)
            NSApp.terminate(nil)
            return .terminate
        }
        return .proceed
    }

    /// Try to take the exclusive lockfile in the store directory. Returns false only
    /// when another live instance already holds it. A lock we cannot even create
    /// (unwritable dir) does not block launch — the app still runs, just unguarded.
    private func acquireInstanceLock() -> Bool {
        let dir = Persistence.defaultDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let lockURL = dir.appendingPathComponent("ordo.lock")
        let fd = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return true }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
        instanceLockFD = fd
        return true
    }

    private func releaseInstanceLock() {
        guard instanceLockFD >= 0 else { return }
        flock(instanceLockFD, LOCK_UN)
        close(instanceLockFD)
        instanceLockFD = -1
    }

    // MARK: Hotkey

    private func registerHotkey() {
        let ok = hotkey.register(settings.hotkey) { [weak self] in
            self?.togglePanel()
        }
        if !ok {
            // Graceful fallback: unbound. Surface a single calm note if the panel is
            // showing; never crash, never retry-loop.
            if panel?.isVisible == true {
                presentNotice(Notices.hotkeyUnavailableAlert(binding: settings.hotkey), ensureVisible: false)
            }
        }
    }

    // MARK: Settings observation (Observation framework)

    private func observeSettings() {
        withObservationTracking {
            _ = settings.hotkey
            _ = settings.appearance
            _ = settings.themeID
            _ = settings.launchAtLoginEnabled
            _ = settings.launchAtLoginConsented
            _ = settings.soundEnabled
        } onChange: { [weak self] in
            // onChange fires just before the value changes; hop to main to read the
            // new values and re-arm the observation.
            Task { @MainActor in
                guard let self else { return }
                self.settingsDidChange()
                self.observeSettings()
            }
        }
    }

    private func settingsDidChange() {
        if settings.hotkey != lastHotkey {
            lastHotkey = settings.hotkey
            hotkey.unregister()
            registerHotkey()
        }
        if settings.themeID != lastThemeID {
            lastThemeID = settings.themeID
            applyTheme()
        }
        if settings.appearance != lastAppearance {
            lastAppearance = settings.appearance
            applyAppearance()
        }
        if settings.soundEnabled != lastSoundEnabled {
            lastSoundEnabled = settings.soundEnabled
            sounds.isEnabled = settings.soundEnabled
        }
        if settings.launchAtLoginEnabled != lastLaunchEnabled
            || settings.launchAtLoginConsented != lastLaunchConsented {
            lastLaunchEnabled = settings.launchAtLoginEnabled
            lastLaunchConsented = settings.launchAtLoginConsented
            syncLoginItem()
        }
    }

    // MARK: Theme

    private func applyTheme() {
        let newTheme = ThemeRegistry.shared.theme(idOrDefault: settings.themeID)
        theme = newTheme
        model.theme = newTheme
        statusItem.updateGlyph()
        panel.themeChanged()
    }

    // MARK: Appearance

    static var systemIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func observeAppearance() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.applyAppearance() }
        }
    }

    private func applyAppearance() {
        let dark = Self.systemIsDark
        model.systemIsDark = dark
        panel.applyAppearance(setting: settings.appearance, systemIsDark: dark)
    }

    // MARK: Login item

    private func syncLoginItem() {
        loginItem.sync(enabled: settings.launchAtLoginEnabled,
                       consented: settings.launchAtLoginConsented)
    }

    // MARK: Resolved appearance helper for the shell

    var resolvedAppearance: ResolvedUIAppearance {
        resolveAppearance(settings.appearance, systemIsDark: Self.systemIsDark)
    }

    var currentPalette: Palette {
        let a = AccessibilityOptions(
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)
        return theme.palette(for: resolvedAppearance.themeAppearance, accessibility: a)
    }
}
