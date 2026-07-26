// OrdoApp — StatusItemController: the menu-bar presence (ARCHITECTURE §4.2, §6.1).
// An NSStatusItem with the theme's template glyph; left-click toggles the panel (glyph
// accent-filled when open), right/control-click shows the Settings + Quit menu.

import AppKit
import OrdoThemes

@MainActor
final class StatusItemController: NSObject {

    private unowned let controller: AppController
    private let statusItem: NSStatusItem

    var button: NSStatusBarButton? { statusItem.button }

    init(controller: AppController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = controller.theme.menuBarGlyphImage()
            button.imagePosition = .imageOnly
            button.toolTip = "Ordo"
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Ordo")
        }
    }

    // MARK: Glyph / active state

    /// Whether the panel is currently open — the glyph reflects it.
    private var active = false

    func updateGlyph() {
        applyGlyph()
    }

    /// Reflect the panel's open/closed state on the glyph. The menu bar renders template
    /// images with its own vibrancy and ignores `contentTintColor`/`highlight`, so "on"
    /// swaps in a non-template accent-tinted copy; closed restores the template image.
    func setActive(_ active: Bool) {
        self.active = active
        applyGlyph()
    }

    private func applyGlyph() {
        guard let button = statusItem.button else { return }
        if active {
            button.image = Self.tinted(controller.theme.menuBarGlyphImage(),
                                       with: NSColor(controller.currentPalette.accent))
        } else {
            button.image = controller.theme.menuBarGlyphImage() // template
        }
    }

    /// A non-template copy of a template glyph, filled with `color` (source-atop so only
    /// the glyph's own pixels are colored).
    private static func tinted(_ base: NSImage, with color: NSColor) -> NSImage {
        let image = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            color.setFill()
            NSGraphicsContext.current?.compositingOperation = .sourceAtop
            NSBezierPath(rect: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: Click routing

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isRight {
            showMenu()
        } else {
            controller.togglePanel()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Ordo", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height + 4),
                   in: button)
    }

    @objc private func openSettings() {
        controller.openSettingsSurface()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
