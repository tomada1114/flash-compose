import FlashComposeCore
import SwiftUI

/// D2, the answer face: the prompt again, small, then the model answer, the alternatives,
/// and the point. The card scrolls when its text outgrows it, so the grade buttons below
/// stay pinned.
struct AnswerFace: View {
    let card: DrillCard
    let focus: AccessibilityFocusState<DrillFocus?>.Binding

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                KindLine(card: card)
                Text(verbatim: card.card.japanese)
                    .font(.body)
                    .foregroundStyle(ColorRoles.inkSecondary)
                Divider()
                Text(verbatim: card.card.english)
                    .font(.title3.weight(.semibold))
                    .accessibilityFocused(focus, equals: .answer)
                    .accessibilityIdentifier("modelAnswer")
                alternatives
                point
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.large)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background { CardSurface() }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
    }

    private var alternatives: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
            Text(DrillStrings.alternatives)
                .font(.footnote)
                .foregroundStyle(ColorRoles.inkSecondary)
            ForEach(Array(card.card.alternatives.enumerated()), id: \.offset) { _, alternative in
                Text(verbatim: alternative)
                    .font(.body)
                    .foregroundStyle(ColorRoles.inkSecondary)
            }
        }
        .padding(.top, DesignTokens.Spacing.xSmall)
    }

    private var point: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
            Image(systemName: "lightbulb")
                .accessibilityHidden(true)
            Text(verbatim: card.card.point)
        }
        .font(.callout)
        .foregroundStyle(.primary)
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ColorRoles.pointBox,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous),
        )
        .padding(.top, DesignTokens.Spacing.xSmall)
    }
}
