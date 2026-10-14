/// The learner's own verdict on a card: × forgot, △ unsure, or ○ remembered.
///
/// Each raw value is the rating FSRS-6 schedules with, so the scheduler reads it directly.
/// There is no easy (4): the drill offers three grades, and an easy case would be one the
/// scheduler must handle but the learner can never choose. Cases are declared
/// alphabetically, as the lint requires, so ``allCases`` is not in rating order; a view
/// that lists the grades names them in the order it shows them.
public enum Grade: Int, Sendable, CaseIterable {
    /// × forgot: the learner could not produce the English.
    case again = 1
    /// ○ remembered: the learner produced it.
    case good = 3
    /// △ unsure: the learner produced it with effort or only in part.
    case hard = 2
}
