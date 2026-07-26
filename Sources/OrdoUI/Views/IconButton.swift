// OrdoUI — the header/utility icon button (mockup .icon-btn): 30×30, rounded, hover
// fill + press scale, all from palette + motion tokens.

import SwiftUI
import OrdoThemes

struct IconButton<Icon: View>: View {
    let action: () -> Void
    var size: CGFloat = 30
    var cornerRadius: CGFloat = 8
    var accessibilityLabel: String
    @ViewBuilder let icon: () -> Icon

    @Environment(\.ordoPalette) private var palette
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            icon()
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(hover ? palette.rowHover : .clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .foregroundStyle(hover ? palette.ink : palette.ink2)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .onHover { hover = $0 }
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A 1.6pt-stroke SF-style glyph drawn from an SVG-ish path builder. We use SF
/// Symbols where possible; a few glyphs are custom to match the mockup exactly.
struct StrokeIcon: View {
    let systemName: String
    var size: CGFloat = 17
    var weight: Font.Weight = .medium

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: weight))
            .imageScale(.medium)
    }
}

/// The mockup's expand glyph (`.expand-glyph`): four outward-pointing corner brackets
/// in a 24-unit box, stroked at 1.6 units. No SF Symbol matches the corner-bracket
/// form, so it is drawn to match the mockup exactly.
struct ExpandCornersShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var p = Path()
        p.move(to: P(9, 4));  p.addLine(to: P(5, 4));   p.addLine(to: P(5, 8))    // top-left
        p.move(to: P(15, 4)); p.addLine(to: P(19, 4));  p.addLine(to: P(19, 8))   // top-right
        p.move(to: P(9, 20)); p.addLine(to: P(5, 20));  p.addLine(to: P(5, 16))   // bottom-left
        p.move(to: P(15, 20));p.addLine(to: P(19, 20)); p.addLine(to: P(19, 16))  // bottom-right
        return p
    }
}

/// The expand/collapse header glyph rendered from `ExpandCornersShape`, matching the
/// mockup's 17px icon at 1.6-unit stroke (round caps/joins).
struct ExpandGlyphIcon: View {
    var size: CGFloat = 17
    var body: some View {
        ExpandCornersShape()
            .stroke(style: StrokeStyle(lineWidth: 1.6 * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
