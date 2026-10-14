#if DEBUG
    import FlashComposeCore
    import SwiftUI

    /// One drill state for a `#Preview`: the bundled catalog cut down to one card, driven
    /// through real view-model actions — so every count, kind, interval, and underline is
    /// Core's, never a value written for the preview.
    ///
    /// One card is enough for every face: a new card's first ○ asks it again at once when
    /// no other card waits, and that re-ask's ○ ends the day.
    private struct DrillPreview: View {
        /// A step the preview takes once the drill has started.
        enum Step {
            case reveal
            case grade(Grade)
        }

        /// `docs/product/ux-flows.md`'s example card (仕事, L5).
        static let sampleCard = "c_2t5h9y9g"
        /// The longest card in the set (L10): the layout's stress case.
        static let longestCard = "c_4m6f2p9m"

        let steps: [Step]
        @State private var model: DrillViewModel
        @State private var startup: StartupIndicator

        var body: some View {
            NavigationStack {
                DrillView(model: model, startup: startup)
            }
            .failureAlert(model.failure) { model.dismissFailure() }
            .task {
                // DrillView starts the drill too; the newest start-up wins, so start again
                // if this one was the one dropped.
                await model.start()
                if model.phase == .starting {
                    await model.start()
                }
                for step in steps {
                    switch step {
                    case .reveal:
                        model.reveal()

                    case let .grade(grade):
                        await model.grade(grade)
                    }
                }
            }
        }

        init(
            card: String = sampleCard,
            store: any ProgressStore = PreviewProgressStore(),
            steps: [Step] = [],
        ) {
            self.steps = steps
            var environment = DrillEnvironment()
            environment.loadCatalog = { () async throws(CatalogError) -> CardCatalog in
                try await Self.catalog(only: card)
            }
            let drill = DrillViewModel(
                store: store,
                scope: ScopeViewModel(preferences: PreviewPreferences(), locale: .current),
                environment: environment,
            )
            _model = State(initialValue: drill)
            _startup = State(initialValue: StartupIndicator(drill: drill))
        }

        /// The bundled catalog with only the card `id` names.
        @concurrent
        private static func catalog(only id: String) async throws(CatalogError) -> CardCatalog {
            let full = try await CatalogLoader.load()
            return CardCatalog(
                cards: full.cards.filter { $0.id.rawValue == id },
                topics: full.topics,
                levels: full.levels,
                grammarTags: full.grammarTags,
                retiredIDs: full.retiredIDs,
            )
        }
    }

    #Preview("D1 new") {
        DrillPreview()
    }

    #Preview("D1 re-ask") {
        DrillPreview(steps: [.reveal, .grade(.good)])
    }

    #Preview("D2 with intervals") {
        DrillPreview(steps: [.reveal])
    }

    #Preview("D2 dark") {
        DrillPreview(steps: [.reveal])
            .preferredColorScheme(.dark)
    }

    #Preview("D2 re-ask") {
        DrillPreview(steps: [.reveal, .grade(.good), .reveal])
    }

    #Preview("D2 longest card") {
        DrillPreview(card: DrillPreview.longestCard, steps: [.reveal])
    }

    #Preview("D2 longest card, AX5") {
        DrillPreview(card: DrillPreview.longestCard, steps: [.reveal])
            .dynamicTypeSize(.accessibility5)
    }

    #Preview("D2 save failed (E2)") {
        DrillPreview(
            store: PreviewProgressStore(failsRecords: true),
            steps: [.reveal, .grade(.good)],
        )
    }

    #Preview("D3") {
        DrillPreview(steps: [.reveal, .grade(.good), .reveal, .grade(.good)])
    }

    #Preview("E1") {
        DrillPreview(store: UnavailableProgressStore())
    }
#endif
