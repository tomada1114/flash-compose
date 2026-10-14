import Foundation

/// A failure the drill reports while it runs (E2), presented by the root's one failure
/// alert. Which store failed, and why, stays in the log; the start-up failure (E1) is a
/// phase of its own, ``DrillViewModel/Phase/failed``, not an alert.
public enum DrillFailure: Equatable, PresentableFailure {
    /// A grade could not be saved: nothing was recorded, and the card is still on screen.
    case saveFailed

    /// The alert's headline.
    public var title: LocalizedStringResource {
        switch self {
        case .saveFailed:
            LocalizedStringResource(
                "drill.failure.save.title",
                defaultValue: "Couldn't save your answer",
                bundle: .module,
                comment: "Title of the alert shown when a grade could not be saved.",
            )
        }
    }

    /// What the learner does next: the grade was not kept, so they tap it again.
    public var message: LocalizedStringResource {
        switch self {
        case .saveFailed:
            LocalizedStringResource(
                "drill.failure.save.message",
                defaultValue: "Tap a grade again",
                bundle: .module,
                comment: "Message of the alert shown when a grade could not be saved.",
            )
        }
    }
}
