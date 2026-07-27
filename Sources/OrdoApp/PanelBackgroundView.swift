// OrdoApp — PanelBackgroundView: the panel's surface behind a clear SwiftUI root; also
// the animation container (layer holds entrance/exit transform). Renders one of two
// mutually exclusive surfaces chosen by `palette.surface`: macOS glass vibrancy, or
// the Arcade cabinet's opaque plastic fill + hard shadow + CRT/LCD overlay.

import AppKit
import SwiftUI
import OrdoThemes

final class PanelBackgroundView: NSView {

    /// Space reserved around the card for the shadow bloom and the beak.
    static let margin: CGFloat = 60

    /// `CAGradientLayer.endPoint` offset (from center) for the cabinet vignette's
    /// 100%-opacity stop, in normalized layer space — sized so the panel's own
    /// corner samples only partway through the ramp, not at full opacity.
    private static let vignetteCornerOversize: CGFloat = 1.2 * (CGFloat(2).squareRoot() / 2)

    /// Geometry is theme-owned and can change while the long-lived panel window is
    /// on screen (for example, macOS's 26pt notch inset → Arcade's 44pt inset).
    /// Keep the current value rather than the launch-time value supplied to `init`.
    private var metrics: ThemeMetrics

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
    /// Paper-only 1pt inset highlight. It is a single retained view so repeated
    /// appearance/theme swaps do not grow the card's layer tree.
    private let innerHighlightView = NSView()
    private let beak = NSView()
    /// Surface overlay host, layered above the hosting view, clipped to the card's
    /// rounded rect (inherited from `card.layer.masksToBounds`), and mouse-transparent.
    private let overlayView = PassThroughOverlayView()
    private let overlayScanlineReplicator = CAReplicatorLayer()
    private let overlayScanlineTile = CALayer()
    private let overlayRadialLayer = CAGradientLayer()
    private var overlayScanlinePitch: CGFloat = 3
    /// The paper overlay is a retained two-axis replicator rather than a new image
    /// for every resize. `paperGrainTile` is one scale-correct CGImage; the two
    /// replicators repeat it across the panel without stretching it.
    private let paperGrainReplicator = CAReplicatorLayer()
    private let paperGrainRows = CAReplicatorLayer()
    private let paperGrainTile = CALayer()
    private var paperGrainStyle: GrainStyle?
    private var paperGrainCache: [PaperGrainCacheKey: CGImage] = [:]
    private var appliedPaperGrainKey: PaperGrainCacheKey?

    /// The card's current corner radius (mirrors `card.layer.cornerRadius`, which is
    /// re-derived from the palette on every `apply(palette:)` rather than the possibly
    /// stale `metrics.panelCornerRadius`, so it stays correct across a live theme swap).
    private var cardCornerRadius: CGFloat
    /// The beak/notch's current corner radius: rounded for the macOS glass beak (3pt),
    /// sharp for the arcade cabinet's square notch (0pt).
    private var beakCornerRadius: CGFloat = 3

    /// `appearanceBlend` is part of the key even though the tile is grayscale: it
    /// marks the light/dark art direction and keeps image cache semantics aligned
    /// with the palette's appearance-specific compositing choice.
    private struct PaperGrainCacheKey: Hashable {
        let tilePixels: Int
        let scaleMilli: Int
        let appearanceBlend: GrainStyle.Blend
    }

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
        innerHighlightView.wantsLayer = true

        beak.wantsLayer = true
        beak.layer?.masksToBounds = true
        if #available(macOS 10.15, *) { beak.layer?.cornerCurve = .continuous }
        addSubview(beak, positioned: .below, relativeTo: shadowHost)

        overlayView.wantsLayer = true
        overlayView.isHidden = true
        overlayScanlineReplicator.addSublayer(overlayScanlineTile)
        overlayView.layer?.addSublayer(overlayScanlineReplicator)
        overlayRadialLayer.type = .radial
        overlayView.layer?.addSublayer(overlayRadialLayer)
        paperGrainRows.addSublayer(paperGrainTile)
        paperGrainReplicator.addSublayer(paperGrainRows)
        overlayView.layer?.addSublayer(paperGrainReplicator)
        card.addSubview(overlayView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { false }

    // MARK: Palette application

    /// Re-applies both visual tokens and geometry to the persistent panel view.
    /// This is intentionally separate from window creation: themes can be swapped
    /// while the panel is visible and its beak must move immediately.
    func apply(palette: Palette, metrics: ThemeMetrics) {
        self.metrics = metrics
        currentPalette = palette

        let overlay: SurfaceOverlay
        switch palette.surface {
        case .vibrancy(let material):
            applyVibrancySurface(material: material, palette: palette)
            overlay = .none
        case .cabinet(let cab):
            applyCabinetSurface(cab)
            overlay = .cabinet(cab.overlay)
        case .paper(let paper):
            applyPaperSurface(paper)
            overlay = .paper(grain: paper.grain)
        }

        if let h = hostingView { card.addSubview(h) }
        overlayView.isHidden = false
        card.addSubview(overlayView)
        applyOverlay(overlay)

        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    /// Compatibility entry point for callers that only change palette values.
    /// New live-theme callers should pass the theme metrics explicitly above.
    func apply(palette: Palette) {
        apply(palette: palette, metrics: metrics)
    }

    // MARK: Vibrancy surface (macOS glass)

    private func applyVibrancySurface(material: MaterialIntent, palette: Palette) {
        let usesFallback = material.usesFallback

        // Effect view vs flat fallback.
        if usesFallback {
            effectView?.removeFromSuperview()
            effectView = nil
            if flatView.superview == nil { card.addSubview(flatView, positioned: .below, relativeTo: nil) }
            applyFlatFill(NSColor(material.fallbackOpaque))
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
        innerHighlightView.isHidden = true
        paperGrainStyle = nil
    }

    // MARK: Cabinet surface (Arcade) — opaque plastic, hard shadow, CRT/LCD overlay.

    private func applyCabinetSurface(_ cab: CabinetStyle) {
        effectView?.removeFromSuperview()
        effectView = nil
        tintView.isHidden = true
        tintView.removeFromSuperview()

        if flatView.superview == nil { card.addSubview(flatView, positioned: .below, relativeTo: nil) }
        flatView.isHidden = false
        applyFlatFill(NSColor(cab.fill))

        sheenView.isHidden = false
        if sheenView.superview == nil { card.addSubview(sheenView) }
        applySheenGradient(topColor: cab.topSheen, extent: 0.40)

        cardCornerRadius = CGFloat(cab.cornerRadius)
        card.layer?.cornerRadius = cardCornerRadius
        card.layer?.borderWidth = CGFloat(cab.borderWidth)
        card.layer?.borderColor = NSColor(cab.border).cgColor

        applyShadow([ShadowLayer(color: cab.hardShadow.color, x: cab.hardShadow.x, y: cab.hardShadow.y, blur: 0)])

        beak.layer?.backgroundColor = NSColor(cab.fill).cgColor
        beak.layer?.borderWidth = CGFloat(cab.borderWidth)
        beak.layer?.borderColor = NSColor(cab.border).cgColor
        beakCornerRadius = 0
        innerHighlightView.isHidden = true
        paperGrainStyle = nil
    }

    // MARK: Paper surface (Zen Ink)

    private func applyPaperSurface(_ paper: PaperStyle) {
        effectView?.removeFromSuperview()
        effectView = nil
        tintView.isHidden = true
        tintView.removeFromSuperview()
        sheenView.isHidden = true
        sheenView.removeFromSuperview()

        if flatView.superview == nil { card.addSubview(flatView, positioned: .below, relativeTo: nil) }
        flatView.isHidden = false
        applyFlatGradient(top: NSColor(paper.fillTop), bottom: NSColor(paper.fillBottom))

        cardCornerRadius = CGFloat(paper.cornerRadius)
        card.layer?.cornerRadius = cardCornerRadius
        card.layer?.borderWidth = CGFloat(paper.borderWidth)
        card.layer?.borderColor = NSColor(paper.border).cgColor
        applyShadow(paper.shadow)

        if innerHighlightView.superview == nil { card.addSubview(innerHighlightView) }
        innerHighlightView.isHidden = false
        innerHighlightView.layer?.backgroundColor = NSColor(paper.innerHighlight).cgColor

        beak.layer?.backgroundColor = NSColor(paper.fillTop).cgColor
        beak.layer?.borderWidth = CGFloat(paper.borderWidth)
        beak.layer?.borderColor = NSColor(paper.border).cgColor
        beakCornerRadius = CGFloat(paper.beakCornerRadius)
        paperGrainStyle = paper.grain
    }

    /// Restores a plain backing layer after a paper gradient, so an old gradient
    /// cannot survive a live paper → macOS/Arcade swap.
    private func applyFlatFill(_ color: NSColor) {
        if flatView.layer is CAGradientLayer {
            let layer = CALayer()
            layer.frame = flatView.bounds
            flatView.layer = layer
        }
        flatView.layer?.backgroundColor = color.cgColor
    }

    private func applyFlatGradient(top: NSColor, bottom: NSColor) {
        let gradient: CAGradientLayer
        if let existing = flatView.layer as? CAGradientLayer {
            gradient = existing
        } else {
            gradient = CAGradientLayer()
            gradient.frame = flatView.bounds
            flatView.layer = gradient
        }
        gradient.colors = [top.cgColor, bottom.cgColor]
        gradient.locations = [0, 1]
        gradient.startPoint = CGPoint(x: 0.5, y: 1.0) // top in the non-flipped layer
        gradient.endPoint = CGPoint(x: 0.5, y: 0.0)
    }

    // MARK: Surface overlays

    /// Surface ownership is explicit so switching among paper, glass, and cabinet
    /// always clears the visual treatment belonging to the previous surface.
    private enum SurfaceOverlay {
        case none
        case cabinet(OverlayStyle)
        case paper(grain: GrainStyle)
    }

    /// Configures the static (non-animated) cabinet or paper treatment. The
    /// theme has already applied accessibility choices to these values.
    private func applyOverlay(_ overlay: SurfaceOverlay) {
        switch overlay {
        case .none:
            resetCabinetOverlay()
            resetPaperGrain()
            overlayView.isHidden = true

        case .cabinet(let cabinet):
            resetPaperGrain()
            overlayView.isHidden = false
            applyCabinetOverlay(cabinet)

        case .paper(let grain):
            resetCabinetOverlay()
            overlayView.isHidden = grain.opacity <= 0 || grain.tile <= 0
            applyPaperGrain(grain)
        }
        needsLayout = true
    }

    /// Existing CRT/LCD behavior is kept intact, but is now scoped to the
    /// cabinet branch of `SurfaceOverlay` rather than sharing a paper no-op.
    private func applyCabinetOverlay(_ overlay: OverlayStyle) {
        switch overlay.kind {
        case .none:
            resetCabinetOverlay()

        case .scanlines:
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
            overlayScanlineReplicator.isHidden = true

            overlayRadialLayer.isHidden = false
            overlayRadialLayer.colors = [
                NSColor(red: 120.0 / 255, green: 130.0 / 255, blue: 90.0 / 255, alpha: 0).cgColor,
                NSColor(red: 120.0 / 255, green: 130.0 / 255, blue: 90.0 / 255, alpha: overlay.gridOpacity).cgColor,
            ]
            overlayRadialLayer.locations = [0.70, 1.0]
            overlayRadialLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            overlayRadialLayer.endPoint = CGPoint(x: 1.0, y: 1.0)

        case .paperGrain:
            // `OverlayStyle.paperGrain` remains a valid neutral descriptor for
            // callers outside this view. Paper itself uses the richer GrainStyle.
            resetCabinetOverlay()
        }
    }

    private func resetCabinetOverlay() {
        overlayScanlineReplicator.isHidden = true
        overlayScanlineReplicator.opacity = 1
        overlayRadialLayer.isHidden = true
        overlayRadialLayer.compositingFilter = nil
    }

    private func applyPaperGrain(_ grain: GrainStyle) {
        paperGrainStyle = grain
        guard grain.opacity > 0, grain.tile > 0 else {
            resetPaperGrain()
            return
        }

        paperGrainReplicator.isHidden = false
        paperGrainReplicator.opacity = Float(grain.opacity)
        paperGrainReplicator.compositingFilter = Self.compositingFilter(for: grain.blend)
        updatePaperGrainImageIfNeeded()
    }

    private func resetPaperGrain() {
        paperGrainReplicator.isHidden = true
        paperGrainReplicator.opacity = 1
        paperGrainReplicator.compositingFilter = nil
        paperGrainTile.contents = nil
        appliedPaperGrainKey = nil
        paperGrainStyle = nil
    }

    private static func compositingFilter(for blend: GrainStyle.Blend) -> String {
        switch blend {
        case .multiply: return "multiplyBlendMode"
        case .overlay: return "overlayBlendMode"
        }
    }

    /// Reuses the image while the tile, active appearance treatment, and backing
    /// scale are unchanged. Calling this from layout is therefore geometry-only on
    /// ordinary frames; the small CPU noise pass happens only when that key changes.
    private func updatePaperGrainImageIfNeeded() {
        guard let grain = paperGrainStyle, grain.opacity > 0, grain.tile > 0 else { return }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        let tilePixels = max(Int((CGFloat(grain.tile) * scale).rounded()), 1)
        let key = PaperGrainCacheKey(
            tilePixels: tilePixels,
            scaleMilli: Int((scale * 1_000).rounded()),
            appearanceBlend: grain.blend
        )

        if appliedPaperGrainKey != key {
            let image: CGImage
            if let cached = paperGrainCache[key] {
                image = cached
            } else {
                image = Self.makePaperGrainImage(side: tilePixels, blend: grain.blend)
                // A panel only normally sees light/dark at one or two display
                // scales. Bound the cache anyway so arbitrary live theme previews
                // cannot retain an unbounded collection of CGImage tiles.
                if paperGrainCache.count >= 8 { paperGrainCache.removeAll(keepingCapacity: true) }
                paperGrainCache[key] = image
            }
            paperGrainTile.contents = image
            paperGrainTile.contentsScale = scale
            appliedPaperGrainKey = key
        }
        layoutPaperGrainReplicator(tile: CGFloat(grain.tile), scale: scale)
    }

    /// Generates a stable washi-like grayscale tile from integer coordinate noise.
    /// It intentionally uses no system RNG: the same theme, tile, and scale always
    /// produce identical bytes, including across launches.
    private static func makePaperGrainImage(side: Int, blend: GrainStyle.Blend) -> CGImage {
        let seed: UInt64 = blend == .multiply ? 0xD1B5_4A32_D192_ED03 : 0x94D0_49BB_1331_11EB
        var bytes = [UInt8](repeating: 0, count: side * side)
        for y in 0..<side {
            for x in 0..<side {
                let coordinate = UInt64(x) &* 0x9E37_79B1 ^ UInt64(y) &* 0x85EB_CA77
                let fine = Self.mixedNoise(seed ^ coordinate)
                // A second low-frequency sample keeps the tile from reading like
                // digital TV static while preserving a neutral mid-gray average.
                let coarse = Self.mixedNoise(seed ^ UInt64(x / 7) &* 0xC2B2_AE3D ^ UInt64(y / 7) &* 0x27D4_EB2F)
                let variation = Int((fine & 0x3F) + (coarse & 0x1F)) - 47
                bytes[y * side + x] = UInt8(clamping: 128 + variation)
            }
        }

        let data = Data(bytes) as CFData
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let provider = CGDataProvider(data: data)!
        return CGImage(
            width: side,
            height: side,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: side,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    private static func mixedNoise(_ value: UInt64) -> UInt64 {
        var value = value
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return value
    }

    private func layoutPaperGrainReplicator(tile: CGFloat, scale: CGFloat) {
        let bounds = overlayView.bounds
        guard bounds.width > 0, bounds.height > 0, tile > 0 else { return }
        paperGrainReplicator.frame = bounds
        paperGrainReplicator.contentsScale = scale
        paperGrainRows.frame = CGRect(x: 0, y: 0, width: tile, height: bounds.height)
        paperGrainRows.contentsScale = scale
        paperGrainRows.instanceCount = Int(ceil(bounds.height / tile))
        paperGrainRows.instanceTransform = CATransform3DMakeTranslation(0, tile, 0)
        paperGrainTile.frame = CGRect(x: 0, y: 0, width: tile, height: tile)
        paperGrainReplicator.instanceCount = Int(ceil(bounds.width / tile))
        paperGrainReplicator.instanceTransform = CATransform3DMakeTranslation(tile, 0, 0)
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
        innerHighlightView.frame = NSRect(x: 0, y: max(card.bounds.height - 1, 0), width: card.bounds.width, height: 1)
        hostingView?.frame = card.bounds

        overlayView.frame = card.bounds
        overlayRadialLayer.frame = overlayView.bounds
        layoutScanlineReplicator()
        updatePaperGrainImageIfNeeded()

        // Each shadow-backing view sits exactly on the card and casts through a rounded
        // silhouette matching the panel corners.
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
        let insetFromRight: CGFloat = metrics.notchInsetFromRight + bs / 2
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
