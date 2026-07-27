import SwiftUI
import OrdoCore

// MARK: - Environment → palette bridge

/// Resolves Zen Ink's live palette locally. Keeping this bridge private avoids
/// leaking environment concerns into the primitive-only `Theme` contract.
private struct Themed<Content: View>: View {
    let theme: ZenInkTheme
    @ViewBuilder let content: (Palette, Bool) -> Content

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        content(
            theme.palette(
                for: ResolvedAppearance(scheme),
                accessibility: AccessibilityOptions(
                    reduceTransparency: reduceTransparency,
                    increaseContrast: contrast == .increased
                )
            ),
            reduceMotion
        )
    }
}

/// The roughened SVG paths are shared with the signature views, but their
/// wrapper is file-private there. This keeps structural marks on the same
/// deterministic ink-rough-2 treatment.
private struct ZenRoughBrushStroke: Shape {
    let kind: BrushStrokeKind

    func path(in rect: CGRect) -> Path {
        BrushStrokeShape(kind).sumiPath(in: rect)
    }
}

/// SwiftUI does not expose CSS's `writing-mode: vertical-rl`. A compact stack
/// of upright glyphs reproduces the mockup's Japanese vertical setting while
/// keeping every glyph legible rather than rotating it sideways.
private struct ZenVerticalText: View {
    let text: String
    let token: TypeToken
    let color: Color
    let spacing: CGFloat

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(text.filter { !$0.isWhitespace }.enumerated()), id: \.offset) { _, glyph in
                Text(String(glyph))
                    .typeToken(token)
                    .foregroundStyle(color)
                    .fixedSize()
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Header

/// `.head-id`: the vermilion 序 wordmark and its vertical せいひつ subtitle.
struct ZenHeaderLeading: View {
    let theme: ZenInkTheme

    // The constrained `writing-mode: vertical-rl` subtitle wraps into two
    // right-to-left columns in the mock. Its small optical inset is local to
    // that subtitle; the wordmark itself begins at the header's top edge.
    private static let verticalLabelHeight: CGFloat = 34
    private static let verticalLabelTopInset: CGFloat = 5

    var body: some View {
        Themed(theme: theme) { palette, _ in
            HStack(alignment: .top, spacing: theme.layout.headerTextSpacing) {
                HStack(spacing: 1) {
                    Text("序")
                        .typeToken(ZenInkTheme.wordmarkType)
                        .foregroundStyle(palette.accent)
                    Text("Ordo")
                        .typeToken(ZenInkTheme.wordmarkType)
                        .foregroundStyle(palette.ink)
                }
                .fixedSize()

                HStack(alignment: .top, spacing: 4) {
                    // CSS vertical-rl fills the right column first.
                    ZenVerticalText(
                        text: "ひつ",
                        token: ZenInkTheme.headSubType,
                        color: palette.inkFaint,
                        spacing: -0.67
                    )
                    ZenVerticalText(
                        text: "せい",
                        token: ZenInkTheme.headSubType,
                        color: palette.inkFaint,
                        spacing: -0.67
                    )
                }
                .frame(height: Self.verticalLabelHeight, alignment: .top)
                .padding(.top, Self.verticalLabelTopInset)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("序 Ordo, せいひつ")
        }
    }
}

/// The compact header ensō. Its layout width and leading margin truly collapse
/// when the rail opens, matching `.head-enso` rather than merely fading it.
struct ZenHeaderTrailing: View {
    let theme: ZenInkTheme
    let done: Int
    let total: Int
    let expanded: Bool

    private var clampedDone: Int { min(max(done, 0), max(total, 0)) }
    private var remaining: Int { max(0, total - clampedDone) }

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            ZStack {
                EnsoShape()
                    .stroke(
                        palette.fieldLine,
                        style: StrokeStyle(lineWidth: theme.metrics.compactRingStrokeWidth, lineCap: .round)
                    )
                EnsoShape(progress: total > 0 ? Double(clampedDone) / Double(total) : 0)
                    .stroke(
                        palette.ink,
                        style: StrokeStyle(lineWidth: theme.metrics.compactRingStrokeWidth, lineCap: .round)
                    )
                    .animation(reduceMotion ? nil : theme.motion.ring.standard, value: done)
                    .animation(reduceMotion ? nil : theme.motion.ring.standard, value: total)
                // The mock swaps the glyph: old value fades upward, changes at
                // 200 ms, then the new value settles. A numeric digit morph is
                // noticeably busier during task completion.
                ZenRemainingCount(
                    theme: theme,
                    palette: palette,
                    remaining: remaining,
                    reduceMotion: reduceMotion,
                    typeToken: ZenInkTheme.headCountType
                )
            }
            .frame(width: theme.metrics.compactRingDiameter, height: theme.metrics.compactRingDiameter)
            .frame(width: expanded ? 0 : theme.metrics.compactRingDiameter,
                   height: theme.metrics.compactRingDiameter)
            .clipped()
            .padding(.leading, expanded ? -theme.layout.headerTrailingAccessorySpacing : 0)
            .animation(reduceMotion ? nil : theme.motion.expandMorph.standard, value: expanded)
            .opacity(expanded ? 0 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.320), value: expanded)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(remaining) remaining, \(clampedDone) of \(max(total, 0)) complete")
            .accessibilityHidden(expanded)
        }
    }
}

// MARK: - Header accessory

/// Full-width 340×12 source path, stretched to the live main-column width.
struct ZenBrushDivider: View {
    let theme: ZenInkTheme

    var body: some View {
        Themed(theme: theme) { palette, _ in
            ZenRoughBrushStroke(kind: .divider)
                .fill(palette.ink.opacity(0.66))
                .frame(maxWidth: .infinity)
                .frame(height: theme.layout.dividerHeight)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Tabs

/// Zen Ink's two equal semantic tabs. The count closure deliberately remains
/// out of the visual treatment (the mockup has no badge), but is announced to
/// assistive technologies so the open-work state is still available.
struct ZenTabBar: View {
    let theme: ZenInkTheme
    let tab: TaskList
    let remaining: (TaskList) -> Int
    let onSelect: (TaskList) -> Void

    @State private var hovered: TaskList?

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: 0) {
                    tabButton(
                        for: .today,
                        main: "Today",
                        sub: "今日",
                        palette: palette,
                        reduceMotion: reduceMotion
                    )
                    tabButton(
                        for: .longterm,
                        main: "道",
                        sub: "THE PATH",
                        palette: palette,
                        reduceMotion: reduceMotion
                    )
                }

                GeometryReader { proxy in
                    let halfWidth = proxy.size.width / 2
                    ZenRoughBrushStroke(kind: .tabInk)
                        .fill(palette.accent)
                        .frame(width: halfWidth * 0.56, height: theme.layout.tabIndicatorHeight)
                        .frame(width: halfWidth, height: theme.layout.tabIndicatorHeight)
                        .offset(x: tab == .today ? 0 : halfWidth)
                        .animation(reduceMotion ? nil : theme.motion.tabThumb.standard, value: tab)
                }
                .frame(height: theme.layout.tabIndicatorHeight)
                .padding(.bottom, theme.layout.tabIndicatorBottomInset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .padding(.top, theme.layout.tabInsets.top)
            .padding(.bottom, theme.layout.tabInsets.bottom)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Task lists")
        }
    }

    private func tabButton(
        for candidate: TaskList,
        main: String,
        sub: String,
        palette: Palette,
        reduceMotion: Bool
    ) -> some View {
        let active = tab == candidate
        let hovering = hovered == candidate
        let mainColor = active ? palette.ink : (hovering ? palette.ink2 : palette.inkFaint)
        let subColor = active ? palette.ink3 : palette.inkFaint

        return Button {
            onSelect(candidate)
        } label: {
            VStack(spacing: theme.layout.tabSublineSpacing) {
                Text(main)
                    .typeToken(theme.typeScale.tab)
                    .foregroundStyle(mainColor)
                Text(sub)
                    .typeToken(ZenInkTheme.tabSubType)
                    .foregroundStyle(subColor)
            }
            .frame(maxWidth: .infinity)
            .padding(
                EdgeInsets(
                    top: theme.layout.tabCellInsets.top,
                    leading: theme.layout.tabCellInsets.leading,
                    bottom: theme.layout.tabCellInsets.bottom,
                    trailing: theme.layout.tabCellInsets.trailing
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in hovered = inside ? candidate : nil }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.340), value: active)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.340), value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(main), \(sub)")
        .accessibilityValue("\(remaining(candidate)) remaining")
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityHint(active ? "Selected tab" : "Show this task list")
    }
}

// MARK: - Row trailing accessory

/// Every Zen row reserves a 27-point vermilion seal slot. Its inner treatment
/// communicates completion while the stable outer geometry keeps rows aligned.
struct ZenRowTrailing: View {
    let theme: ZenInkTheme
    let done: Bool

    var body: some View {
        OrdoZenHanko(theme: theme, done: done)
            .frame(width: 27, height: 27)
            .accessibilityHidden(true)
    }
}

// MARK: - Rail

private struct ZenRailEnso: View {
    let theme: ZenInkTheme
    let done: Int
    let total: Int
    let palette: Palette
    let reduceMotion: Bool

    private var clampedDone: Int { min(max(done, 0), max(total, 0)) }
    private var remaining: Int { max(0, total - clampedDone) }

    var body: some View {
        ZStack {
            EnsoShape()
                .stroke(palette.fieldLine, style: StrokeStyle(lineWidth: theme.metrics.ringStrokeWidth, lineCap: .round))
            EnsoShape(progress: total > 0 ? Double(clampedDone) / Double(total) : 0)
                .stroke(palette.ink, style: StrokeStyle(lineWidth: theme.metrics.ringStrokeWidth, lineCap: .round))
                .animation(reduceMotion ? nil : theme.motion.ring.standard, value: done)
                .animation(reduceMotion ? nil : theme.motion.ring.standard, value: total)
            Text("\(remaining)")
                .typeToken(theme.typeScale.ringNumber)
                .foregroundStyle(palette.ink)
                .contentTransition(.numericText())
        }
        .frame(width: 132, height: 132)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(remaining) remaining, \(clampedDone) of \(max(total, 0)) complete")
    }
}

/// `.rail-inner`: an intentionally quiet meditation rail with only progress
/// and the bottom-pinned poem, rather than dashboard statistics.
struct ZenRailContent: View {
    let theme: ZenInkTheme
    let done: Int
    let total: Int
    let remaining: Int

    var body: some View {
        Themed(theme: theme) { palette, reduceMotion in
            VStack(alignment: .center, spacing: 0) {
                HStack(alignment: .top, spacing: 2) {
                    ZenVerticalText(
                        text: "序 の 道",
                        token: ZenInkTheme.railVertType,
                        color: palette.ink,
                        spacing: -1
                    )
                    ZenVerticalText(
                        text: "ORDO",
                        token: ZenInkTheme.railVertSmallType,
                        color: palette.ink3,
                        spacing: 0
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .leading)
                .padding(.leading, 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("序 の 道, Ordo")

                ZenRailEnso(theme: theme, done: done, total: total, palette: palette, reduceMotion: reduceMotion)
                    .padding(.top, 6)

                Text("REMAINING")
                    .typeToken(theme.typeScale.railKicker)
                    .foregroundStyle(palette.ink3)
                    .padding(.top, 16)

                Spacer(minLength: 0)

                VStack(spacing: 5) {
                    Text("一息、一事")
                        .typeToken(theme.typeScale.railLineValue)
                        .foregroundStyle(palette.ink2)
                    Text("one breath,\none thing")
                        .typeToken(theme.typeScale.railQuote)
                        .foregroundStyle(palette.ink3)
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("一息、一事. One breath, one thing")
            }
            .padding(
                EdgeInsets(
                    top: theme.layout.railInsets.top,
                    leading: theme.layout.railInsets.leading,
                    bottom: theme.layout.railInsets.bottom,
                    trailing: theme.layout.railInsets.trailing
                )
            )
            .frame(width: theme.metrics.railWidth, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Planning view, \(max(0, remaining)) remaining")
        }
    }
}

// MARK: - Theme structural hooks

extension ZenInkTheme {
    public func headerLeading(score: Int) -> AnyView? {
        AnyView(ZenHeaderLeading(theme: self))
    }

    public func headerAccessory() -> AnyView? {
        AnyView(ZenBrushDivider(theme: self))
    }

    public func headerTrailingAccessory(done: Int, total: Int, expanded: Bool) -> AnyView? {
        AnyView(ZenHeaderTrailing(theme: self, done: done, total: total, expanded: expanded))
    }

    public func tabBarContent(
        tab: TaskList,
        remaining: @escaping (TaskList) -> Int,
        onSelect: @escaping (TaskList) -> Void
    ) -> AnyView? {
        AnyView(ZenTabBar(theme: self, tab: tab, remaining: remaining, onSelect: onSelect))
    }

    public func rowTrailingAccessory(done: Bool, age: Int, triage: Bool, index: Int?) -> AnyView? {
        AnyView(ZenRowTrailing(theme: self, done: done))
    }

    public func railContent(
        done: Int,
        total: Int,
        remaining: Int,
        score: Int,
        best: Int,
        streak: Int
    ) -> AnyView? {
        AnyView(ZenRailContent(theme: self, done: done, total: total, remaining: remaining))
    }

    public func composerPlaceholder(isToday: Bool) -> String? {
        "書く… write the next thing"
    }
}
