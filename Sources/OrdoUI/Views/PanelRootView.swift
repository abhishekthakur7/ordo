// OrdoUI — PanelRootView: the complete SwiftUI interior of the Ordo panel (mockup
// 02-macos-glass). Draws content on a CLEAR background — the shell renders vibrancy +
// beak behind it; a forced Light/Dark overrides `.colorScheme` so themes self-resolve.

import SwiftUI
import OrdoCore
import OrdoThemes

public struct PanelRootView: View {
    @Bindable private var model: AppModel
    private let chrome: PanelChrome

    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @FocusState private var focus: PanelFocus?

    public init(model: AppModel, chrome: PanelChrome) {
        self.model = model
        self.chrome = chrome
    }

    // MARK: Resolution

    private var resolved: ResolvedUIAppearance {
        resolveAppearance(model.settings.appearance, systemIsDark: systemScheme == .dark)
    }

    private var palette: Palette {
        model.theme.palette(
            for: resolved.themeAppearance,
            accessibility: AccessibilityOptions(
                reduceTransparency: reduceTransparency,
                increaseContrast: contrast == .increased
            )
        )
    }

    private var expanded: Bool { model.settings.panelExpanded }

    /// This is driven by `PanelController` on each manual window-frame tick.
    /// It deliberately is not animated in SwiftUI: the native frame and every
    /// interior layout quantity must use the same instantaneous value.
    private var expansionProgress: CGFloat { model.panelExpansionProgress }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 0) {
            if model.theme.railOnTrailing {
                mainColumn
                rail
            } else {
                rail
                mainColumn
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.clear)
        .environment(\.ordoTheme, model.theme)
        .environment(\.ordoPalette, palette)
        .environment(\.colorScheme, resolved.colorScheme)
        .tint(palette.accent)
        .focusable()
        .focused($focus, equals: .root)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { handleKey($0) }
        .onAppear {
            model.reduceMotion = reduceMotion
            model.systemIsDark = systemScheme == .dark
            if focus == nil { focus = .root }
        }
        .onChange(of: reduceMotion) { _, new in model.reduceMotion = new }
        .onChange(of: systemScheme) { _, new in model.systemIsDark = new == .dark }
    }

    // MARK: Rail

    private var rail: some View {
        let dividerEdge: Alignment = model.theme.railOnTrailing ? .leading : .trailing
        return RailView(model: model)
            .offset(x: -10 * (1 - expansionProgress))
            .frame(width: model.theme.metrics.railWidth * expansionProgress, alignment: .leading)
            // Mock: rail geometry follows the 620 ms drawer curve, while its
            // visibility uses the shorter 380 ms CSS `ease` transition.
            .opacity(expanded ? 1 : 0)
            .animation(
                reduceMotion
                    ? nil
                    : .timingCurve(0.25, 0.10, 0.25, 1.0, duration: 0.380),
                value: expanded
            )
            .clipped()
            .overlay(alignment: dividerEdge) {
                Rectangle()
                    .fill(palette.divider)
                    .frame(width: palette.hairlineWidth)
            }
    }

    // MARK: Main column

    private var mainColumn: some View {
        VStack(spacing: model.theme.layout.mainColumnSpacing) {
            HeaderView(model: model, chrome: chrome)
            if let headerAccessory = model.theme.headerAccessory() {
                headerAccessory
                    .padding(headerAccessoryInsets)
            }
            TabBarView(model: model)
            if let statusRow = model.theme.statusRow(done: model.railDone, total: model.railTotal,
                                                       isToday: model.tab == .today) {
                statusRow
            }
            TaskListView(model: model, expanded: expanded)
                .frame(maxHeight: .infinity)
            ComposerView(model: model, focus: $focus)
            FooterView(model: model)
        }
        .padding(mainColumnInsets)
        // Zen's flexible main column shares the exact shell-driven fraction with
        // the rail, so its footer and other full-width controls never animate
        // independently of the window during an expand/collapse reversal.
        .frame(width: resolvedMainColumnWidth)
        .overlay(alignment: .bottom) { undoToast }
        .overlay { settingsOverlay }
        .overlay { arcadeFX }
    }

    private var mainColumnInsets: EdgeInsets {
        let insets = model.theme.layout.mainColumnInsets
        return EdgeInsets(top: insets.top, leading: insets.leading,
                          bottom: insets.bottom, trailing: insets.trailing)
    }

    private var resolvedMainColumnWidth: CGFloat {
        guard model.theme.mainColumnFlexes else {
            return model.theme.metrics.mainColumnWidth
        }
        let metrics = model.theme.metrics
        let compactWidth = metrics.panelCompactSize.width
        let expandedWidth = metrics.panelExpandedSize.width - metrics.railWidth
        return compactWidth + (expandedWidth - compactWidth) * expansionProgress
    }

    private var headerAccessoryInsets: EdgeInsets {
        let insets = model.theme.layout.dividerInsets
        return EdgeInsets(top: insets.top, leading: insets.leading,
                          bottom: insets.bottom, trailing: insets.trailing)
    }

    /// Completion-FX (score-pop, coin burst, confetti), mounted only when the
    /// theme opts in. Hit-testing is disabled inside the view itself.
    @ViewBuilder
    private var arcadeFX: some View {
        if model.theme.providesCompletionFX {
            ArcadeFXOverlay(model: model)
        }
    }

    @ViewBuilder
    private var undoToast: some View {
        if let toast = model.undoToast {
            UndoToastView(model: model, toast: toast)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var settingsOverlay: some View {
        if model.settingsOpen {
            SettingsView(model: model)
                .background(
                    // Opaque base so the list can't show through (the shell's blur is
                    // behind all content), plus the tint on top to keep the material look.
                    ZStack {
                        Rectangle().fill(palette.material.fallbackOpaque)
                        if !palette.material.usesFallback {
                            Rectangle().fill(palette.material.tint)
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    // MARK: Keyboard (§4.4)

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let mods = press.modifiers

        // ⌘-combinations
        if mods.contains(.command) {
            switch press.key {
            case KeyEquivalent("n"): focusComposer(); return .handled
            case KeyEquivalent("1"): model.selectTab(.today); return .handled
            case KeyEquivalent("2"): model.selectTab(.longterm); return .handled
            case KeyEquivalent("e"): toggleExpand(); return .handled
            default: break
            }
        }

        switch press.key {
        case .upArrow: model.moveSelection(.up); return .handled
        case .downArrow: model.moveSelection(.down); return .handled
        case .space:
            if let sel = model.selectedID { model.toggle(sel); return .handled }
            return .ignored
        case .return:
            if let sel = model.selectedID { beginEdit(sel); return .handled }
            return .ignored
        case .delete, .deleteForward:
            if let sel = model.selectedID { model.delete(sel); return .handled }
            return .ignored
        case .escape:
            if model.settingsOpen {
                withAnimation(model.theme.motion.panelExit.animation(reduceMotion: reduceMotion)) {
                    model.settingsOpen = false
                }
            } else {
                chrome.requestClose()
            }
            return .handled
        default:
            break
        }

        if press.characters == "/" && mods.isEmpty {
            focusComposer()
            return .handled
        }
        return .ignored
    }

    private func focusComposer() { focus = .composer }

    private func beginEdit(_ id: UUID) {
        model.beginEditing(id)
    }

    private func toggleExpand() {
        let next = !model.settings.panelExpanded
        model.settings.panelExpanded = next
        // The chrome bridge defers and coalesces frame work after this SwiftUI
        // state change; all expand affordances use that same sequencing.
        chrome.setExpanded(next)
    }
}
