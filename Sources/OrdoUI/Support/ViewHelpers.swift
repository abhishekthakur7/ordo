// OrdoUI — small view helpers: multi-layer shadows and the row entrance transition,
// all derived from theme tokens (zero hardcoded numbers).

import SwiftUI
import OrdoThemes

extension View {
    /// Apply a stack of `ShadowLayer`s (the CSS `box-shadow` list) as SwiftUI shadows.
    func ordoShadows(_ layers: [ShadowLayer]) -> some View {
        layers.reduce(AnyView(self)) { view, layer in
            AnyView(view.shadow(
                color: layer.color,
                radius: layer.swiftUIRadius,
                x: layer.x,
                y: layer.y
            ))
        }
    }
}

extension AnyTransition {
    /// The theme's row-entrance transform (translateY + scale + fade) as an
    /// asymmetric transition: entrance from the transform, removal a quick fade.
    static func ordoRowEntrance(_ transform: RowEntranceTransform) -> AnyTransition {
        let insertion = AnyTransition.modifier(
            active: RowEntranceModifier(translateY: transform.translateY, scale: transform.scale, opacity: 0),
            identity: RowEntranceModifier(translateY: 0, scale: 1, opacity: 1)
        )
        let removal = AnyTransition.modifier(
            active: RowEntranceModifier(translateY: 0, scale: 0.98, opacity: 0),
            identity: RowEntranceModifier(translateY: 0, scale: 1, opacity: 1)
        )
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

private struct RowEntranceModifier: ViewModifier {
    let translateY: Double
    let scale: Double
    let opacity: Double
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: translateY)
    }
}

extension TypeToken {
    /// A SwiftUI `Text` styling helper that also applies uppercasing when the token
    /// requests it (CSS `text-transform: uppercase`).
    @ViewBuilder
    func styled(_ text: String) -> some View {
        Text(uppercase ? text.uppercased() : text)
            .typeToken(self)
    }
}
