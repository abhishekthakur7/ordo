// OrdoUI — focus targets inside the panel, driven by keyboard shortcuts (§4.4).

import Foundation

/// Focusable regions of the panel. The root view owns one `@FocusState` of this
/// type so ⌘N / "/" can focus the composer and the root can reclaim key handling.
public enum PanelFocus: Hashable, Sendable {
    case root
    case composer
}
