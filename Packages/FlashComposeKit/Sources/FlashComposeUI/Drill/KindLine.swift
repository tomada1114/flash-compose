import FlashComposeCore
import SwiftUI

/// The line above the prompt on D1 and D2 — `復習 · 仕事 · L5` — with a return arrow on a
/// re-ask. The arrow repeats what the word もう一度 says, so VoiceOver skips it.
struct KindLine: View {
    let card: DrillCard

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xSmall) {
            if card.pile == .reAsk {
                Image(systemName: "arrow.uturn.backward")
                    .accessibilityHidden(true)
            }
            Text(card.kindLine)
        }
        .font(.footnote)
        .foregroundStyle(ColorRoles.inkSecondary)
    }
}
