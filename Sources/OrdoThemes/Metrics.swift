import CoreGraphics

/// Layout constants that are part of the theme's art direction (panel size, radii,
/// ring geometry). Transcribed from the mockup so OrdoUI/OrdoApp stay token-driven
/// with zero hardcoded dimensions.
public struct ThemeMetrics: Sendable, Hashable {
    /// Compact panel size (380 × 566).
    public var panelCompactSize: CGSize
    /// Expanded panel size (606 × 588).
    public var panelExpandedSize: CGSize
    /// Panel corner radius (20).
    public var panelCornerRadius: Double
    /// Planning rail width when expanded (226).
    public var railWidth: Double
    /// Main column width (380).
    public var mainColumnWidth: Double
    /// Expanded progress ring radius (56).
    public var ringRadius: Double
    /// Expanded progress ring stroke width (9).
    public var ringStrokeWidth: Double
    /// Compact progress ring diameter (20).
    public var compactRingDiameter: Double
    /// Compact progress ring stroke width (2.5).
    public var compactRingStrokeWidth: Double
    /// Task row corner radius (11).
    public var rowCornerRadius: Double
    /// Checkbox diameter (22).
    public var checkboxSize: Double
    /// Pointer beak size (12).
    public var beakSize: Double
    /// Cabinet border stroke width (Arcade). Default 0 — macOS has no cabinet border.
    public var borderWidth: Double
    /// Segmented progress bar segment count (Arcade). Default 0 — unused elsewhere.
    public var progressSegments: Int
    /// Horizontal inset from the panel's right edge to the notch/beak's right edge —
    /// i.e. the mockup's `.notch`/`.beak` CSS `right:` value, in px (macOS 26, Arcade 44).
    public var notchInsetFromRight: Double

    public init(
        panelCompactSize: CGSize, panelExpandedSize: CGSize, panelCornerRadius: Double,
        railWidth: Double, mainColumnWidth: Double,
        ringRadius: Double, ringStrokeWidth: Double,
        compactRingDiameter: Double, compactRingStrokeWidth: Double,
        rowCornerRadius: Double, checkboxSize: Double, beakSize: Double,
        borderWidth: Double = 0, progressSegments: Int = 0,
        notchInsetFromRight: Double = 26
    ) {
        self.panelCompactSize = panelCompactSize
        self.panelExpandedSize = panelExpandedSize
        self.panelCornerRadius = panelCornerRadius
        self.railWidth = railWidth
        self.mainColumnWidth = mainColumnWidth
        self.ringRadius = ringRadius
        self.ringStrokeWidth = ringStrokeWidth
        self.compactRingDiameter = compactRingDiameter
        self.compactRingStrokeWidth = compactRingStrokeWidth
        self.rowCornerRadius = rowCornerRadius
        self.checkboxSize = checkboxSize
        self.beakSize = beakSize
        self.borderWidth = borderWidth
        self.progressSegments = progressSegments
        self.notchInsetFromRight = notchInsetFromRight
    }
}
