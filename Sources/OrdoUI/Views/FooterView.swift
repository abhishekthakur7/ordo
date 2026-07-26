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
            HStack(spacing: 4) {
                StrokeIcon(systemName: icon(for: option), size: 12, weight: .medium)
                theme.typeScale.segmentButton.styled(label(for: option))
            }
            .foregroundStyle(isActive ? palette.ink : palette.ink2)
            .padding(.horizontal, 10)
        }
        .accessibilityLabel(UIStrings.appearanceLabel)
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

            Button {
                model.setSoundEnabled(!on)
            } label: {
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
            .buttonStyle(.plain)
            .accessibilityLabel(UIStrings.soundLabel)
            .accessibilityValue(on ? "on" : "off")
            .accessibilityAddTraits(.isToggle)
        }
    }
}
