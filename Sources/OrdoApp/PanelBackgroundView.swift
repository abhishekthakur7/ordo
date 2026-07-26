// OrdoApp — PanelBackgroundView: the panel's glass surface (NSVisualEffectView + tint,
// sheen, hairlines, shadow layers, beak) behind a clear SwiftUI root; flat opaque fill
// under Reduce-Transparency. Also the animation container (layer holds entrance/exit transform).

import AppKit
import SwiftUI
import OrdoThemes

final class PanelBackgroundView: NSView {

    /// Space reserved around the card for the shadow bloom and the beak.
    static let margin: CGFloat = 60

    private let metrics: ThemeMetrics

    // The card (clipped, rounded) and its layered surface.
    private let shadowHost = NSView()
    private let card = NSView()
    // One backing view per CSS box-shadow layer, stacked behind the card so the full
    // 3-layer stack (contact + mid + wide) composites like the mockup, rather than a
    // single representative approximation.
    private var shadowViews: [NSView] = []
    private var effectView: NSVisualEffectView?
    private let flatView = NSView()
    private let tintView = NSView()
    private let sheenView = NSView()
    private let beak = NSView()

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
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false

        shadowHost.wantsLayer = true
        shadowHost.layer?.masksToBounds = false
        addSubview(shadowHost)

        card.wantsLayer = true
        card.layer?.cornerRadius = metrics.panelCornerRadius
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
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { false }

    // MARK: Palette application

    func apply(palette: Palette) {
        currentPalette = palette
        let usesFallback = palette.material.usesFallback

        // Effect view vs flat fallback.
        if usesFallback {
            effectView?.removeFromSuperview()
            effectView = nil
            if flatView.superview == nil { card.addSubview(flatView, positioned: .below, relativeTo: nil) }
            flatView.layer?.backgroundColor = NSColor(palette.material.fallbackOpaque).cgColor
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
            effect.material = Self.material(for: palette.material.material)
            effect.blendingMode = Self.blending(for: palette.material.blending)
            // Tint over the blur (the CSS --panel-bg).
            tintView.isHidden = false
            tintView.layer?.backgroundColor = NSColor(palette.material.tint).cgColor
            if tintView.superview == nil { card.addSubview(tintView) }
            // Top sheen gradient (CSS --panel-tint → transparent by 30%).
            sheenView.isHidden = false
            if sheenView.superview == nil { card.addSubview(sheenView) }
            applySheen(palette: palette)
        }

        // Keep the hosting view topmost.
        if let h = hostingView { card.addSubview(h) }

        // Inner + outer hairlines on the card.
        card.layer?.borderWidth = palette.hairlineWidth
        card.layer?.borderColor = NSColor(palette.panelHairline).cgColor

        // Shadow (largest, most-diffuse layer approximates the CSS stack).
        applyShadow(palette.panelShadow)

        // Beak surface matches the card glass tint + top/left hairline.
        beak.layer?.backgroundColor = NSColor(
            usesFallback ? palette.material.fallbackOpaque : palette.material.tint).cgColor
        beak.layer?.borderWidth = palette.hairlineWidth
        beak.layer?.borderColor = NSColor(palette.panelHairline).cgColor

        needsLayout = true
    }

    private func applySheen(palette: Palette) {
        let gradient = (sheenView.layer as? CAGradientLayer) ?? {
            let g = CAGradientLayer()
            sheenView.layer = g
            sheenView.wantsLayer = true
            return g
        }()
        gradient.colors = [
            NSColor(palette.material.sheen).cgColor,
            NSColor(palette.material.sheen).withAlphaComponent(0).cgColor,
        ]
        gradient.locations = [0.0, 0.30]
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

        // Each shadow-backing view sits exactly on the card and casts through a rounded
        // silhouette matching the panel corners.
        let shadowPath = CGPath(
            roundedRect: CGRect(origin: .zero, size: cardRect.size),
            cornerWidth: metrics.panelCornerRadius,
            cornerHeight: metrics.panelCornerRadius, transform: nil)
        for v in shadowViews {
            v.frame = cardRect
            v.layer?.shadowPath = shadowPath
        }

        // Beak: near the card's top-right, poking upward toward the glyph.
        let bs = metrics.beakSize
        let insetFromRight: CGFloat = 26 + bs / 2 // mockup right:26 + half width → center
        let centerX = cardRect.maxX - insetFromRight
        let centerY = cardRect.maxY - 1 // sit right at the card's top edge
        beak.frame = NSRect(x: centerX - bs / 2, y: centerY - bs / 2, width: bs, height: bs)
        // Rotate 45° about its center so a corner points up (the pointer tip).
        beak.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        beak.layer?.position = CGPoint(x: beak.frame.midX, y: beak.frame.midY)
        beak.layer?.transform = CATransform3DMakeRotation(.pi / 4, 0, 0, 1)
        beak.layer?.cornerRadius = 3
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
