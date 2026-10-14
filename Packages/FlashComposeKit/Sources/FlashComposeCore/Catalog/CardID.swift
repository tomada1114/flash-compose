/// Why a ``CardID`` could not be made.
///
/// It names the rule that failed and carries nothing of the rejected string, so the error
/// can travel into a log or test output without repeating what it was handed.
public enum CardIDError: Error, Equatable, Sendable {
    /// The string is not `c_` followed by four digit–letter pairs,
    /// `^c_(?:[2-9][a-hjkmnp-z]){4}$`.
    case doesNotMatchFormat
}

/// A card's identity: the key its progress and every answer to it are stored under.
///
/// Card ids are contract (`docs/architecture.md` › Card identity): the learner's progress
/// on the phone is keyed by them, so the format is checked here, once, and every layer
/// above holds a value that already passed. The format alternates a digit and a letter so
/// the repository's spell check never meets a run of letters it could flag, and leaves out
/// `0`, `1`, `i`, `l`, and `o` as too easily confused.
public struct CardID: Hashable, Sendable {
    /// The id exactly as the catalog spells it, such as `c_7k2m9x4q`.
    public let rawValue: String

    /// Creates an id from a string in the catalog's format, `^c_(?:[2-9][a-hjkmnp-z]){4}$`.
    ///
    /// The whole string must match: a trailing newline, a full-width digit, or an
    /// uppercase letter is a different id, not a near miss to tidy up.
    public init(_ rawValue: String) throws(CardIDError) {
        guard rawValue.wholeMatch(of: #/c_(?:[2-9][a-hjkmnp-z]){4}/#) != nil else {
            throw .doesNotMatchFormat
        }
        self.rawValue = rawValue
    }
}
