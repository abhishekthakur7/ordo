// OrdoUI — the hotkey capture control (§6.4). Captures a keyCode + modifier flags
// via a first-responder NSView and reports them; actual global registration is the
// shell's job (it observes AppSettings.hotkey). No registration happens here.

import SwiftUI
import AppKit

struct HotkeyRecorderField: View {
    @Binding var binding: HotkeyBinding

    @Environment(\.ordoTheme) private var theme
    @Environment(\.ordoPalette) private var palette
    @State private var recording = false

    var body: some View {
        Button {
            recording.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(recording ? UIStrings.hotkeyRecording : binding.displayString)
                    .typeToken(theme.typeScale.railLineValue)
                    .foregroundStyle(recording ? palette.accent : palette.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.fieldBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(recording ? palette.accent : palette.fieldLine,
                                          lineWidth: recording ? 1.5 : palette.hairlineWidth)
                    )
            )
        }
        .buttonStyle(.plain)
        .background(
            KeyCaptureView(isRecording: $recording) { keyCode, flags in
                let candidate = HotkeyBinding(keyCode: keyCode, flags: flags)
                // Require at least one modifier for a global hotkey; otherwise keep prior.
                if candidate.hasModifiers { binding = candidate }
                recording = false
            }
        )
    }
}

/// An invisible NSView that becomes first responder while recording and reports the
/// next modified key press.
private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ view: CaptureNSView, context: Context) {
        view.onCapture = onCapture
        if isRecording {
            DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        }
    }

    final class CaptureNSView: NSView {
        var onCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            onCapture?(event.keyCode, event.modifierFlags)
        }
    }
}
