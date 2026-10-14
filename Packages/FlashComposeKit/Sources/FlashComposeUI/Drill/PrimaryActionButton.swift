import SwiftUI

/// The one primary action of a drill screen — 答えを見る on D1, 再試行 on E1 — as the
/// design lock draws it: `.headline`, white on `Action`, `Radius.medium`, at least 50 pt
/// tall and growing with the text.
struct PrimaryActionButton: View {
    private enum Layout {
        /// The lock's height for the reveal and primary buttons at the default text size.
        static let minimumHeight: CGFloat = 50
    }

    let title: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Spacing.large)
                .padding(.vertical, DesignTokens.Spacing.small)
                .frame(maxWidth: .infinity, minHeight: Layout.minimumHeight)
                .background(
                    ColorRoles.action,
                    in: RoundedRectangle(
                        cornerRadius: DesignTokens.Radius.medium,
                        style: .continuous,
                    ),
                )
                .contentShape(RoundedRectangle(
                    cornerRadius: DesignTokens.Radius.medium,
                    style: .continuous,
                ))
        }
        .buttonStyle(.plain)
    }
}
