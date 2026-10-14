import FlashComposeCore
import Testing

/// The scope over the shipped catalog (`docs/product/requirements.md` §3.5).
@Suite("Scope over the shipped catalog")
struct ScopeRealCatalogTests {
    static let catalogSize = 1_952
    static let travelLevelOneCount = 33

    @Test
    func `the shipped catalog builds the scope's topics and levels`() async throws {
        let scope = try await ScopeCatalog(CatalogLoader.load())
        #expect(scope.topics.map(\.name) == ["日常", "雑談・人付き合い", "仕事", "旅行", "IT・技術"])
        #expect(scope.levels.first?.toeicLabel == "TOEIC 300")
        #expect(scope.levels.last?.toeicLabel == "TOEIC 990+")
        #expect(scope.levelValues == Level.allCases)
    }

    @Test
    func `travel L1 holds 33 never-seen cards and leaves 1,919 outside`() async throws {
        let scope = try await ScopeCatalog(CatalogLoader.load())
        let lowest = try Level(1)
        let selection = ScopeSelection(
            topicsOff: Set(scope.topicIDs.filter { $0 != TopicID("travel") }),
            levelsOff: Set(scope.levelValues.filter { $0 != lowest }),
        )
        let narrowed = scope.neverSeenCounts(in: selection, seenCardIDs: [])
        #expect(narrowed == NeverSeenCounts(
            inScope: Self.travelLevelOneCount,
            outsideScope: Self.catalogSize - Self.travelLevelOneCount,
        ))
        let everything = scope.neverSeenCounts(in: ScopeSelection(), seenCardIDs: [])
        #expect(everything == NeverSeenCounts(inScope: Self.catalogSize, outsideScope: 0))
    }
}
