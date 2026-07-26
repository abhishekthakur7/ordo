// OrdoApp — PanelWindow: a borderless, non-activating NSPanel that can still take key
// status (ARCHITECTURE §6.1). Borderless windows return false from `canBecomeKey` by
// default, so we override it — SwiftUI TextFields/`.onKeyPress` need the window key.

import AppKit

final class PanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
