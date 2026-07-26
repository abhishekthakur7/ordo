// OrdoApp — PanelBackgroundView: the panel's surface behind a clear SwiftUI root; also
// the animation container (layer holds entrance/exit transform). Two mutually exclusive
// surfaces, chosen by `palette.surface`:
//   - `.vibrancy` (macOS glass): NSVisualEffectView + tint, sheen, hairlines, 3-layer soft
//     shadow, glass beak. Flat opaque fill under Reduce-Transparency. UNCHANGED behavior.
//   - `.cabinet` (Arcade cabinet chrome): opaque plastic fill, 2px border, single hard
//     zero-blur offset shadow, top sheen, CRT/LCD overlay (scanlines+vignette or grain),
//     bordered square notch. See `Sources/OrdoThemes/Palette.swift` for the descriptors.

import AppKit
import SwiftUI
import OrdoThemes

final class PanelBackgroundView: NSView {

    /// Space reserved around the card for the shadow bloom and the beak.
    static let margin: CGFloat = 60

    /// `CAGradientLayer.endPoint` offset (from the (0.5, 0.5) center, per axis) for the
    /// cabinet CRT vignette's 100%-opacity stop, in the layer's normalized unit space.
    /// The panel's own corner sits at a fixed unit-space offset of `(0.5, 0.5)` — i.e.
    /// distance `sqrt(0.5² + 0.5²)` from center — regardless of the panel's real pixel
    /// aspect ratio. Scaling that distance by the mockup's 120% gradient-box oversize
    /// gives the endPoint offset at which the 100% stop lands 1.2x beyond the corner,
    /// so the corner itself only ever samples ~1/1.2 of the way through the ramp. See
    /// the `.scanlines` case of `applyOverlay(_:)` for the resulting opacity math.
    private static let vignetteCornerOversize: CGFloat = 1.2 * (CGFloat(2).squareRoot() / 2)

    private let metrics: ThemeMetrics

    // The card (clipped, rounded) and its layered surface.
    private let shadowHost = NSView()
    private let card = NSView()
    // One backing view per CSS box-shadow layer, stacked behind the card so the full
    // 3-layer stack (contact + mid + wide) composites like the mockup, rather than a
    // single representative approximation. The cabinet surface reuses this same
    // mechanism with exactly one layer (a zero-blur offset shadow).
    private var shadowViews: [NSView] = []
    private var effectView: NSVisualEffectView?
    private let flatView = NSView()
    private let tintView = NSView()
    private let sheenView = NSView()
    private let beak = NSView()
    /// Cabinet-only CRT/LCD overlay, layered above the hosting view, clipped to the
    /// card's rounded rect (inherited from `card.layer.masksToBounds`), and mouse-transparent.
    private let overlayView = PassThroughOverlayView()
    private let overlayScanlineReplicator = CAReplicatorLayer()
    private let overlayScanlineTile = CALayer()
    private let overlayRadialLayer = CAGradientLayer()
    private var overlayScanlinePitch: CGFloat = 3

    /// The card's current corner radius (mirrors `card.layer.cornerRadius`, which is
    /// re-derived from the palette on every `apply(palette:)` rather than the possibly
    /// stale `metrics.panelCornerRadius`, so it stays correct across a live theme swap).
    private var cardCornerRadius: CGFloat
    /// The beak/notch's current corner radius: rounded for the macOS glass beak (3pt),
    /// sharp for the arcade cabinet's square notch (0pt).
    private var beakCornerRadius: CGFloat = 3

    /// The SwiftUI hosting view, inserted by the controller (kept clipped to the card).
    var hostingView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let h = hostingView {
                h.translatesAutoresizingMaskIntoConstraints = true
                card.addSubview(h)
            }
            needsLayout = true
        }
    }

    private var currentPalette: Palette?

    init(metrics: ThemeMetrics) {
        self.metrics = metrics
        self.cardCornerRadius = metrics.panelCornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false

        shadowHost.wantsLayer = true
        shadowHost.layer?.masksToBounds = false
        addSubview(shadowHost)

        card.wantsLayer = true
        card.layer?.cornerRadius = cardCornerRadius
        card.layer?.masksToBounds = true
        if #available(macOS 10.15, *) {
            card.layer?.cornerCurve = .continuous
        }
        shadowHost.addSubview(card)

        flatView.wantsLayer = true
        tintView.wantsLayer = true
        sheenView.wantsLayer = true

        beak.wantsLayer = true
        beak.layer?.masksToBounds = true
        if #available(macOS 10.15, *) { beak.layer?.cornerCurve = .continuous }
        addSubview(beak, positioned: .below, relativeTo: shadowHost)

        // Cabinet overlay scaffold: replicator (scanlines) + radial gradient (vignette /
        // grain), both hidden until a `.cabinet` palette with a non-`.none` overlay applies.
        overlayView.wantsLayer = true
        overlayView.isHidden = true
        overlayScanlineReplicator.addSublayer(overlayScanlineTile)
        overlayView.layer?.addSublayer(overlayScanlineReplicator)
        overlayRadialLayer.type = .radial
        overlayView.layer?.addSublayer(overlayRadialLayer)
        card.addSubview(overlayView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { false }

    // MARK: Palette application

    func apply(palette: Palette) {
        currentPalette = palette

        switch palette.surface {
        case .vibrancy(let material):
            applyVibrancySurface(material: material, palette: palette)
        case .cabinet(let cab):
            applyCabinetSurface(cab)
        }

        // Keep the hosting view topmost, and — for the cabinet surface — the CRT/LCD
        // overlay topmost above that (it must sit above the SwiftUI content).
        if let h = hostingView { card.addSubview(h) }
        if case .cabinet(let cab) = palette.surface {
            overlayView.isHidden = false
            card.addSubview(overlayView) // reorder to front
            applyOverlay(cab.overlay)
        } else {
            overlayView.isHidden = true
        }

        needsLayout = true
    }

    // MARK: Vibrancy surface (macOS glass) — behavior unchanged from pre-cabinet code.

    private func applyVibrancySurface(material: MaterialIntent, palette: Palette) {
        let usesFallback = material.usesFallback

        // Effect view vs flat fallback.
        if usesFallback {
            effectView?.removeFromSuperview()
            effectView = nil
            if flatView.superview == nil { card.addSubview(flatView, positioned: .below, relativeTo: nil) }
            flatView.layer?.backgroundColor = NSColor(material.fallbackOpaque).cgColor
            tintView.isHidden = true
            sheenView.isHidden = true
        } else {
            flatView.removeFromSuperview()
            let effect: NSVisualEffectView
            if let existing = effectView {
                effect = existing
            } else {
                effect = NSVisualEffectView()
                effect.state = .active
                card.addSubview(effect, positioned: .below, relativeTo: nil)
                effectView = effect
            }
            effect.material = Self.material(for: material.material)
            effect.blendingMode = Self.blending(for: material.blending)
            // Tint over the blur (the CSS --panel-bg).
            tintView.isHidden = false
            tintView.layer?.backgroundColor = NSColor(material.tint).cgColor
            if tintView.superview == nil { card.addSubview(tintView) }
            // Top sheen gradient (CSS --panel-tint → transparent by 30%).
            sheenView.isHidden = false
            if sheenView.superview == nil { card.addSubview(sheenView) }
            applySheenGradient(topColor: material.sheen, extent: 0.30)
        }

        // Inner + outer hairlines on the card.
        cardCornerRadius = metrics.panelCornerRadius
        card.layer?.cornerRadius = cardCornerRadius
        card.layer?.borderWidth = palette.hairlineWidth
        card.layer?.borderColor = NSColor(palette.panelHairline).cgColor

        // Shadow (largest, most-diffuse layer approximates the CSS stack).
        applyShadow(palette.panelShadow)

        // Beak surface matches the card glass tint + top/left hairline.
        beak.layer?.backgroundColor = NSColor(
            usesFallback ? material.fallbackOpaque : material.tint).cgColor
        beak.layer?.borderWidth = palette.hairlineWidth
        beak.layer?.borderColor = NSColor(palette.panelHairline).cgColor
        beakCornerRadius = 3
    }

    // MARK: Cabinet surface (Arcade) — opaque plastic, hard shadow, CRT/LCD overlay.

    private func applyCabinetSurface(_ cab: CabinetStyle) {
        // No vibrancy at all on this path.
        effectView?.removeFromSuperview()
        effectView = nil
        tintView.isHidden = true
        tintView.removeFromSuperview()

        // Opaque plastic fill.
        if flatView.superview == nil { card.addSubview(flatView, positioned: .below, relativeTo: nil) }
        flatView.isHidden = false
        flatView.layer?.backgroundColor = NSColor(cab.fill).cgColor

        // Top sheen highlight, reusing the same gradient machinery as the glass sheen
        // but over the top ~40% of the card (vs. glass's 30%) and cab.topSheen's color.
        sheenView.isHidden = false
        if sheenView.superview == nil { card.addSubview(sheenView) }
        applySheenGradient(topColor: cab.topSheen, extent: 0.40)

        // Real 2px border + the cabinet's own corner radius (16 vs macOS's 20) — read
        // straight from the palette so this is correct even if the view's `metrics`
        // (captured once at construction) is stale after a live theme swap.
        cardCornerRadius = CGFloat(cab.cornerRadius)
        card.layer?.cornerRadius = cardCornerRadius
        card.layer?.borderWidth = CGFloat(cab.borderWidth)
        card.layer?.borderColor = NSColor(cab.border).cgColor

        // Single hard, zero-blur offset shadow (mockup: `6px 8px 0 var(--hard)`). This
        // reuses the same shadow-backing-view stack as the vibrancy path's 3-layer
        // stack — passing a single synthetic `ShadowLayer` with `blur: 0` reconciles it
        // down to exactly one view with `shadowRadius == 0`.
        applyShadow([ShadowLayer(color: cab.hardShadow.color, x: cab.hardShadow.x, y: cab.hardShadow.y, blur: 0)])

        // Bordered square notch (no glass tint, no rounding): cab.fill + cab.border.
        beak.layer?.backgroundColor = NSColor(cab.fill).cgColor
        beak.layer?.borderWidth = CGFloat(cab.borderWidth)
        beak.layer?.borderColor = NSColor(cab.border).cgColor
        beakCornerRadius = 0
    }

    // MARK: CRT / LCD overlay (cabinet only)

    /// Configures the static (non-animated) scanline + radial layers from the palette's
    /// `OverlayStyle`. Honors Reduce-Motion trivially (nothing here is ever animated) and
    /// trusts the descriptor's already-softened values for Reduce-Transparency (Phase 1
    /// tempers `scanlineOpacity`/`vignetteOpacity`/`gridOpacity` at the theme layer).
    private func applyOverlay(_ overlay: OverlayStyle) {
        switch overlay.kind {
        case .none:
            overlayScanlineReplicator.isHidden = true
            overlayRadialLayer.isHidden = true

        case .scanlines:
            // Repeating 1px dark lines every `scanlinePitch`, then a soft radial
            // vignette on top (mockup: rgba(0,0,0,0.22) lines @ opacity 0.42, plus
            // radial(120% 120% at 50% 50%, transparent 58%, rgba(0,0,0,0.55) 100%)).
            //
            // The mockup's gradient box is sized 120% of the panel, so the panel's own
            // corners only ever sample ~1/1.2 of the way through the 58%→100% ramp
            // (~0.33 opacity), not the full 0.55 — the vignette darkens the mid-field
            // but leaves edge-adjacent content (accent add button, status number,
            // composer "+") close to full brightness. `endPoint` at exactly (1, 1)
            // previously placed the *box corner itself* at (or past) the 100% stop,
            // crushing the edges to full 0.55. Pushing `endPoint` out along the same
            // diagonal so the 100%-stop circle has radius `1.2x` the center→corner
            // distance reproduces that: the corner now lands at t ≈ 1/1.2 ≈ 0.83,
            // i.e. opacity ≈ 0.55 * (0.83 - 0.58) / (1 - 0.58) ≈ 0.33.
            overlayScanlineReplicator.isHidden = false
            overlayScanlineTile.backgroundColor = NSColor.black.withAlphaComponent(0.22).cgColor
            overlayScanlineReplicator.opacity = Float(overlay.scanlineOpacity)
            overlayScanlinePitch = max(CGFloat(overlay.scanlinePitch), 1)

            overlayRadialLayer.isHidden = false
            overlayRadialLayer.colors = [
                NSColor.black.withAlphaComponent(0).cgColor,
                NSColor.black.withAlphaComponent(overlay.vignetteOpacity).cgColor,
            ]
            overlayRadialLayer.locations = [0.58, 1.0]
            overlayRadialLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            let cornerOversize = Self.vignetteCornerOversize
            overlayRadialLayer.endPoint = CGPoint(x: 0.5 + cornerOversize, y: 0.5 + cornerOversize)

        case .lcdGrain:
            // Very subtle grey-green radial darkening at the corners (mockup:
            // radial-gradient(circle at 50% 50%, transparent 70%, rgba(120,130,90,0.06) 100%)).
            // `vignetteOpacity` is 0 for the light palette; the DMG grain's intensity is
            // carried on `gridOpacity` instead (ArcadeTheme sets 0.10 there, 0 on vignette).
            overlayScanlineReplicator.isHidden = true

            overlayRadialLayer.isHidden = false
            overlayRadialLayer.colors = [
                NSColor(red: 120.0 / 255, green: 130.0 / 255, blue: 90.0 / 255, alpha: 0).cgColor,
                NSColor(red: 120.0 / 255, green: 130.0 / 255, blue: 90.0 / 255, alpha: overlay.gridOpacity).cgColor,
            ]
            overlayRadialLayer.locations = [0.70, 1.0]
            overlayRadialLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            overlayRadialLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        }
        needsLayout = true
    }

    private func applySheenGradient(topColor: Color, extent: Double) {
        let gradient = (sheenView.layer as? CAGradientLayer) ?? {
            let g = CAGradientLayer()
            sheenView.layer = g
            sheenView.wantsLayer = true
            return g
        }()
        gradient.colors = [
            NSColor(topColor).cgColor,
            NSColor(topColor).withAlphaComponent(0).cgColor,
        ]
        gradient.locations = [0.0, NSNumber(value: extent)]
        gradient.startPoint = CGPoint(x: 0.5, y: 1.0) // top (non-flipped layer)
        gradient.endPoint = CGPoint(x: 0.5, y: 0.0)
    }

    private func applyShadow(_ layers: [ShadowLayer]) {
        // The card container casts nothing itself; each CSS layer is a dedicated
        // backing view behind the card so the stack composites like the mockup.
        shadowHost.layer?.shadowOpacity = 0

        // Reconcile the backing-view count with the layer count.
        while shadowViews.count < layers.count {
            let v = NSView()
            v.wantsLayer = true
            v.layer?.masksToBounds = false
            v.layer?.backgroundColor = NSColor.clear.cgColor
            addSubview(v, positioned: .below, relativeTo: nil) // send to the very back
            shadowViews.append(v)
        }
        while shadowViews.count > layers.count {
            shadowViews.removeLast().removeFromSuperview()
        }

        for (i, s) in layers.enumerated() {
            guard let l = shadowViews[i].layer else { continue }
            let ns = NSColor(s.color)
            l.shadowColor = ns.withAlphaComponent(1).cgColor
            l.shadowOpacity = Float(ns.alphaComponent)
            l.shadowRadius = s.blur / 2
            // CSS positive y = downward; default macOS layer geometry: negative height = down.
            l.shadowOffset = CGSize(width: s.x, height: -s.y)
        }
        needsLayout = true
    }

    // MARK: Layout

    override func layout() {
        super.layout()
        let m = Self.margin
        let cardRect = bounds.insetBy(dx: m, dy: m)
        shadowHost.frame = cardRect
        card.frame = shadowHost.bounds
        effectView?.frame = card.bounds
        flatView.frame = card.bounds
        tintView.frame = card.bounds
        sheenView.frame = card.bounds
        (sheenView.layer as? CAGradientLayer)?.frame = sheenView.bounds
        hostingView?.frame = card.bounds

        overlayView.frame = card.bounds
        overlayRadialLayer.frame = overlayView.bounds
        layoutScanlineReplicator()

        // Each shadow-backing view sits exactly on the card and casts through a rounded
        // silhouette matching the panel corners (read from the card's live corner radius,
        // not `metrics`, so this stays correct across a live theme swap).
        let shadowPath = CGPath(
            roundedRect: CGRect(origin: .zero, size: cardRect.size),
            cornerWidth: cardCornerRadius,
            cornerHeight: cardCornerRadius, transform: nil)
        for v in shadowViews {
            v.frame = cardRect
            v.layer?.shadowPath = shadowPath
        }

        // Beak: near the card's top-right, poking upward toward the glyph.
        let bs = metrics.beakSize
        let insetFromRight: CGFloat = metrics.notchInsetFromRight + bs / 2 // mockup notch/beak right: + half width → center
        let centerX = cardRect.maxX - insetFromRight
        let centerY = cardRect.maxY - 1 // sit right at the card's top edge
        beak.frame = NSRect(x: centerX - bs / 2, y: centerY - bs / 2, width: bs, height: bs)
        // Rotate 45° about its center so a corner points up (the pointer tip).
        beak.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        beak.layer?.position = CGPoint(x: beak.frame.midX, y: beak.frame.midY)
        beak.layer?.transform = CATransform3DMakeRotation(.pi / 4, 0, 0, 1)
        beak.layer?.cornerRadius = beakCornerRadius
    }

    /// Sizes the repeating-line replicator: a 1pt-tall dark tile anchored at the top,
    /// replicated downward every `overlayScanlinePitch` points to fill the overlay's
    /// height. Purely geometric — no animation — so Reduce-Motion is unaffected.
    private func layoutScanlineReplicator() {
        let bounds = overlayView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        overlayScanlineReplicator.frame = bounds
        let tileHeight: CGFloat = 1
        overlayScanlineTile.frame = CGRect(x: 0, y: bounds.height - tileHeight, width: bounds.width, height: tileHeight)
        let pitch = overlayScanlinePitch
        overlayScanlineReplicator.instanceCount = Int(ceil(bounds.height / pitch)) + 1
        overlayScanlineReplicator.instanceTransform = CATransform3DMakeTranslation(0, -pitch, 0)
    }

    // MARK: Material mapping (OrdoThemes enums → AppKit)

    static func material(for kind: MaterialKind) -> NSVisualEffectView.Material {
        switch kind {
        case .popover: return .popover
        case .menu: return .menu
        case .hudWindow: return .hudWindow
        case .underWindowBackground: return .underWindowBackground
        case .sidebar: return .sidebar
        case .headerView: return .headerView
        case .fullScreenUI: return .fullScreenUI
        }
    }

    static func blending(for blending: MaterialBlending) -> NSVisualEffectView.BlendingMode {
        switch blending {
        case .behindWindow: return .behindWindow
        case .withinWindow: return .withinWindow
        }
    }
}

/// A view that never intercepts mouse events — used for the cabinet CRT/LCD overlay so
/// clicks/hover still reach the SwiftUI content beneath it ("pointer-events: none").
private final class PassThroughOverlayView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
