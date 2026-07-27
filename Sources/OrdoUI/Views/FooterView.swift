// OrdoUI — footer (mockup .foot): the appearance segmented control (Auto/Light/
// Dark) with a sliding thumb, and the sound toggle switch. Both live.

import SwiftUI
import OrdoThemes

struct FooterView: View {
    @Bindable var model: AppModel

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette

    var body: some View {
        HStack(spacing: theme.layout.footerContentSpacing) {
            appearanceControl
            Spacer(minLength: 0)
            SoundToggle(model: model)
        }
        .padding(theme.layout.footerInsets.edgeInsets)
        // The task stage is the flexible panel region. Preserve the footer's
        // authored vertical insets when a covering state has taller content.
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) {
            if theme.appearanceSegmentStyle == .labelOnly {
                Rectangle()
                    .fill(palette.divider)
                    .frame(height: palette.hairlineWidth)
            }
        }
    }

    @ViewBuilder
    private var appearanceControl: some View {
        switch theme.appearanceSegmentStyle {
        case .labelOnly:
            ZenAppearanceSegment(selection: model.settings.appearance, onSelect: { model.settings.appearance = $0 })
        case .iconAndLabel, .iconOnly:
            SlidingSegment(
                options: AppAppearance.allCases,
                selection: model.settings.appearance,
                motion: theme.motion.appearanceThumb,
                height: 24,
                cornerRadius: 7,
                thumbInset: 2,
                fillEqually: false, // mockup .seg buttons hug their content
                trackCornerRadius: 9,
                onSelect: { model.settings.appearance = $0 }
            ) { option, isActive in
                Group {
                    if theme.appearanceSegmentStyle == .iconAndLabel {
                        HStack(spacing: 4) {
                            StrokeIcon(systemName: icon(for: option), size: 12, weight: .medium)
                            theme.typeScale.segmentButton.styled(label(for: option))
                        }
                    } else {
                        StrokeIcon(systemName: icon(for: option), size: 12, weight: .medium)
                    }
                }
                .foregroundStyle(activeSegmentForeground(isActive: isActive))
                .padding(.horizontal, 10)
            }
            .accessibilityLabel(UIStrings.appearanceLabel)
        }
    }

    /// The active segment's foreground. Themes whose thumb is an accent fill
    /// (Arcade) need `accentInk` there for contrast; others keep plain `ink`.
    private func activeSegmentForeground(isActive: Bool) -> Color {
        guard isActive else { return palette.ink2 }
        return theme.soundToggleLabel != nil ? palette.accentInk : palette.ink
    }

    private func icon(for option: AppAppearance) -> String {
        switch option {
        case .system: return "display"   // mockup Auto glyph is a monitor/display
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    private func label(for option: AppAppearance) -> String {
        switch option {
        case .system: return UIStrings.appearanceAuto
        case .light: return UIStrings.appearanceLight
        case .dark: return UIStrings.appearanceDark
        }
    }
}

/// Zen Ink's label-only appearance selector. This is intentionally local
/// rather than changing `SlidingSegment`: the latter remains byte-for-byte
/// compatible with the macOS and Arcade controls.
private struct ZenAppearanceSegment: View {
    let selection: AppAppearance
    let onSelect: (AppAppearance) -> Void

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var frames: [Int: CGRect] = [:]

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(palette.segmentBackground)

            if let frame = frames[selectedIndex] {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(palette.segmentThumb)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(palette.fieldLine, lineWidth: palette.hairlineWidth)
                    )
                    .ordoShadows(palette.segmentThumbShadow)
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .animation(theme.motion.appearanceThumb.animation(reduceMotion: reduceMotion), value: selectedIndex)
            }

            HStack(spacing: 0) {
                ForEach(Array(AppAppearance.allCases.enumerated()), id: \.element) { index, option in
                    Button {
                        onSelect(option)
                    } label: {
                        theme.typeScale.segmentButton.styled(label(for: option))
                            .foregroundStyle(option == selection ? palette.ink : palette.ink2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.97))
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ZenSegmentFramesKey.self,
                                value: [index: geometry.frame(in: .named(Self.coordinateSpace))]
                            )
                        }
                    )
                }
            }
            .padding(3)
        }
        .coordinateSpace(name: Self.coordinateSpace)
        // The background shapes are proposal-filling. Without an intrinsic
        // clamp the segment greedily consumes the footer's remaining vertical
        // space in the flexible panel column.
        .fixedSize()
        .onPreferenceChange(ZenSegmentFramesKey.self) { frames = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(UIStrings.appearanceLabel)
    }

    private var selectedIndex: Int { AppAppearance.allCases.firstIndex(of: selection) ?? 0 }
    private static var coordinateSpace: String { "ordoZenAppearanceSegment" }

    private func label(for option: AppAppearance) -> String {
        switch option {
        case .system: return "SYSTEM"
        case .light: return "LIGHT"
        case .dark: return "DARK"
        }
    }
}

private struct ZenSegmentFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// The sound on/off switch (mockup .sw): a 40×24 track with a 20pt knob that
/// slides 320ms drawer, plus the speaker glyph.
struct SoundToggle: View {
    @Bindable var model: AppModel

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var on: Bool { model.settings.soundEnabled }

    var body: some View {
        if theme.soundControlStyle == .ghostIcon {
            ghostSoundButton
        } else {
            trackedSoundToggle
        }
    }

    private var trackedSoundToggle: some View {
        HStack(spacing: 8) {
            StrokeIcon(systemName: on ? "speaker.wave.2" : "speaker.slash", size: 16, weight: .medium)
                .foregroundStyle(palette.ink2)

            if let sfxLabel = theme.soundToggleLabel {
                Text(sfxLabel)
                    .typeToken(theme.typeScale.segmentButton)
                    .foregroundStyle(palette.ink2)
            }

            Button {
                model.setSoundEnabled(!on)
            } label: {
                if theme.soundControlStyle == .cabinetSwitch {
                    cabinetSwitch
                } else {
                    legacySwitch
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(UIStrings.soundLabel)
            .accessibilityValue(on ? "on" : "off")
            .accessibilityAddTraits(.isToggle)
        }
    }

    /// Zen's sound affordance is a simple 34×30 icon target, not a switch. It
    /// still exposes the current on/off state to VoiceOver.
    private var ghostSoundButton: some View {
        Button {
            model.setSoundEnabled(!on)
        } label: {
            StrokeIcon(systemName: on ? "speaker.wave.2" : "speaker.slash", size: 16, weight: .medium)
                .foregroundStyle(on ? palette.accent : (isHovering ? palette.ink : palette.ink2))
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isHovering ? palette.rowHover : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(theme.motion.hoverFade.animation(reduceMotion: reduceMotion), value: isHovering)
        .accessibilityLabel(UIStrings.soundLabel)
        .accessibilityValue(on ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
    }

    /// The macOS capsule track + white circular knob with a soft drop shadow.
    private var legacySwitch: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(on ? palette.accent : palette.segmentBackground)
                .overlay(
                    Capsule().strokeBorder(palette.fieldLine, lineWidth: on ? 0 : palette.hairlineWidth)
                )
            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.35), radius: 1.2, y: 1)
                .padding(2)
        }
        .frame(width: 40, height: 24)
        .animation(theme.motion.soundKnob.animation(reduceMotion: reduceMotion), value: on)
    }

    /// The Arcade cabinet switch: a squared 38×20 track (no capsule) with a
    /// bordered knob that glows accent-colored when on. No soft shadow.
    private var cabinetSwitch: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(palette.segmentBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(palette.accent.opacity(on ? 0.16 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(on ? palette.accent : palette.checkRing, lineWidth: 2)
                )
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(on ? palette.accent : palette.ink3)
                .frame(width: 14, height: 14)
                .shadow(color: on ? palette.glow : .clear, radius: 4)
                .padding(3)
        }
        .frame(width: 38, height: 20)
        .animation(theme.motion.soundKnob.animation(reduceMotion: reduceMotion), value: on)
    }
}
