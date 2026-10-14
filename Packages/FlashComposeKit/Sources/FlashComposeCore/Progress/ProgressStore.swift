/// Everything a ``ProgressStore`` can report, in Core's vocabulary.
///
/// No case carries a payload: the drill does the same thing whichever card a failure
/// touched, and a stored row the store cannot read back may not even hold a valid card id.
/// The detail stays in the adapter's log.
public enum ProgressStoreError: Error, Equatable, Sendable {
    /// A stored row no longer makes a Core value — a card id, a practice day, a grade, or
    /// an answer kind the store cannot read back. An adapter uses it for the one row it
    /// cannot translate; ``ProgressStore/loadProgress()`` leaves such a row out rather
    /// than reporting it, so one damaged row never costs the learner every other card.
    case corruptedRecord
    /// The store is open, but a read or a save did not happen.
    case storageFailure
    /// There is no store: the container could not be opened at launch, and
    /// ``UnavailableProgressStore`` stands in for it.
    case unavailable
}

/// A port: where the learner's progress and the answer log are kept
/// (`docs/architecture.md` › Progress store).
///
/// Core declares it; `FlashComposePlatform` holds the SwiftData adapter
/// (`SwiftDataProgressStore`) over the app's one container; `FlashComposeTestSupport`
/// holds the in-memory fake every Core test uses; and `App/` decides which one the drill
/// gets. The same shape as ``TodoRepository`` (`docs/architecture.md` › Repositories):
/// `Sendable`, value types only across it, every method `async` because an
/// implementation is an actor, and every method throwing ``ProgressStoreError`` and
/// nothing else, so a caller handles a closed set of cases and never learns which store
/// failed.
///
/// It has no way to read the answer log back: nothing in this version does, and the log
/// is kept only because it cannot be rebuilt later (``Answer``).
///
/// `ProgressStoreContract` in `FlashComposeTestSupport` checks the promises below against
/// the fake and against the SwiftData adapter, both under `just test`; a new promise is
/// stated here first, then added there.
public protocol ProgressStore: Sendable {
    /// Every stored ``CardProgress``, in no particular order: exactly one per card that
    /// has ever been recorded, including cards the catalog no longer has, and none for a
    /// card never recorded. An empty store — a first launch — returns an empty array.
    ///
    /// A stored row the store cannot read back is left out and logged, and the load still
    /// succeeds: that card reads as never recorded, so it comes back as a new card, and
    /// every other card keeps its schedule. The row is not removed; the card's next
    /// ``record(answer:progress:)`` replaces it. The load throws only when the store as a
    /// whole cannot be read.
    func loadProgress() async throws(ProgressStoreError) -> [CardProgress]

    /// Appends `answer` to the log and replaces the progress stored for
    /// `progress.cardID` with `progress`, in one save: after it returns both are stored,
    /// and after it throws neither is, nor will a later save write them.
    ///
    /// Every answer is appended — a re-ask included — and none is ever edited or
    /// removed. The store decides nothing about the grade: whether the progress moved is
    /// the caller's decision, so a re-ask passes the card's unchanged progress, and
    /// `progress` is expected to be the progress of `answer.cardID`.
    func record(answer: Answer, progress: CardProgress) async throws(ProgressStoreError)
}
