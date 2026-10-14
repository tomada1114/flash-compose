import FlashComposeCore
import SwiftUI

/// The drill header (`docs/product/ux-flows.md` §2): 新規 › 復習 › もう一度 with the card on
/// screen's pile underlined, read by VoiceOver as Core's one sentence.
///
/// One row while it fits; at accessibility sizes, one count per line, so no number is
/// ever truncated.
struct DrillHeaderView: View {
    /// The separator between counts, a typographic mark rather than wording.
    private enum Glyph {
        static let separator = "\u{203A}"
    }

    let header: DrillHeader

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
                ForEach(header.items) { item in
                    if item.pile != header.items.first?.pile {
                        Text(verbatim: Glyph.separator)
                            .foregroundStyle(ColorRoles.inkSecondary)
                    }
                    count(item)
                }
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xSmall) {
                ForEach(header.items) { item in
                    count(item)
                }
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(header.accessibilityLabel))
        .accessibilityIdentifier("drillHeader")
    }

    private func count(_ item: DrillHeaderItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xSmall) {
            Text(item.title)
                .foregroundStyle(ColorRoles.inkSecondary)
            Text(verbatim: item.count)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .underline(item.isCurrent, color: .accentColor)
                .contentTransition(.numericText())
        }
        .fixedSize()
    }
}
