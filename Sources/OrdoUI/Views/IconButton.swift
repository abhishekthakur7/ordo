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

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette
    @State private var hover = false

    var body: some View {
        Group {
            if theme.usesCabinetIconButtons {
                cabinetButton
            } else {
                flatButton
            }
        }
        .onHover { hover = $0 }
        .accessibilityLabel(accessibilityLabel)
    }

    /// The macOS flat, hover-tint-only button.
    private var flatButton: some View {
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
    }

    /// The Arcade cabinet icon button: border + fill + hard offset shadow at
    /// rest, accent border/glyph on hover, translate(2,2) with the shadow gone
    /// on press.
    private var cabinetButton: some View {
        Button(action: action) {
            icon()
                .frame(width: size, height: size)
        }
        .buttonStyle(CabinetIconButtonStyle(size: size, cornerRadius: cornerRadius, hover: hover))
    }
}

/// The Arcade cabinet chrome for `IconButton`: a hard-offset shadow shape sits
/// fixed behind the card, and only the card translates on press.
private struct CabinetIconButtonStyle: ButtonStyle {
    let size: CGFloat
    let cornerRadius: CGFloat
    let hover: Bool

    func makeBody(configuration: Configuration) -> some View {
        CabinetIconButtonBody(configuration: configuration, size: size, cornerRadius: cornerRadius, hover: hover)
    }

    private struct CabinetIconButtonBody: View {
        let configuration: Configuration
        let size: CGFloat
        let cornerRadius: CGFloat
        let hover: Bool

        @Environment(\.ordoTheme) private var theme
        @Environment(\.ordoPalette) private var palette
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// The cabinet surface's own fill color.
        private var cabinetFill: Color {
            if case .cabinet(let cab) = palette.surface { return cab.fill }
            return palette.rowHover
        }

        private var hardShadowColor: Color {
            if case .cabinet(let cab) = palette.surface { return cab.hardShadow.color }
            return .black.opacity(0.3)
        }

        private var borderColor: Color { hover ? palette.accent : palette.checkRing }
        private var contentColor: Color { hover ? palette.accent : palette.ink2 }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            ZStack(alignment: .topLeading) {
                shape
                    .fill(hardShadowColor)
                    .frame(width: size, height: size)
                    .offset(x: 2, y: 2)
                    .opacity(configuration.isPressed ? 0 : 1)

                ZStack {
                    shape.fill(cabinetFill)
                    shape.strokeBorder(borderColor, lineWidth: 2)
                    configuration.label
                        .foregroundStyle(contentColor)
                }
                .frame(width: size, height: size)
                .contentShape(shape)
                .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
            }
            .animation(theme.motion.hoverFade.animation(reduceMotion: reduceMotion), value: hover)
            .animation(theme.motion.pressEcho.animation(reduceMotion: reduceMotion), value: configuration.isPressed)
        }
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
