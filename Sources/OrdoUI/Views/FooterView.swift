// OrdoUI — footer (mockup .foot): the appearance segmented control (Auto/Light/
// Dark) with a sliding thumb, and the sound toggle switch. Both live.

import SwiftUI
import OrdoThemes

struct FooterView: View {
    @Bindable var model: AppModel

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            appearanceControl
            Spacer(minLength: 0)
            SoundToggle(model: model)
        }
        .padding(EdgeInsets(top: 8, leading: 14, bottom: 12, trailing: 14))
    }

    private var appearanceControl: some View {
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
                if theme.showsAppearanceLabels {
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

/// The sound on/off switch (mockup .sw): a 40×24 track with a 20pt knob that
/// slides 320ms drawer, plus the speaker glyph.
struct SoundToggle: View {
    @Bindable var model: AppModel

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var on: Bool { model.settings.soundEnabled }

    var body: some View {
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
                if theme.usesCabinetControls {
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
