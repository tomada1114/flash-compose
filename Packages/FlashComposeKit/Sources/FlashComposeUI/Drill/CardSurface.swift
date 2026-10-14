import SwiftUI

/// The card's surface: `secondarySystemBackground` in `Radius.large`.
struct CardSurface: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
            .fill(ColorRoles.card)
    }
}
