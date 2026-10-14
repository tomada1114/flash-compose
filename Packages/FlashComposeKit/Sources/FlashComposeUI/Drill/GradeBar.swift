import FlashComposeCore
import SwiftUI

/// One grade button: its glyph, its word, and the interval it would set, if any. Its
/// accessible name is Core's — the grade and the interval, or the grade alone.
private struct GradeButton: View {
    private enum Layout {
        /// The lock's height for a grade button at the default text size.
        static let minimumHeight: CGFloat = 64
        /// The ○ button's edge stroke.
        static let edgeWidth: CGFloat = 1
        /// The square every grade glyph sits in at the default text size, so ×, △, and ○
        /// — drawn at different sizes — leave their words on one line across the bar.
        static let glyphSide: CGFloat = 28
    }

    let option: GradeOption
    let isStacked: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title3)
    private var glyphSide = Layout.glyphSide

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(style.content)
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .padding(.vertical, DesignTokens.Spacing.small)
                .frame(maxWidth: .infinity, minHeight: Layout.minimumHeight, maxHeight: .infinity)
                .background(style.fill, in: shape)
                .overlay { shape.strokeBorder(style.edge, lineWidth: Layout.edgeWidth) }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.accessibilityLabel))
        .accessibilityIdentifier("grade-\(option.grade)")
    }

    @ViewBuilder private var label: some View {
        if isStacked {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.medium) {
                glyph
                title
                Spacer(minLength: DesignTokens.Spacing.small)
                interval
            }
        } else {
            VStack(spacing: DesignTokens.Spacing.xxSmall) {
                glyph
                title
                interval
            }
            .multilineTextAlignment(.center)
        }
    }

    private var glyph: some View {
        Image(systemName: style.symbol)
            .font(.title3)
            .frame(width: glyphSide, height: glyphSide)
            .accessibilityHidden(true)
    }

    private var title: some View {
        Text(option.title)
            .font(.subheadline.weight(.semibold))
    }

    @ViewBuilder private var interval: some View {
        if let intervalText = option.intervalLabel {
            Text(intervalText)
                .font(.caption)
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(style.secondary)
        }
    }

    private var style: GradeStyle {
        GradeStyle.of(option.grade)
    }
}

/// How the lock draws each grade: its symbol, fill, edge, and text colours. × and △ are
/// neutral, the same grey; only ○ has a colour, and a miss is never red.
private struct GradeStyle {
    let symbol: String
    let fill: Color
    let edge: Color
    let content: Color
    let secondary: Color

    /// The style of `grade`'s button.
    static func of(_ grade: Grade) -> Self {
        switch grade {
        case .again:
            neutral(symbol: "xmark")

        case .hard:
            neutral(symbol: "triangle")

        case .good:
            Self(
                symbol: "circle",
                fill: ColorRoles.good,
                edge: ColorRoles.goodEdge,
                content: ColorRoles.onGood,
                secondary: ColorRoles.onGood,
            )
        }
    }

    private static func neutral(symbol: String) -> Self {
        Self(
            symbol: symbol,
            fill: ColorRoles.neutralGrade,
            edge: .clear,
            content: .primary,
            secondary: ColorRoles.inkSecondary,
        )
    }
}

/// D2's three grade buttons, × left and ○ right: side by side at the default text size,
/// stacked one per row, in the same order, at accessibility sizes.
struct GradeBar: View {
    let options: [GradeOption]
    let grade: (Grade) -> Void

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    var body: some View {
        // Each stack takes its ideal height, so the three buttons side by side share the
        // tallest one's height and the bar never grows past its content.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: DesignTokens.Spacing.small) { buttons(isStacked: true) }
                .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(spacing: DesignTokens.Spacing.small) { buttons(isStacked: false) }
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func buttons(isStacked: Bool) -> some View {
        ForEach(options) { option in
            GradeButton(option: option, isStacked: isStacked) { grade(option.grade) }
        }
    }
}
