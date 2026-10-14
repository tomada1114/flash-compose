#if DEBUG
    /// A ``ProgressStore`` over another one that fails every
    /// ``ProgressStore/record(answer:progress:)`` with ``ProgressStoreError/storageFailure``
    /// and lets the load through.
    ///
    /// Debug-only fault injection, so a failed save (E2) can be seen in the running app:
    /// the composition root wraps the real store in it under the `-failRecords` launch
    /// argument (`App/FlashComposeApp.swift`), and `LaunchUITests` launches with it to prove
    /// the alert presents and leaves D2 on the same card. The load still succeeds, so the
    /// drill reaches D2 first. A Release build compiles neither this type nor the argument.
    public struct RecordFailingProgressStore: ProgressStore {
        private let base: any ProgressStore

        /// Creates the store over `base`, which answers every load.
        public init(wrapping base: any ProgressStore) {
            self.base = base
        }

        public func loadProgress() async throws(ProgressStoreError) -> [CardProgress] {
            try await base.loadProgress()
        }

        /// Throws ``ProgressStoreError/storageFailure`` and stores nothing.
        public func record(
            answer _: Answer,
            progress _: CardProgress,
        ) throws(ProgressStoreError) {
            throw .storageFailure
        }
    }
#endif
