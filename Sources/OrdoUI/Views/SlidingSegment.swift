// OrdoUI — a generic sliding-thumb segmented control (mockup .tabs / .seg). The
// selected segment's thumb slides under the label with the theme's drawer curve.
// Used for the tab bar and the footer appearance control; fully token-driven.

import SwiftUI
import OrdoThemes

struct SlidingSegment<Option: Hashable, Label: View>: View {
    let options: [Option]
    let selection: Option
    let motion: MotionToken
    let height: CGFloat
    let cornerRadius: CGFloat
    let thumbInset: CGFloat
    /// When true (tabs) segments split the width equally; when false (footer appearance)
    /// each hugs its content — the mockup's `.tabs` vs `.seg`. Content-width also avoids
    /// a collapse an enclosing `.fixedSize()` caused around a width-driven GeometryReader.
    var fillEqually: Bool = true
    /// Outer track corner radius. Mockup: both `.tabs` and `.seg` use 9.
    var trackCornerRadius: CGFloat? = nil
    let onSelect: (Option) -> Void
    @ViewBuilder let label: (Option, Bool) -> Label

    @Environment(\.ordoPalette) private var palette
    @Environment(\.ordoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    /// Measured per-segment frames in the control's own coordinate space, so the thumb
    /// lands under the selected segment regardless of equal vs content widths.
    @State private var frames: [Int: CGRect] = [:]

    private var selectedIndex: Int { options.firstIndex(of: selection) ?? 0 }
    private var outerRadius: CGFloat { trackCornerRadius ?? (cornerRadius + thumbInset) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(palette.segmentBackground)

            // Sliding thumb, sized/placed from the measured selected-segment frame.
            if let f = frames[selectedIndex] {
                let thumbWidth = theme.usesCabinetControls ? pixelSnapped(f.width) : f.width
                let thumbX = theme.usesCabinetControls ? pixelSnapped(f.minX) : f.minX
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.segmentThumb)
                    .ordoShadows(palette.segmentThumbShadow)
                    .frame(width: thumbWidth, height: height)
                    .offset(x: thumbX, y: thumbInset)
                    .animation(motion.animation(reduceMotion: reduceMotion), value: selectedIndex)
            }

            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    Button {
                        onSelect(option)
                    } label: {
                        label(option, option == selection)
                            .frame(maxWidth: fillEqually ? .infinity : nil, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.97))
                    .background(
                        GeometryReader { g in
                            Color.clear.preference(
                                key: SegmentFramesKey.self,
                                value: [index: g.frame(in: .named(Self.space))])
                        }
                    )
                }
            }
            .padding(thumbInset)
        }
        .frame(maxWidth: fillEqually ? .infinity : nil)
        .frame(height: height + thumbInset * 2)
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(SegmentFramesKey.self) { frames = $0 }
    }

    private static var space: String { "ordoSeg" }

    /// Rounds a measured point value to the nearest whole *device pixel* (not
    /// just the nearest point), so a flat-fill shape's edges land on a pixel
    /// boundary instead of straddling two rows/columns under anti-aliasing.
    private func pixelSnapped(_ value: CGFloat) -> CGFloat {
        (value * displayScale).rounded() / displayScale
    }
}

/// Collects each segment button's frame (keyed by index) so the thumb can track it.
private struct SegmentFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// A button style that scales down slightly on press, driven by the theme's press
/// echo token (mockup active/press transforms) with Reduce-Motion resolution.
struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        PressScaleBody(configuration: configuration, scale: scale)
    }

    private struct PressScaleBody: View {
        let configuration: Configuration
        let scale: CGFloat
        @Environment(\.ordoTheme) private var theme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? scale : 1)
                .animation(theme.motion.pressEcho.animation(reduceMotion: reduceMotion), value: configuration.isPressed)
        }
    }
}
