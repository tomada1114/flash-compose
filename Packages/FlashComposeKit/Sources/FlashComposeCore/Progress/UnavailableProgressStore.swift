/// A ``ProgressStore`` that has no store: every call throws
/// ``ProgressStoreError/unavailable``.
///
/// The composition root's answer when the app's container cannot be opened, as
/// ``UnavailableTodoRepository`` is for the to-do list (`docs/architecture.md` ›
/// Repositories). Crashing on launch, or silently falling back to an in-memory store
/// whose grades vanish on the next launch, are both worse: with this, the drill reports
/// the failure and nothing pretends to have been saved.
///
/// Its methods are synchronous: a synchronous throwing method satisfies the port's
/// `async` requirement, and there is nothing here to wait for.
public struct UnavailableProgressStore: ProgressStore {
    public init() {
        // Stateless: there is nothing to hold.
    }

    public func loadProgress() throws(ProgressStoreError) -> [CardProgress] {
        throw .unavailable
    }

    public func record(answer _: Answer, progress _: CardProgress) throws(ProgressStoreError) {
        throw .unavailable
    }
}
