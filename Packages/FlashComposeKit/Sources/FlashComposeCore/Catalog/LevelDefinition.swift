/// A level as `levels.json` defines it: the rough exam scores the scope screen shows as a
/// hint, and a one-line Japanese summary.
///
/// The scores are strings because the file spells them as ranges and bounds (`990+`,
/// `B1-`), which a number would lose.
public struct LevelDefinition: Hashable, Sendable {
    /// The level this entry describes.
    public let level: Level
    /// A rough TOEIC score, such as `730`.
    public let toeic: String
    /// A rough CEFR level, such as `B1+`.
    public let cefr: String
    /// What the level asks of the learner, in Japanese.
    public let summary: String

    /// Creates a level entry from `levels.json`, or a hand-built one for a test or
    /// preview.
    public init(level: Level, toeic: String, cefr: String, summary: String) {
        self.level = level
        self.toeic = toeic
        self.cefr = cefr
        self.summary = summary
    }
}
