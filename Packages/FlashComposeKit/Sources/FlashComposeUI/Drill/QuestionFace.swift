import FlashComposeCore
import SwiftUI

/// D1, the question face: the kind line and the Japanese prompt on the card. A tap
/// anywhere on the card reveals the answer, as the button below it does.
struct QuestionFace: View {
    let card: DrillCard
    let reveal: () -> Void
    let focus: AccessibilityFocusState<DrillFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            KindLine(card: card)
            Spacer(minLength: 0)
            // Card content is data: shown verbatim, never looked up in a catalog.
            Text(verbatim: card.card.japanese)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityFocused(focus, equals: .prompt)
                .accessibilityIdentifier("drillPrompt")
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Taps fall through the text to the card behind it, which is the reveal.
        .allowsHitTesting(false)
        .background {
            // A button rather than a tap gesture, so the whole card is one hit region
            // and the gesture has a button's trait; VoiceOver reaches 答えを見る instead.
            Button(action: reveal) {
                CardSurface()
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
    }
}
