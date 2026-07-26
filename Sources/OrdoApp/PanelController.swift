// OrdoApp — PanelController: owns the borderless, non-activating NSPanel, hosts
// PanelRootView over the glass background, implements the PanelChrome bridge (C4, §4.2/§6.1).
// Animates entrance/exit + expand-morph, closes on click-outside; hidden ≠ deallocated.

import AppKit
import SwiftUI
import OrdoCore
import OrdoThemes
import OrdoUI

@MainActor
final class PanelController: NSObject, PanelChrome {

    private unowned let controller: AppController
    private let window: PanelWindow
    private let background: PanelBackgroundView
    private let hosting: NSHostingView<PanelRootView>

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private var interactionHold = false
    private(set) var isVisible = false

    /// The status-item button we anchored to (for re-positioning on expand).
    private weak var anchorButton: NSStatusBarButton?

    init(controller: AppController) {
        self.controller = controller
        let metrics = controller.theme.metrics

        self.background = PanelBackgroundView(metrics: metrics)

        // The window is created oversized (panel + shadow/beak margins) and lives for
        // the app's lifetime; it is ordered out (not released) on close.
        let initialSize = PanelController.windowSize(for: metrics.panelCompactSize)
        self.window = PanelWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)

        self.hosting = NSHostingView(rootView: PanelRootView(model: controller.model, chrome: ThisChromeBox.placeholder))

        super.init()

        // Rebuild the hosting view now that `self` exists (PanelRootView needs the
        // real chrome = self); also wire the model → chrome bridge so drag interaction
        // can hold click-outside dismissal (§4.2).
        hosting.rootView = PanelRootView(model: controller.model, chrome: self)
        controller.model.chrome = self
        hosting.translatesAutoresizingMaskIntoConstraints = true

        configureWindow()
        background.frame = NSRect(origin: .zero, size: initialSize)
        background.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(background)
        background.hostingView = hosting

        applyAppearance(setting: controller.settings.appearance, systemIsDark: AppController.systemIsDark)
    }

    private func configureWindow() {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false // we render the shadow ourselves in the background view
        window.level = .statusBar
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false

        let host = NSView()
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = host
    }

    // MARK: PanelChrome

    func requestClose() {
        hide(animated: true)
    }

    func setExpanded(_ expanded: Bool) {
        morphFrame(expanded: expanded, animated: true)
    }

    func notifyInteraction(active: Bool) {
        interactionHold = active
    }

    // MARK: Sheet presentation (calm, non-blocking notices)

    /// Attach an alert as a sheet on the panel window. Non-blocking; skips gracefully
    /// if the panel isn't currently on screen.
    func beginSheet(_ alert: NSAlert, handler: @escaping (NSApplication.ModalResponse) -> Void) {
        guard isVisible else { return }
        // A sheet counts as interior interaction — don't dismiss on click-outside.
        interactionHold = true
        alert.beginSheetModal(for: window) { [weak self] response in
            self?.interactionHold = false
            handler(response)
        }
    }

    // MARK: Show / hide

    func show(from button: NSStatusBarButton?) {
        guard !isVisible else { return }
        anchorButton = button

        // Restore the remembered expanded state and size the window BEFORE showing,
        // so the panel appears at its final size (morph only on explicit toggle).
        let expanded = controller.settings.panelExpanded
        let panelSize = expanded ? controller.theme.metrics.panelExpandedSize
                                 : controller.theme.metrics.panelCompactSize
        let winSize = PanelController.windowSize(for: panelSize)
        window.setContentSize(winSize)
        background.frame = NSRect(origin: .zero, size: winSize)

        // Lifecycle: catch up + reset to Today happens in the model before we show.
        controller.model.panelWillOpen()

        position(for: panelSize)

        window.orderFrontRegardless()
        window.makeKey() // key WITHOUT activating the app (non-activating panel)

        isVisible = true
        installMonitors()
        animateEntrance()
    }

    func hide(animated: Bool) {
        guard isVisible else { return }
        isVisible = false
        removeMonitors()

        let finish: () -> Void = { [weak self] in
            guard let self else { return }
            self.window.orderOut(nil)
            self.controller.model.panelDidClose()
            self.controller.panelDidHide()
            self.controller.sounds.play(.panelClose)
        }

        if animated {
            animateExit(completion: finish)
        } else {
            finish()
        }
    }

    // MARK: Entrance / exit animation

    private func animateEntrance() {
        guard let layer = background.layer else { return }
        let reduce = Self.systemReduceMotion
        setAnchorPoint(CGPoint(x: 0.88, y: 1.0), for: background)

        let motion = controller.theme.motion.panelEnter
        let duration = reduce ? motion.reducedDuration : motion.duration

        layer.removeAllAnimations()
        if reduce {
            layer.opacity = 1
            layer.transform = CATransform3DIdentity
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0; fade.toValue = 1; fade.duration = duration
            layer.add(fade, forKey: "enter")
            return
        }

        let from = entranceTransform()
        layer.transform = CATransform3DIdentity
        layer.opacity = 1

        let timing = Self.timingFunction(for: motion.curve)
        let group = CAAnimationGroup()
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0; opacity.toValue = 1
        let transform = CABasicAnimation(keyPath: "transform")
        transform.fromValue = NSValue(caTransform3D: from)
        transform.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        group.animations = [opacity, transform]
        group.duration = duration
        group.timingFunction = timing
        layer.add(group, forKey: "enter")
    }

    private func animateExit(completion: @escaping () -> Void) {
        guard let layer = background.layer else { completion(); return }
        let reduce = Self.systemReduceMotion
        setAnchorPoint(CGPoint(x: 0.88, y: 1.0), for: background)

        let motion = controller.theme.motion.panelExit
        let duration = reduce ? motion.reducedDuration : motion.duration
        let timing = Self.timingFunction(for: motion.curve)

        layer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // Reset for the next open.
            layer.opacity = 1
            layer.transform = CATransform3DIdentity
            completion()
        }

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 1; opacity.toValue = 0
        opacity.duration = duration
        opacity.timingFunction = timing
        opacity.isRemovedOnCompletion = false
        opacity.fillMode = .forwards
        layer.add(opacity, forKey: "exitOpacity")

        if !reduce {
            let transform = CABasicAnimation(keyPath: "transform")
            transform.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
            transform.toValue = NSValue(caTransform3D: entranceTransform())
            transform.duration = duration
            transform.timingFunction = timing
            transform.isRemovedOnCompletion = false
            transform.fillMode = .forwards
            layer.add(transform, forKey: "exitTransform")
        }
        CATransaction.commit()
    }

    /// The mockup's closed transform: translateY(-10px) scale(0.965). In the
    /// non-flipped layer, CSS "up" (-10) becomes +10.
    private func entranceTransform() -> CATransform3D {
        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, 0, 10, 0)
        t = CATransform3DScale(t, 0.965, 0.965, 1)
        return t
    }

    // MARK: Frame morph (expand / collapse)

    private func morphFrame(expanded: Bool, animated: Bool) {
        guard isVisible else { return }
        let panelSize = expanded ? controller.theme.metrics.panelExpandedSize
                                 : controller.theme.metrics.panelCompactSize
        let newWinSize = PanelController.windowSize(for: panelSize)

        // Anchor the card's right edge (top-right anchor) so the beak stays put.
        let old = window.frame
        let newOriginX = old.maxX - newWinSize.width
        let newOriginY = old.maxY - newWinSize.height // top edge fixed
        var newFrame = NSRect(x: newOriginX, y: newOriginY, width: newWinSize.width, height: newWinSize.height)
        newFrame = clampToScreen(newFrame, panelSize: panelSize)

        let reduce = Self.systemReduceMotion
        let motion = controller.theme.motion.expandMorph

        if animated && !reduce {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = motion.duration
                ctx.timingFunction = Self.timingFunction(for: motion.curve)
                ctx.allowsImplicitAnimation = true
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
        }
    }

    // MARK: Positioning

    static func windowSize(for panelSize: CGSize) -> CGSize {
        CGSize(width: panelSize.width + 2 * PanelBackgroundView.margin,
               height: panelSize.height + 2 * PanelBackgroundView.margin)
    }

    private func position(for panelSize: CGSize) {
        let winSize = PanelController.windowSize(for: panelSize)
        let m = PanelBackgroundView.margin

        // Resolve the anchor rect in screen coords.
        let screen = anchorButton?.window?.screen ?? NSScreen.main
        let buttonScreen: NSRect
        if let button = anchorButton, let bwin = button.window {
            buttonScreen = bwin.convertToScreen(button.convert(button.bounds, to: nil))
        } else if let screen {
            // No status item (headless fallback): top-right of the screen.
            buttonScreen = NSRect(x: screen.frame.maxX - 40, y: screen.frame.maxY - 24, width: 24, height: 24)
        } else {
            buttonScreen = NSRect(x: 800, y: 800, width: 24, height: 24)
        }

        let gap: CGFloat = 6
        let beakInsetFromRight: CGFloat = 26 + controller.theme.metrics.beakSize / 2

        // Desired card position.
        let cardTopY = buttonScreen.minY - gap
        var cardOriginY = cardTopY - panelSize.height
        let cardRightX = buttonScreen.midX + beakInsetFromRight
        var cardOriginX = cardRightX - panelSize.width

        // Clamp the card to the owning screen's visible frame.
        if let vf = screen?.visibleFrame {
            cardOriginX = min(max(cardOriginX, vf.minX + 8), vf.maxX - 8 - panelSize.width)
            cardOriginY = max(cardOriginY, vf.minY + 8)
            cardOriginY = min(cardOriginY, vf.maxY - 8 - panelSize.height)
        }

        let winOrigin = NSPoint(x: cardOriginX - m, y: cardOriginY - m)
        window.setFrame(NSRect(origin: winOrigin, size: winSize), display: true)
    }

    private func clampToScreen(_ frame: NSRect, panelSize: CGSize) -> NSRect {
        let m = PanelBackgroundView.margin
        guard let screen = anchorButton?.window?.screen ?? NSScreen.main else { return frame }
        let vf = screen.visibleFrame
        var cardOriginX = frame.origin.x + m
        var cardOriginY = frame.origin.y + m
        cardOriginX = min(max(cardOriginX, vf.minX + 8), vf.maxX - 8 - panelSize.width)
        cardOriginY = max(cardOriginY, vf.minY + 8)
        cardOriginY = min(cardOriginY, vf.maxY - 8 - panelSize.height)
        return NSRect(x: cardOriginX - m, y: cardOriginY - m, width: frame.width, height: frame.height)
    }

    // MARK: Click-outside monitors

    private func installMonitors() {
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.handleClickOutside() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.window {
                self.handleClickOutside()
            }
            return event
        }
    }

    private func removeMonitors() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
    }

    private func handleClickOutside() {
        guard isVisible, !interactionHold else { return }
        // Ignore clicks on the status item itself: its button action (on mouseUp) toggles
        // the panel, so dismissing here too would close-then-reopen. We test the button's
        // own screen frame, so this stays correct on whichever display owns the item.
        if clickIsOnStatusItem() { return }
        requestClose()
    }

    private func clickIsOnStatusItem() -> Bool {
        guard let button = anchorButton, let win = button.window else { return false }
        let frameOnScreen = win.convertToScreen(button.convert(button.bounds, to: nil))
        return frameOnScreen.contains(NSEvent.mouseLocation)
    }

    // MARK: Appearance / theme

    func applyAppearance(setting: AppAppearance, systemIsDark: Bool) {
        let resolved = resolveAppearance(setting, systemIsDark: systemIsDark)
        // For a forced scheme, pin the window appearance so the vibrancy material
        // matches; for .system, let the hosting view inherit NSApp.effectiveAppearance.
        switch setting {
        case .system:
            window.appearance = nil
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        }
        _ = resolved
        background.apply(palette: controller.currentPalette)
    }

    func themeChanged() {
        background.apply(palette: controller.currentPalette)
    }

    // MARK: Layer anchor helper

    private func setAnchorPoint(_ anchor: CGPoint, for view: NSView) {
        guard let layer = view.layer else { return }
        let bounds = view.bounds
        var newPoint = CGPoint(x: bounds.width * anchor.x, y: bounds.height * anchor.y)
        var oldPoint = CGPoint(x: bounds.width * layer.anchorPoint.x, y: bounds.height * layer.anchorPoint.y)
        newPoint = newPoint.applying(layer.affineTransform())
        oldPoint = oldPoint.applying(layer.affineTransform())
        var position = layer.position
        position.x -= oldPoint.x; position.x += newPoint.x
        position.y -= oldPoint.y; position.y += newPoint.y
        layer.anchorPoint = anchor
        layer.position = position
    }

    // MARK: Timing

    /// System Reduce-Motion, read directly (independent of the SwiftUI lifecycle) so
    /// the panel's own entrance/exit/morph honor it even before the interior appears.
    static var systemReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static func timingFunction(for curve: MotionCurve) -> CAMediaTimingFunction {
        if let p = curve.controlPoints {
            return CAMediaTimingFunction(controlPoints: Float(p.0), Float(p.1), Float(p.2), Float(p.3))
        }
        return CAMediaTimingFunction(name: .linear)
    }
}

/// A tiny holder used only to satisfy the initializer before `self` exists; the real
/// chrome (the PanelController) is installed immediately after super.init.
private enum ThisChromeBox {
    @MainActor static let placeholder: PanelChrome = NoopPanelChrome()
}
