/// An explicit four-edge inset token. It deliberately uses `Double` rather
/// than SwiftUI's `EdgeInsets` so the token remains platform-neutral,
/// `Sendable`, and `Hashable`.
public struct ThemeInsets: Sendable, Hashable {
    public var top: Double
    public var leading: Double
    public var bottom: Double
    public var trailing: Double

    public init(top: Double = 0, leading: Double = 0, bottom: Double = 0, trailing: Double = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public static let zero = ThemeInsets()
}

/// Layout tokens for the panel's shared regions. `legacy` is a transcription of
/// the hard-coded geometry currently used by the shared macOS layout. The UI
/// does not consume these tokens yet; Phase 5 can replace each corresponding
/// literal without changing the protocol again.
public struct ThemeLayout: Sendable, Hashable {
    // Panel main column and header.
    public var railInsets: ThemeInsets
    public var mainColumnInsets: ThemeInsets
    public var mainColumnSpacing: Double
    public var headerInsets: ThemeInsets
    public var headerContentSpacing: Double
    public var headerControlsSpacing: Double
    public var headerTextSpacing: Double
    public var headerTrailingAccessorySpacing: Double

    // Header divider/accessory, tabs, status stage, and scrolling list.
    public var dividerInsets: ThemeInsets
    public var dividerHeight: Double
    public var tabInsets: ThemeInsets
    public var tabHeight: Double
    public var tabCornerRadius: Double
    public var tabThumbInset: Double
    public var tabTrackCornerRadius: Double
    public var tabLabelSpacing: Double
    public var tabCellInsets: ThemeInsets
    public var tabSublineSpacing: Double
    public var tabIndicatorHeight: Double
    public var tabIndicatorBottomInset: Double
    public var stageTopSpacing: Double
    public var stageInsets: ThemeInsets
    public var listInsets: ThemeInsets
    public var listRowSpacing: Double

    // Task rows.
    public var rowInsets: ThemeInsets
    public var rowContentSpacing: Double
    public var rowStackSpacing: Double
    public var rowTrailingSpacing: Double
    public var rowActionsSpacing: Double
    public var rowTitleTrailingReserve: Double
    public var triageInsets: ThemeInsets
    public var triageContentSpacing: Double

    // Composer and footer.
    public var composerInsets: ThemeInsets
    public var composerStackSpacing: Double
    public var composerFieldSpacing: Double
    public var composerFieldInsets: ThemeInsets
    public var composerFieldMinimumHeight: Double
    public var footerInsets: ThemeInsets
    public var footerContentSpacing: Double

    // Empty and all-cleared states.
    public var emptyStateInsets: ThemeInsets
    public var emptyStateContentSpacing: Double
    public var emptyIconBottomSpacing: Double
    public var emptyBodyTopSpacing: Double
    public var clearedStateInsets: ThemeInsets
    public var clearedStateContentSpacing: Double
    public var clearedIconBottomSpacing: Double
    public var clearedBodyTopSpacing: Double
    public var clearedPeekTopSpacing: Double
    public var clearedStateFillsAvailableSpace: Bool

    public init(
        railInsets: ThemeInsets,
        mainColumnInsets: ThemeInsets,
        mainColumnSpacing: Double,
        headerInsets: ThemeInsets,
        headerContentSpacing: Double,
        headerControlsSpacing: Double,
        headerTextSpacing: Double,
        headerTrailingAccessorySpacing: Double,
        dividerInsets: ThemeInsets,
        dividerHeight: Double,
        tabInsets: ThemeInsets,
        tabHeight: Double,
        tabCornerRadius: Double,
        tabThumbInset: Double,
        tabTrackCornerRadius: Double,
        tabLabelSpacing: Double,
        tabCellInsets: ThemeInsets,
        tabSublineSpacing: Double,
        tabIndicatorHeight: Double,
        tabIndicatorBottomInset: Double,
        stageTopSpacing: Double,
        stageInsets: ThemeInsets,
        listInsets: ThemeInsets,
        listRowSpacing: Double,
        rowInsets: ThemeInsets,
        rowContentSpacing: Double,
        rowStackSpacing: Double,
        rowTrailingSpacing: Double,
        rowActionsSpacing: Double,
        rowTitleTrailingReserve: Double,
        triageInsets: ThemeInsets,
        triageContentSpacing: Double,
        composerInsets: ThemeInsets,
        composerStackSpacing: Double,
        composerFieldSpacing: Double,
        composerFieldInsets: ThemeInsets,
        composerFieldMinimumHeight: Double,
        footerInsets: ThemeInsets,
        footerContentSpacing: Double,
        emptyStateInsets: ThemeInsets,
        emptyStateContentSpacing: Double,
        emptyIconBottomSpacing: Double,
        emptyBodyTopSpacing: Double,
        clearedStateInsets: ThemeInsets,
        clearedStateContentSpacing: Double,
        clearedIconBottomSpacing: Double,
        clearedBodyTopSpacing: Double,
        clearedPeekTopSpacing: Double,
        clearedStateFillsAvailableSpace: Bool
    ) {
        self.railInsets = railInsets
        self.mainColumnInsets = mainColumnInsets
        self.mainColumnSpacing = mainColumnSpacing
        self.headerInsets = headerInsets
        self.headerContentSpacing = headerContentSpacing
        self.headerControlsSpacing = headerControlsSpacing
        self.headerTextSpacing = headerTextSpacing
        self.headerTrailingAccessorySpacing = headerTrailingAccessorySpacing
        self.dividerInsets = dividerInsets
        self.dividerHeight = dividerHeight
        self.tabInsets = tabInsets
        self.tabHeight = tabHeight
        self.tabCornerRadius = tabCornerRadius
        self.tabThumbInset = tabThumbInset
        self.tabTrackCornerRadius = tabTrackCornerRadius
        self.tabLabelSpacing = tabLabelSpacing
        self.tabCellInsets = tabCellInsets
        self.tabSublineSpacing = tabSublineSpacing
        self.tabIndicatorHeight = tabIndicatorHeight
        self.tabIndicatorBottomInset = tabIndicatorBottomInset
        self.stageTopSpacing = stageTopSpacing
        self.stageInsets = stageInsets
        self.listInsets = listInsets
        self.listRowSpacing = listRowSpacing
        self.rowInsets = rowInsets
        self.rowContentSpacing = rowContentSpacing
        self.rowStackSpacing = rowStackSpacing
        self.rowTrailingSpacing = rowTrailingSpacing
        self.rowActionsSpacing = rowActionsSpacing
        self.rowTitleTrailingReserve = rowTitleTrailingReserve
        self.triageInsets = triageInsets
        self.triageContentSpacing = triageContentSpacing
        self.composerInsets = composerInsets
        self.composerStackSpacing = composerStackSpacing
        self.composerFieldSpacing = composerFieldSpacing
        self.composerFieldInsets = composerFieldInsets
        self.composerFieldMinimumHeight = composerFieldMinimumHeight
        self.footerInsets = footerInsets
        self.footerContentSpacing = footerContentSpacing
        self.emptyStateInsets = emptyStateInsets
        self.emptyStateContentSpacing = emptyStateContentSpacing
        self.emptyIconBottomSpacing = emptyIconBottomSpacing
        self.emptyBodyTopSpacing = emptyBodyTopSpacing
        self.clearedStateInsets = clearedStateInsets
        self.clearedStateContentSpacing = clearedStateContentSpacing
        self.clearedIconBottomSpacing = clearedIconBottomSpacing
        self.clearedBodyTopSpacing = clearedBodyTopSpacing
        self.clearedPeekTopSpacing = clearedPeekTopSpacing
        self.clearedStateFillsAvailableSpace = clearedStateFillsAvailableSpace
    }

    /// The current hard-coded shared macOS geometry. Field comments above map
    /// directly to `PanelRootView`, `HeaderView`, `TabBarView`, `TaskListView`,
    /// `TaskRowView`, `ComposerView`, `FooterView`, and the macOS signature states.
    public static let legacy = ThemeLayout(
        railInsets: .zero,
        mainColumnInsets: .zero,
        mainColumnSpacing: 0,
        headerInsets: ThemeInsets(top: 15, leading: 18, bottom: 10, trailing: 12),
        headerContentSpacing: 10,
        headerControlsSpacing: 6,
        headerTextSpacing: 2,
        headerTrailingAccessorySpacing: 0,
        dividerInsets: .zero,
        dividerHeight: 0,
        tabInsets: ThemeInsets(top: 4, leading: 16, bottom: 6, trailing: 16),
        tabHeight: 28,
        tabCornerRadius: 7,
        tabThumbInset: 3,
        tabTrackCornerRadius: 9,
        tabLabelSpacing: 6,
        tabCellInsets: .zero,
        tabSublineSpacing: 0,
        tabIndicatorHeight: 0,
        tabIndicatorBottomInset: 0,
        stageTopSpacing: 0,
        stageInsets: .zero,
        listInsets: ThemeInsets(top: 4, leading: 12, bottom: 8, trailing: 12),
        listRowSpacing: 0,
        rowInsets: ThemeInsets(top: 9, leading: 10, bottom: 9, trailing: 10),
        rowContentSpacing: 11,
        rowStackSpacing: 6,
        rowTrailingSpacing: 6,
        rowActionsSpacing: 2,
        rowTitleTrailingReserve: 0,
        triageInsets: ThemeInsets(top: 0, leading: 33, bottom: 0, trailing: 2),
        triageContentSpacing: 8,
        composerInsets: ThemeInsets(top: 8, leading: 14, bottom: 10, trailing: 14),
        composerStackSpacing: 8,
        composerFieldSpacing: 9,
        composerFieldInsets: ThemeInsets(top: 0, leading: 12, bottom: 0, trailing: 6),
        composerFieldMinimumHeight: 40,
        footerInsets: ThemeInsets(top: 8, leading: 14, bottom: 12, trailing: 14),
        footerContentSpacing: 10,
        emptyStateInsets: ThemeInsets(top: 26, leading: 24, bottom: 20, trailing: 24),
        emptyStateContentSpacing: 0,
        emptyIconBottomSpacing: 14,
        emptyBodyTopSpacing: 4,
        clearedStateInsets: ThemeInsets(top: 26, leading: 24, bottom: 20, trailing: 24),
        clearedStateContentSpacing: 0,
        clearedIconBottomSpacing: 14,
        clearedBodyTopSpacing: 4,
        clearedPeekTopSpacing: 0,
        clearedStateFillsAvailableSpace: false
    )
}
