import FlashComposeCore
import SwiftUI

/// D3, done for today: a calm statement and the day the next review is due. The line
/// about unseen cards outside the scope and the button that changes it are #20's.
struct DoneFace: View {
    let nextReview: LocalizedStringResource?

    var body: some View {
        StatusMessage(
            symbol: "checkmark.circle",
            title: DrillStrings.doneTitle,
            message: nextReview,
        )
        .accessibilityIdentifier("drillDone")
    }
}
