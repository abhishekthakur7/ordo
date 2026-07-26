// OrdoUI — the panel-chrome bridge (cross-module contract C4). The minimal protocol
// the SwiftUI interior uses to ask the AppKit shell to close or resize the NSPanel —
// window geometry the interior cannot touch itself.

import Foundation

/// The bridge from the SwiftUI interior to the AppKit shell. All calls are made
/// on the main actor (the UI is main-actor confined).
@MainActor
public protocol PanelChrome: AnyObject {
    /// Ask the shell to dismiss the panel (Esc, ⌘W-style close). The shell runs
    /// its exit animation and then calls `AppModel.panelDidClose()`.
    func requestClose()

    /// Ask the shell to animate the NSPanel frame to the expanded/compact size.
    /// The UI has already flipped `AppSettings.panelExpanded`; this only drives the
    /// window geometry so the two stay in lockstep.
    func setExpanded(_ expanded: Bool)

    /// Optional hint that the interior interaction state changed (typing, editing,
    /// dragging). The shell may use it to hold non-activating dismissal while a
    /// field is engaged. No-op is a valid implementation.
    func notifyInteraction(active: Bool)
}

/// A do-nothing chrome for SwiftUI previews and unit tests that never touch a
/// real NSPanel.
@MainActor
public final class NoopPanelChrome: PanelChrome {
    public init() {}
    public func requestClose() {}
    public func setExpanded(_ expanded: Bool) {}
    public func notifyInteraction(active: Bool) {}
}
