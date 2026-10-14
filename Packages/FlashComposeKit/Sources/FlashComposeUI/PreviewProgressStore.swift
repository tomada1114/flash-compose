#if DEBUG
    import FlashComposeCore

    /// A preview-only progress store, so a drill `#Preview` can grade cards without
    /// SwiftData — or fail every grade, to show E2.
    ///
    /// `FlashComposeTestSupport`'s fake is test code no shipped module may import, and the
    /// SwiftData adapter lives in `FlashComposePlatform`, which `FlashComposeUI` must not
    /// see — hence this small copy, compiled into Debug builds only.
    actor PreviewProgressStore: ProgressStore {
        private var progress: [CardID: CardProgress] = [:]
        private let failsRecords: Bool

        /// Starts empty; every grade saves.
        init() {
            self.init(failsRecords: false)
        }

        /// Starts empty; every grade saves, or — with `failsRecords` — none does.
        init(failsRecords: Bool) {
            self.failsRecords = failsRecords
        }

        func loadProgress() -> [CardProgress] {
            Array(progress.values)
        }

        func record(answer _: Answer, progress recorded: CardProgress) throws(ProgressStoreError) {
            if failsRecords {
                throw .storageFailure
            }
            progress[recorded.cardID] = recorded
        }
    }
#endif
