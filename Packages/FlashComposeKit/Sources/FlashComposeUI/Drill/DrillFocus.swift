import FlashComposeCore

/// Where VoiceOver focus moves as the drill changes face (`docs/design/ux-guidelines.md` ›
/// Accessibility targets): to the model answer after the reveal, and to the new card's
/// prompt after a grade.
enum DrillFocus: Hashable {
    /// The model answer on D2.
    case answer
    /// The prompt on D1.
    case prompt

    /// The focus a move from `old` to `new` calls for, or `nil` to leave it where it is —
    /// as on the first card, where VoiceOver starts at the counts.
    static func after(_ old: DrillViewModel.Face?, _ new: DrillViewModel.Face?) -> Self? {
        switch new {
        case .answer:
            old == .question ? .answer : nil

        case .question:
            old == .answer ? .prompt : nil

        case .done, nil:
            nil
        }
    }
}
