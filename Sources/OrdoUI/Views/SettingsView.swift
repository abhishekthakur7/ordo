// OrdoUI — the in-panel settings pane (§6.4): launch-at-login, the hotkey recorder,
// and the day-start-offset control (writes through the store, NOT UserDefaults).
// Appearance & sound stay in the footer; registration side effects are the shell's.

import SwiftUI
import OrdoThemes

struct SettingsView: View {
    @Bindable var model: AppModel

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(palette.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    themeSection
                    launchAtLogin
                    hotkeySection
                    dayStartSection
                }
                .padding(EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18))
            }
        }
        .background(backgroundFill)
    }

    private var header: some View {
        HStack {
            theme.typeScale.greeting.styled(UIStrings.settingsTitle)
                .foregroundStyle(palette.ink)
            Spacer()
            Button(UIStrings.settingsDone) {
                withAnimation(theme.motion.panelExit.animation(reduceMotion: reduceMotion)) {
                    model.settingsOpen = false
                }
            }
            .buttonStyle(PressScaleButtonStyle())
            .typeToken(theme.typeScale.segmentButton)
            .foregroundStyle(palette.accent)
        }
        .padding(EdgeInsets(top: 15, leading: 18, bottom: 12, trailing: 16))
    }

    // MARK: Theme

    private var themeSection: some View {
        HStack {
            theme.typeScale.railLine.styled(UIStrings.themeTitle)
                .foregroundStyle(palette.ink)
            Spacer()
            Picker("", selection: themeBinding) {
                ForEach(ThemeRegistry.shared.all, id: \.id) { available in
                    Text(available.displayName).tag(available.id)
                }
            }
            .labelsHidden()
            .fixedSize()
            .tint(palette.accent)
        }
    }

    private var themeBinding: Binding<ThemeID> {
        Binding(
            get: { model.settings.themeID },
            set: { model.settings.themeID = $0 }
        )
    }

    // MARK: Launch at login

    private var launchAtLogin: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: launchBinding) {
                theme.typeScale.railLine.styled(UIStrings.launchAtLogin)
                    .foregroundStyle(palette.ink)
            }
            .toggleStyle(.switch)
            .tint(palette.accent)

            if !model.settings.launchAtLoginConsented {
                theme.typeScale.emptyBody.styled(UIStrings.launchAtLoginConsent)
                    .foregroundStyle(palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { model.settings.launchAtLoginEnabled },
            set: { newValue in
                model.settings.launchAtLoginEnabled = newValue
                model.settings.launchAtLoginConsented = true
            }
        )
    }

    // MARK: Hotkey

    private var hotkeySection: some View {
        HStack {
            theme.typeScale.railLine.styled(UIStrings.summonHotkey)
                .foregroundStyle(palette.ink)
            Spacer()
            HotkeyRecorderField(binding: hotkeyBinding)
        }
    }

    private var hotkeyBinding: Binding<HotkeyBinding> {
        Binding(
            get: { model.settings.hotkey },
            set: { model.settings.hotkey = $0 }
        )
    }

    // MARK: Day start offset (writes through the store)

    private var dayStartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                theme.typeScale.railLine.styled(UIStrings.dayStartTitle)
                    .foregroundStyle(palette.ink)
                Spacer()
                Picker("", selection: dayStartBinding) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .tint(palette.accent)
            }
            theme.typeScale.emptyBody.styled(UIStrings.dayStartHelp)
                .foregroundStyle(palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dayStartBinding: Binding<Int> {
        Binding(
            get: { model.dayStartOffsetHours },
            set: { model.setDayStartOffsetHours($0) }
        )
    }

    @ViewBuilder
    private var backgroundFill: some View {
        if palette.material.usesFallback {
            palette.material.fallbackOpaque
        } else {
            Color.clear
        }
    }
}
