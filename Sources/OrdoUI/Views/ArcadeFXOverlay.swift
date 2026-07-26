// OrdoUI — ArcadeFXOverlay: Phase 5 "juice" for the Arcade theme. A pointer-events-off
// overlay above `PanelRootView.mainColumn` that observes `AppModel.arcadeFXEvent` and
// spawns transient particles: a coin-gold "+100" score-pop + a 9-bit radial burst on
// task completion, and a 34-piece confetti fall on stage-clear. Mounted ONLY when
// `model.theme.providesCompletionFX` is true (Arcade); every other theme never
// instantiates this view, so macOS is byte-for-byte unaffected.
//
// Reduce-Motion is a full no-op: `AppModel` never sets `arcadeFXEvent` while
// `reduceMotion` is true (see `AppModel.toggle`), and this view's own `onChange`
// handler re-checks the environment flag defensively before spawning anything, so
// even a hypothetical stale/late event can't animate.
//
// Row flash and segment-pop (the mockup's other two completion beats,
// `celebrateRow`'s `row.classList.add('flash')` and `popSegments()`) are
// DELIBERATELY NOT implemented here: both need geometry/state this
// panel-level overlay doesn't have — row flash needs the completed row's own
// view (`TaskRowView`, owned by the concurrent Phase 6/7 agent this phase),
// and segment-pop needs the segbar's own view (`ArcadeStatusRow` in
// `ArcadeStructuralViews.swift`, also off-limits this phase). Both are
// documented future refinements rather than approximated badly from here.

import SwiftUI
import OrdoThemes

struct ArcadeFXOverlay: View {
    let model: AppModel

    @Environment(\.ordoPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scorePops: [ScorePopParticle] = []
    @State private var bits: [BitParticle] = []
    @State private var confetti: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(scorePops) { pop in
                    ScorePopView(anchor: pop.anchor, palette: palette)
                }
                ForEach(bits) { bit in
                    BitView(bit: bit, palette: palette)
                }
                ForEach(confetti) { piece in
                    ConfettiView(piece: piece, palette: palette, floor: proxy.size.height + 30)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .onChange(of: model.arcadeFXEvent) { _, event in
                guard !reduceMotion, let event else { return }
                switch event.kind {
                case .complete:
                    celebrateComplete(in: proxy.size)
                case .stageClear:
                    fireConfetti(in: proxy.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Score-pop + burst (on task complete)

    /// JUDGMENT CALL — anchor position: the mockup anchors `scorePop`/`burst` at
    /// the completed row's own checkbox via real DOM geometry (`rel(check)`).
    /// This overlay sits above the ENTIRE `mainColumn` (header, tab bar, status
    /// row, list, composer, footer) with no per-row coordinate threaded up to
    /// it, and adding that plumbing would mean touching `TaskRowView` — Agent
    /// B's file this phase. As a reasonable approximation, every completion
    /// anchors to a fixed point near the top-left of the task list, just under
    /// where the status row sits (the mockup's own completions cluster near
    /// there in the compact panel too, since new/just-toggled rows are close
    /// to the top).
    private func celebrateComplete(in size: CGSize) {
        let anchor = CGPoint(x: size.width * 0.22, y: size.height * 0.30)
        spawnScorePop(at: anchor)
        spawnBurst(at: anchor)
    }

    /// `.score-pop`: 780ms, `--ease-out`, rising ~46pt and fading (mockup:
    /// `translate(-50%,-165%) scale(1.1)`, opacity → 0).
    private func spawnScorePop(at anchor: CGPoint) {
        let pop = ScorePopParticle(anchor: anchor)
        scorePops.append(pop)
        remove(after: 0.85) { scorePops.removeAll { $0.id == pop.id } }
    }

    /// `.bit` burst: 9 pieces, `i % 3 == 0` coin-gold else accent, radial
    /// 26–52pt at a jittered angle, scaling to 0.4 and fading over 560ms.
    private func spawnBurst(at anchor: CGPoint) {
        let count = 9
        for i in 0..<count {
            let angle = (2 * Double.pi * Double(i)) / Double(count) + Double.random(in: 0...0.5)
            let distance = Double.random(in: 26...52)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance - 6
            let bit = BitParticle(anchor: anchor, dx: dx, dy: dy, isCoin: i % 3 == 0)
            bits.append(bit)
            remove(after: 0.62) { bits.removeAll { $0.id == bit.id } }
        }
    }

    // MARK: Confetti (on stage-clear)

    /// `confetti()`: 34 pieces in [accent, coin, accent-2] falling from the
    /// top edge to past the panel bottom with a random rotation, staggered by
    /// a 0–250ms delay, over 1300ms.
    private func fireConfetti(in size: CGSize) {
        let count = 34
        let colors: [ConfettiParticle.ColorRole] = [.accent, .coin, .accentDim]
        let width = max(size.width, 1)
        for i in 0..<count {
            let piece = ConfettiParticle(
                x: CGFloat.random(in: 0...width),
                dx: CGFloat.random(in: -40...40),
                rotation: Double.random(in: -360...360),
                colorRole: colors[i % colors.count],
                delay: Double.random(in: 0...0.25)
            )
            confetti.append(piece)
            remove(after: 1.65) { confetti.removeAll { $0.id == piece.id } }
        }
    }

    /// Schedules `body` on the main queue after `seconds` — the particle's own
    /// CSS-equivalent duration plus slack (mirrors the mockup's `setTimeout`
    /// removal), so array growth is bounded and nothing leaks.
    private func remove(after seconds: Double, _ body: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { body() }
    }
}

// MARK: - Particle models

private struct ScorePopParticle: Identifiable {
    let id = UUID()
    let anchor: CGPoint
}

private struct BitParticle: Identifiable {
    let id = UUID()
    let anchor: CGPoint
    let dx: Double
    let dy: Double
    let isCoin: Bool
}

private struct ConfettiParticle: Identifiable {
    enum ColorRole { case accent, coin, accentDim }
    let id = UUID()
    let x: CGFloat
    let dx: CGFloat
    let rotation: Double
    let colorRole: ColorRole
    let delay: Double
}

// MARK: - Particle views

/// The mockup's `.score-pop`: "+100" in coin-gold Press Start 2P, rising and
/// fading over 780ms `--ease-out`.
private struct ScorePopView: View {
    let anchor: CGPoint
    let palette: Palette

    @State private var animateOut = false

    /// Matches the mockup's `.score-pop{ font-size:12px }` — not one of the
    /// theme's named `TypeScale` roles (those are sized for persistent UI,
    /// not a transient particle), so built inline like `arcadeMiniLabelType`
    /// in `ArcadeStructuralViews.swift`.
    private static let type = TypeToken(size: 12, weight: .regular, fontFamily: .named(FontRegistrar.pressStart2PFamily))

    var body: some View {
        Text("+100")
            .typeToken(Self.type)
            .foregroundStyle(palette.coin)
            .shadow(color: palette.coinGlow, radius: 5)
            .scaleEffect(animateOut ? 1.1 : 1.0)
            .opacity(animateOut ? 0 : 1)
            .position(x: anchor.x, y: animateOut ? anchor.y - 46 : anchor.y)
            .onAppear {
                withAnimation(MotionCurve.easeOut.animation(duration: 0.78)) {
                    animateOut = true
                }
            }
    }
}

/// The mockup's `.bit`: a 6×6 square flying radially outward, scaling down to
/// 0.4 and fading over 560ms `--ease-out`.
private struct BitView: View {
    let bit: BitParticle
    let palette: Palette

    @State private var animateOut = false

    var body: some View {
        Rectangle()
            .fill(bit.isCoin ? palette.coin : palette.accent)
            .frame(width: 6, height: 6)
            .scaleEffect(animateOut ? 0.4 : 1)
            .opacity(animateOut ? 0 : 1)
            .position(
                x: animateOut ? bit.anchor.x + bit.dx : bit.anchor.x,
                y: animateOut ? bit.anchor.y + bit.dy : bit.anchor.y
            )
            .onAppear {
                withAnimation(MotionCurve.easeOut.animation(duration: 0.56)) {
                    animateOut = true
                }
            }
    }
}

/// The mockup's `.confetti`: a 7×7 square falling from the top edge past the
/// panel bottom while rotating, over 1300ms `--ease-out`, staggered by its
/// own random delay.
private struct ConfettiView: View {
    let piece: ConfettiParticle
    let palette: Palette
    /// The y-position past the panel bottom to fall to (`panel.clientHeight + 30`).
    let floor: CGFloat

    @State private var animateOut = false

    private var color: Color {
        switch piece.colorRole {
        case .accent: return palette.accent
        case .coin: return palette.coin
        // JUDGMENT CALL: the mockup's `--accent-2` (a dimmer accent tone used
        // only by confetti) has no dedicated `Palette` field — approximated as
        // `accent` at 70% opacity, mirroring the same call already made for
        // the rail mascot's `accentDim` in `ArcadeStructuralViews.swift`.
        case .accentDim: return palette.accent.opacity(0.7)
        }
    }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 7, height: 7)
            .rotationEffect(.degrees(animateOut ? piece.rotation : 0))
            .opacity(animateOut ? 0 : 1)
            .position(
                x: piece.x + (animateOut ? piece.dx : 0),
                y: animateOut ? floor : -12
            )
            .onAppear {
                withAnimation(MotionCurve.easeOut.animation(duration: 1.3).delay(piece.delay)) {
                    animateOut = true
                }
            }
    }
}
