/// The drill's start-up reads (`docs/architecture.md` › Core flows, Cold launch): the
/// catalog decode and the progress fetch, made at the same time off the main actor, so
/// the first card waits on the slower of the two rather than on both in turn.
enum DrillStartup {
    /// What both reads returned.
    struct Loaded: Sendable {
        let catalog: CardCatalog
        let progress: [CardProgress]
    }

    /// Which read failed; logged by case, never shown — either one is E1.
    enum Failure: Error {
        case catalog(CatalogError)
        case progress(ProgressStoreError)
    }

    /// Decodes the catalog with `load` and loads every progress row from `store`,
    /// concurrently; the catalog's failure is reported when both fail.
    @concurrent
    static func read(
        catalog load: @escaping @Sendable () async throws(CatalogError) -> CardCatalog,
        store: any ProgressStore,
    ) async -> Result<Loaded, Failure> {
        async let catalog = catalogResult(load)
        async let progress = progressResult(store)
        switch await (catalog, progress) {
        case let (.success(cards), .success(rows)):
            return .success(Loaded(catalog: cards, progress: rows))

        case let (.failure(error), _):
            return .failure(.catalog(error))

        case let (_, .failure(error)):
            return .failure(.progress(error))
        }
    }

    private static func catalogResult(
        _ load: @Sendable () async throws(CatalogError) -> CardCatalog,
    ) async -> Result<CardCatalog, CatalogError> {
        do {
            return try await .success(load())
        } catch {
            return .failure(error)
        }
    }

    private static func progressResult(
        _ store: any ProgressStore,
    ) async -> Result<[CardProgress], ProgressStoreError> {
        do {
            return try await .success(store.loadProgress())
        } catch {
            return .failure(error)
        }
    }
}
