// OrdoApp — PanelController: owns the borderless, non-activating NSPanel, hosts
// PanelRootView over the glass background, implements the PanelChrome bridge (C4, §4.2/§6.1).
// Animates entrance/exit + expand-morph, closes on click-outside; hidden ≠ deallocated.

import AppKit
import CoreImage
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

    /// The background owns no other layer filters today, but retain the exact filter
    /// instance so this controller can remove only the transient panel blur.
    private var panelBlurFilter: CIFilter?
    /// Invalidates a stale exit completion when the panel is reopened mid-close.
    private var exitAnimationGeneration = 0
    /// Invalidates an entrance blur cleanup once an exit begins.
    private var entranceBlurGeneration = 0
    /// Frame changes made through `NSWindow.animator()` are composited by AppKit
    /// from a cached window snapshot. That is normally desirable, but it leaves
    /// an expanded SwiftUI surface visible over the compact hierarchy during a
    /// panel collapse. Drive real, non-animated window frames instead.
    private var morphTimer: Timer?
    private var morphGeneration = 0
    /// Both the header button and ⌘E change SwiftUI state before calling the
    /// chrome bridge. Keep one next-turn request here so every entry point lets
    /// that state commit first, and a rapid reversal retains only its last target.
    private var morphRequestGeneration = 0

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

    func setExpanded(_ _: Bool) {
        // Do not defer a reduced-motion update: it must invalidate an in-flight
        // timer and put the window and SwiftUI hierarchy at the exact endpoint
        // in this same main-actor turn.
        if resolvedReduceMotion {
            cancelPendingMorph()
            morphFrame(expanded: controller.settings.panelExpanded, animated: false)
            return
        }
        // Freeze a prior tween at its last shared frame/progress immediately.
        // The coalesced request below then restarts from that exact live state.
        cancelMorphAnimation()
        morphRequestGeneration &+= 1
        let generation = morphRequestGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.morphRequestGeneration == generation else { return }
            // Read the single source of truth at execution time. A second toggle
            // in this run-loop turn supersedes the captured request entirely.
            self.morphFrame(expanded: self.controller.settings.panelExpanded, animated: true)
        }
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
        cancelPendingMorph()
        cancelMorphAnimation()
        setExpansionProgress(for: controller.settings.panelExpanded)
        // A second status-item click can reopen while the previous exit animation
        // is still in flight. Its completion must not order this new presentation out.
        exitAnimationGeneration += 1
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
        cancelPendingMorph()
        cancelMorphAnimation()
        setExpansionProgress(for: controller.settings.panelExpanded)
        isVisible = false
        removeMonitors()

        let finish: () -> Void = { [weak self] in
            guard let self else { return }
            self.clearPanelBlur()
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
        let reduce = resolvedReduceMotion
        setAnchorPoint(CGPoint(x: 0.88, y: 1.0), for: background)

        let motion = controller.theme.motion.panelEnter
        let duration = reduce ? motion.reducedDuration : motion.duration

        layer.removeAllAnimations()
        clearPanelBlur(from: layer)
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
        let animations: [CAAnimation] = [opacity, transform]

        let blurRadius = panelBlurRadius(entering: true, reduceMotion: reduce)
        if blurRadius > 0, installPanelBlur(radius: blurRadius, on: layer) != nil {
            let blur = CABasicAnimation(keyPath: "filters.gaussianBlur.inputRadius")
            blur.fromValue = blurRadius
            blur.toValue = 0
            blur.duration = duration
            blur.timingFunction = timing

            entranceBlurGeneration += 1
            let generation = entranceBlurGeneration
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self, weak layer] in
                guard let self, let layer, self.entranceBlurGeneration == generation else { return }
                self.clearPanelBlur(from: layer)
            }
            group.animations = animations
            group.duration = duration
            group.timingFunction = timing
            layer.add(group, forKey: "enter")
            layer.add(blur, forKey: "enterBlur")
            CATransaction.commit()
            return
        }

        group.animations = animations
        group.duration = duration
        group.timingFunction = timing
        layer.add(group, forKey: "enter")
    }

    private func animateExit(completion: @escaping () -> Void) {
        guard let layer = background.layer else { completion(); return }
        let reduce = resolvedReduceMotion
        setAnchorPoint(CGPoint(x: 0.88, y: 1.0), for: background)

        let motion = controller.theme.motion.panelExit
        let duration = reduce ? motion.reducedDuration : motion.duration
        let timing = Self.timingFunction(for: motion.curve)

        layer.removeAllAnimations()
        entranceBlurGeneration += 1
        clearPanelBlur(from: layer)
        exitAnimationGeneration += 1
        let generation = exitAnimationGeneration
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak layer] in
            guard let self, let layer,
                  self.exitAnimationGeneration == generation,
                  !self.isVisible else { return }
            // Reset for the next open.
            layer.opacity = 1
            layer.transform = CATransform3DIdentity
            self.clearPanelBlur(from: layer)
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

        let blurRadius = panelBlurRadius(entering: false, reduceMotion: reduce)
        if blurRadius > 0, installPanelBlur(radius: blurRadius, on: layer) != nil {
            let blur = CABasicAnimation(keyPath: "filters.gaussianBlur.inputRadius")
            blur.fromValue = 0
            blur.toValue = blurRadius
            blur.duration = duration
            blur.timingFunction = timing
            blur.isRemovedOnCompletion = false
            blur.fillMode = .forwards
            layer.add(blur, forKey: "exitBlur")
        }
        CATransaction.commit()
    }

    /// The Core Image blur is safe only for Zen's opaque paper card. In
    /// particular, never apply it to the vibrancy view, where it cannot compose
    /// correctly with the window-server material, or to the cabinet surface.
    private func panelBlurRadius(entering: Bool, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion, case .paper = controller.currentPalette.surface else { return 0 }
        let radius = controller.theme.motion.panelBlur(entering: entering, reduceMotion: reduceMotion)
        guard radius.isFinite, radius > 0 else { return 0 }
        return CGFloat(radius)
    }

    /// Installs a transient Core Image filter with its model value at the final
    /// radius. The explicit animation supplies the visual start value, so the
    /// filter is never left blurred once its animation is removed.
    @discardableResult
    private func installPanelBlur(radius: CGFloat, on layer: CALayer) -> CIFilter? {
        clearPanelBlur(from: layer)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setDefaults()
        filter.setValue(radius, forKey: kCIInputRadiusKey)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.filters = (layer.filters ?? []) + [filter]
        CATransaction.commit()
        panelBlurFilter = filter
        return filter
    }

    /// Removes only this controller's filter so a future background-layer effect
    /// cannot be accidentally stripped. This is called before every new lifecycle
    /// animation and after a completed entrance/exit, including theme swaps.
    private func clearPanelBlur(from layer: CALayer? = nil) {
        guard let filter = panelBlurFilter else { return }
        guard let layer = layer ?? background.layer else {
            panelBlurFilter = nil
            return
        }
        layer.removeAnimation(forKey: "enterBlur")
        layer.removeAnimation(forKey: "exitBlur")
        let remaining = (layer.filters ?? []).filter { candidate in
            guard let candidate = candidate as? CIFilter else { return true }
            return candidate !== filter
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.filters = remaining.isEmpty ? nil : remaining
        CATransaction.commit()
        panelBlurFilter = nil
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
        guard isVisible else {
            setExpansionProgress(for: expanded)
            return
        }
        let panelSize = expanded ? controller.theme.metrics.panelExpandedSize
                                 : controller.theme.metrics.panelCompactSize
        let newWinSize = PanelController.windowSize(for: panelSize)

        // Anchor the card's right edge (top-right anchor) so the beak stays put.
        let old = window.frame
        let newOriginX = old.maxX - newWinSize.width
        let newOriginY = old.maxY - newWinSize.height // top edge fixed
        var newFrame = NSRect(x: newOriginX, y: newOriginY, width: newWinSize.width, height: newWinSize.height)
        newFrame = clampToScreen(newFrame, panelSize: panelSize)

        let reduce = resolvedReduceMotion
        let motion = controller.theme.motion.expandMorph
        let targetProgress: CGFloat = expanded ? 1 : 0

        cancelMorphAnimation()
        guard animated, !reduce, motion.duration > 0, window.frame != newFrame else {
            setExpansionProgress(targetProgress)
            setWindowFrame(newFrame, display: true)
            return
        }

        // The current frame is the start frame, rather than a remembered endpoint.
        // This makes an expand/collapse reversal continuous, even midway through the
        // previous transition. `setFrame(..., animate: false)` avoids AppKit's
        // snapshot compositor entirely, so SwiftUI is always drawing the one live
        // hierarchy for the current frame.
        let startFrame = window.frame
        let startProgress = expansionProgress(for: startFrame)
        setExpansionProgress(startProgress)
        let duration = motion.duration
        let startedAt = Date()
        morphGeneration &+= 1
        let generation = morphGeneration
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            // This timer is installed only on `RunLoop.main` below. Foundation's
            // callback is nevertheless Sendable, so re-enter the known main actor
            // explicitly before touching AppKit or controller state.
            MainActor.assumeIsolated {
                guard let self, self.isVisible, self.morphGeneration == generation else {
                    timer.invalidate()
                    return
                }

                // Accessibility can change while the panel is visible. Finish
                // both surfaces at the semantic endpoint rather than leaving a
                // timer alive with a now-disallowed in-between state.
                guard !self.resolvedReduceMotion else {
                    self.setExpansionProgress(targetProgress)
                    self.setWindowFrame(newFrame, display: true)
                    timer.invalidate()
                    if self.morphGeneration == generation {
                        self.morphTimer = nil
                    }
                    return
                }

                let linearProgress = min(max(Date().timeIntervalSince(startedAt) / duration, 0), 1)
                let easedProgress = Self.easedProgress(linearProgress, curve: motion.curve)
                let progress = startProgress + (targetProgress - startProgress) * easedProgress
                self.setExpansionProgress(linearProgress >= 1 ? targetProgress : progress)
                self.setWindowFrame(Self.interpolate(from: startFrame, to: newFrame, progress: easedProgress),
                                    display: true)

                guard linearProgress >= 1 else { return }
                timer.invalidate()
                if self.morphGeneration == generation {
                    self.morphTimer = nil
                }
            }
        }
        morphTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelMorphAnimation() {
        morphGeneration &+= 1
        morphTimer?.invalidate()
        morphTimer = nil
    }

    private func cancelPendingMorph() {
        morphRequestGeneration &+= 1
    }

    /// The model owns observable layout state, while the controller owns the
    /// timing. This class is main-actor isolated, so this never crosses threads.
    private func setExpansionProgress(_ progress: CGFloat) {
        controller.model.setPanelExpansionProgress(progress)
    }

    private func setExpansionProgress(for expanded: Bool) {
        setExpansionProgress(expanded ? 1 : 0)
    }

    /// Converts the current live frame to the matching semantic fraction. This
    /// is the only valid start state for a rapid reversal because the frame may
    /// be partway through an earlier target's interpolation.
    private func expansionProgress(for frame: NSRect) -> CGFloat {
        let metrics = controller.theme.metrics
        let compactWidth = Self.windowSize(for: metrics.panelCompactSize).width
        let expandedWidth = Self.windowSize(for: metrics.panelExpandedSize).width
        let span = expandedWidth - compactWidth
        guard span != 0 else { return controller.settings.panelExpanded ? 1 : 0 }
        return min(max((frame.width - compactWidth) / span, 0), 1)
    }

    /// Explicitly passing `animate: false` is important: the two-argument
    /// overload may still participate in an AppKit animation context.
    private func setWindowFrame(_ frame: NSRect, display: Bool) {
        window.setFrame(frame, display: display, animate: false)
    }

    private static func interpolate(from: NSRect, to: NSRect, progress: CGFloat) -> NSRect {
        let p = min(max(progress, 0), 1)
        return NSRect(
            x: from.origin.x + (to.origin.x - from.origin.x) * p,
            y: from.origin.y + (to.origin.y - from.origin.y) * p,
            width: from.size.width + (to.size.width - from.size.width) * p,
            height: from.size.height + (to.size.height - from.size.height) * p
        )
    }

    /// Converts elapsed time to the matching cubic-bezier progress. Core
    /// Animation accepts the curve directly; for manual frames we solve its x
    /// component first so the motion retains the theme's authored timing.
    private static func easedProgress(_ progress: Double, curve: MotionCurve) -> CGFloat {
        let input = min(max(progress, 0), 1)
        guard let (x1, y1, x2, y2) = curve.controlPoints else {
            if case let .steps(count) = curve, count > 0, input < 1 {
                return CGFloat(floor(input * Double(count)) / Double(count))
            }
            return CGFloat(input)
        }

        func cubic(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
            let inverse = 1 - t
            return 3 * inverse * inverse * t * p1 + 3 * inverse * t * t * p2 + t * t * t
        }
        func derivative(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
            let inverse = 1 - t
            return 3 * inverse * inverse * p1 + 6 * inverse * t * (p2 - p1) + 3 * t * t * (1 - p2)
        }

        // Newton's method converges rapidly for normal curves; the bisection
        // fallback also handles the drawer curve's x2 == 0 safely.
        var t = input
        for _ in 0..<8 {
            let slope = derivative(t, x1, x2)
            guard abs(slope) > 0.000_001 else { break }
            let next = t - (cubic(t, x1, x2) - input) / slope
            guard (0...1).contains(next) else { break }
            t = next
        }
        var lower = 0.0
        var upper = 1.0
        for _ in 0..<12 {
            let x = cubic(t, x1, x2)
            if abs(x - input) < 0.000_001 { break }
            if x < input { lower = t } else { upper = t }
            t = (lower + upper) / 2
        }
        return CGFloat(cubic(t, y1, y2))
    }

    // MARK: Positioning

    static func windowSize(for panelSize: CGSize) -> CGSize {
        CGSize(width: panelSize.width + 2 * PanelBackgroundView.margin,
               height: panelSize.height + 2 * PanelBackgroundView.margin)
    }

    /// Horizontal distance from a card's right edge to the status-item-aligned
    /// beak center. Kept pure so the 26pt macOS and 44pt Arcade/Zen metric values
    /// can be regression-tested when OrdoApp gains a test target.
    static func beakAnchorOffset(for metrics: ThemeMetrics) -> CGFloat {
        #if DEBUG
        assert(metrics.notchInsetFromRight >= 0)
        assert(metrics.beakSize >= 0)
        #endif
        return CGFloat(metrics.notchInsetFromRight + metrics.beakSize / 2)
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
        let beakInsetFromRight = Self.beakAnchorOffset(for: controller.theme.metrics)

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
        clearPanelBlur()
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
        background.apply(palette: controller.currentPalette, metrics: controller.theme.metrics)
    }

    func themeChanged() {
        cancelPendingMorph()
        cancelMorphAnimation()
        setExpansionProgress(for: controller.settings.panelExpanded)
        // The palette may switch paper ↔ vibrancy/cabinet while the panel is on
        // screen. Drop the transient filter before the persistent surface changes.
        clearPanelBlur()
        background.apply(palette: controller.currentPalette, metrics: controller.theme.metrics)
        if isVisible {
            // Re-resolve from the status-item anchor rather than merely preserving
            // the old right edge: a live Mac → Arcade swap changes the notch inset
            // from 26pt to 44pt and must keep the newly drawn beak under the item.
            let panelSize = controller.settings.panelExpanded
                ? controller.theme.metrics.panelExpandedSize
                : controller.theme.metrics.panelCompactSize
            position(for: panelSize)
        }
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

    /// `AppModel` receives the SwiftUI accessibility environment after the host is
    /// attached; the direct workspace read covers the earlier panel lifecycle.
    private var resolvedReduceMotion: Bool {
        Self.systemReduceMotion || controller.model.reduceMotion
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
