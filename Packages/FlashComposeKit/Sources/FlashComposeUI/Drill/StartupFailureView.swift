import FlashComposeCore
import SwiftUI

/// E1: the cards or the progress could not be opened. 再試行, below it, repeats the
/// start-up.
struct StartupFailureView: View {
    var body: some View {
        StatusMessage(
            symbol: "exclamationmark.triangle",
            title: DrillStrings.startFailureTitle,
            message: DrillStrings.startFailureMessage,
        )
        .accessibilityIdentifier("drillStartFailure")
    }
}
