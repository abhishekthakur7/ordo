import SwiftUI

/// Which font face a `TypeToken` should resolve to. `.system` keeps the SF Pro
/// behavior every macOS token uses; `.named` resolves a bundled custom font by
/// family name (e.g. Arcade's "Press Start 2P" or "Space Grotesk").
public enum FontFamily: Sendable, Hashable {
    case system
    case named(String)
    /// Resolves one exact PostScript face without synthesizing a weight.
    /// This is required for static multi-weight font families such as Zen Ink's.
    case postScript(String)
}

/// One typographic role: size, weight, letter-spacing, line-height and digit style.
/// Transcribed from the mockup's per-element CSS. Sizes are in points; `trackingEm`
/// is CSS `letter-spacing` in em; `lineHeightMultiple` is the CSS unitless line-height.
public struct TypeToken: Sendable, Hashable {
    public var size: Double
    public var weight: Font.Weight
    /// letter-spacing expressed in em (multiply by `size` for points).
    public var trackingEm: Double
    /// CSS line-height as a multiple of the font size.
    public var lineHeightMultiple: Double
    /// Whether digits should be tabular (monospaced).
    public var monospacedDigit: Bool
    /// Whether the text should render uppercased (CSS `text-transform: uppercase`).
    public var uppercase: Bool
    /// Whether the text should render with an italic face or synthesized italic.
    public var italic: Bool
    /// Which font face to resolve `font` to. Defaults to `.system` (SF Pro).
    public var fontFamily: FontFamily

    public init(
        size: Double,
        weight: Font.Weight,
        trackingEm: Double = 0,
        lineHeightMultiple: Double = 1.2,
        monospacedDigit: Bool = false,
        uppercase: Bool = false,
        italic: Bool = false,
        fontFamily: FontFamily = .system
    ) {
        self.size = size
        self.weight = weight
        self.trackingEm = trackingEm
        self.lineHeightMultiple = lineHeightMultiple
        self.monospacedDigit = monospacedDigit
        self.uppercase = uppercase
        self.italic = italic
        self.fontFamily = fontFamily
    }

    /// letter-spacing converted to points for `.tracking(_:)`.
    public var trackingPoints: Double { size * trackingEm }

    /// Extra leading for `.lineSpacing(_:)` (SwiftUI adds this *between* lines).
    public var lineSpacing: Double { max(0, size * (lineHeightMultiple - 1)) }

    /// The font for this role, digit style and italics applied. Resolves `.named`
    /// to the bundled custom font, still applying `weight` where the face
    /// supports it. `.postScript` keeps its exact static face and does not apply
    /// a synthesized weight.
    public var font: Font {
        var f: Font
        switch fontFamily {
        case .system:
            f = Font.system(size: size, weight: weight)
        case .named(let name):
            f = Font.custom(name, size: size).weight(weight)
        case .postScript(let name):
            f = Font.custom(name, size: size)
        }
        if monospacedDigit { f = f.monospacedDigit() }
        if italic { f = f.italic() }
        return f
    }
}

extension View {
    /// Apply a `TypeToken`'s font, tracking and line spacing in one call.
    @ViewBuilder
    public func typeToken(_ t: TypeToken) -> some View {
        if t.italic {
            self.font(t.font)
                .italic()
                .tracking(t.trackingPoints)
                .lineSpacing(t.lineSpacing)
        } else {
            self.font(t.font)
                .tracking(t.trackingPoints)
                .lineSpacing(t.lineSpacing)
        }
    }
}

/// The complete type scale for a theme. macOS values come straight from
/// `mockups/02-macos-glass.html`.
public struct TypeScale: Sendable, Hashable {
    public var greeting: TypeToken       // 19 / 700 / -0.02em
    public var date: TypeToken           // 12.5 / 500
    public var tab: TypeToken            // 13 / 600 / -0.01em
    public var tabCount: TypeToken       // 11 / 600 tabular
    public var taskTitle: TypeToken      // 14 / 500 / -0.01em / 1.3
    public var ageMarker: TypeToken      // 11 / 600 tabular
    public var doneHeader: TypeToken     // 11 / 600 / 0.08em / uppercase
    public var field: TypeToken          // 14 / 500 / -0.01em
    public var emptyTitle: TypeToken     // 15.5 / 700 / -0.01em
    public var emptyBody: TypeToken      // 12.5 / 1.45
    public var railKicker: TypeToken     // 10.5 / 600 / 0.16em / uppercase
    public var ringNumber: TypeToken     // 30 / 700 / -0.03em tabular
    public var ringSub: TypeToken        // 11
    public var railLine: TypeToken       // 13
    public var railLineValue: TypeToken  // 13 / 600 tabular
    public var railQuote: TypeToken      // 12 / 1.5
    public var segmentButton: TypeToken  // 12 / 600

    public init(
        greeting: TypeToken, date: TypeToken, tab: TypeToken, tabCount: TypeToken,
        taskTitle: TypeToken, ageMarker: TypeToken, doneHeader: TypeToken, field: TypeToken,
        emptyTitle: TypeToken, emptyBody: TypeToken, railKicker: TypeToken,
        ringNumber: TypeToken, ringSub: TypeToken, railLine: TypeToken,
        railLineValue: TypeToken, railQuote: TypeToken, segmentButton: TypeToken
    ) {
        self.greeting = greeting
        self.date = date
        self.tab = tab
        self.tabCount = tabCount
        self.taskTitle = taskTitle
        self.ageMarker = ageMarker
        self.doneHeader = doneHeader
        self.field = field
        self.emptyTitle = emptyTitle
        self.emptyBody = emptyBody
        self.railKicker = railKicker
        self.ringNumber = ringNumber
        self.ringSub = ringSub
        self.railLine = railLine
        self.railLineValue = railLineValue
        self.railQuote = railQuote
        self.segmentButton = segmentButton
    }
}
