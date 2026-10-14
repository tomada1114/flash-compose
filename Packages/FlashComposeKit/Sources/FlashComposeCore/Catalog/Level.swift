/// Why a ``Level`` could not be made.
///
/// It names the rule that failed and carries nothing of the rejected number.
public enum LevelError: Error, Equatable, Sendable {
    /// The number is outside ``Level/range``.
    case outOfRange
}

/// A card's difficulty, from 1 to 10 (`docs/product/requirements.md` §3.1).
///
/// A type rather than a bare `Int` so the range is checked once, where a level enters
/// Core, and the scope screen and the catalog's integrity test can rely on it.
public struct Level: Hashable, Comparable, Sendable, CaseIterable {
    /// The levels the catalog defines.
    public static let range = 1 ... 10

    /// Every level, lowest first: what the scope screen lists, whether or not the
    /// catalog has a card at it.
    public static let allCases = range.map(Self.init(validated:))

    /// The level's number, from 1 to 10.
    public let rawValue: Int

    /// Creates a level from a number in ``range``.
    public init(_ rawValue: Int) throws(LevelError) {
        guard Self.range.contains(rawValue) else {
            throw .outOfRange
        }
        self.init(validated: rawValue)
    }

    private init(validated rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Lower levels first, so a sorted list reads from easiest to hardest.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
