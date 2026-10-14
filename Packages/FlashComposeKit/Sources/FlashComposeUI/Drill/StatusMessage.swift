import FlashComposeCore
import SwiftUI

/// A large hierarchical symbol, a title, and an optional line under it, centred: the
/// shape D3 and E1 share.
struct StatusMessage: View {
    let symbol: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.largeTitle)
                .imageScale(.large)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
            if let message {
                Text(message)
                    .font(.body)
                    .foregroundStyle(ColorRoles.inkSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(DesignTokens.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
