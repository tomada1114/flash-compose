import FlashComposeCore
import Foundation
import Testing

/// The subset of the String Catalog format these tests read: its source language and,
/// per key, each language's single string. A plural or device-varied entry has
/// `variations` instead of a `stringUnit`.
private struct StringCatalog: Decodable {
    let sourceLanguage: String
    let strings: [String: CatalogEntry]
}

/// One key's entry. An entry keyed by its own English text may carry no `localizations`
/// at all, which decodes as none rather than failing the whole catalog.
private struct CatalogEntry: Decodable {
    private enum CodingKeys: String, CodingKey {
        case localizations
    }

    let localizations: [String: CatalogLocalization]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localizations = try container.decodeIfPresent(
            [String: CatalogLocalization].self,
            forKey: .localizations,
        ) ?? [:]
    }
}

private struct CatalogLocalization: Decodable {
    struct StringUnit: Decodable {
        let state: String?
        let value: String
    }

    let stringUnit: StringUnit?
}

/// The String Catalog plumbing (`Sources/FlashComposeCore/Resources/Localizable.xcstrings`).
///
/// `swift test` builds with SwiftPM's native build system, which copies the catalog into
/// Core's resource bundle uncompiled, so every English string here comes from a
/// resource's `defaultValue`; only `xcodebuild` compiles the catalog into the app. These
/// tests therefore read the sources and the catalog as text and hold them together:
/// every `LocalizedStringResource(…)` call in `Sources/FlashComposeCore` declares an explicit
/// key, a `defaultValue`, and `bundle: .module`; the keys those calls declare are exactly
/// the catalog's and exactly ``everyCase()``'s; and the catalog's English is what Core
/// renders. Without them, a key missing from the catalog still reads correctly in
/// English and simply never translates. A resource made from a bare string literal is
/// outside what the scan sees (``ResourceDeclarationScan``).
@MainActor
@Suite("Localization")
struct LocalizationTests {
    /// A resource Core returns, and the arguments its English format takes — a `String`
    /// for `%@`, an `Int` for `%lld`.
    struct Case {
        let resource: LocalizedStringResource
        let arguments: [any CVarArg]
    }

    /// `Sources/FlashComposeCore`, resolved from this file's path.
    static let coreSources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/FlashComposeCore")

    /// The Japanese the scope sheet ships, held to the catalog's source: `swift test` never
    /// compiles the catalog, so resolving a resource in `ja` would only return English.
    static let scopeJapanese = [
        "scope.title": "出題範囲",
        "scope.done": "完了",
        "scope.note.newCards": "新規カードの出題範囲。",
        "scope.note.reviews": "復習は範囲に関係なく出題。",
        "scope.topics": "トピック",
        "scope.levels": "レベル",
        "scope.pickAtLeastOne": "1つ以上を選択",
        "scope.unseenCount": "この範囲の未出題：%@枚",
        "scope.allShown": "この範囲は全カード出題済み",
    ]

    /// The Japanese the drill ships, held to the catalog's source as ``scopeJapanese`` is,
    /// in the glossary's words and terse register (`docs/design/ux-guidelines.md`).
    static let drillJapanese = [
        "drill.kind.new": "新規",
        "drill.kind.review": "復習",
        "drill.kind.reAsk": "もう一度",
        "drill.card.kindLine": "%@ · %@ · L%lld",
        "drill.showAnswer": "答えを見る",
        "drill.alternatives": "別解",
        "drill.grade.again": "忘れた",
        "drill.grade.hard": "微妙",
        "drill.grade.good": "覚えてた",
        "drill.grade.spoken": "%@、次回%@後",
        "drill.interval.oneDay": "1日",
        "drill.interval.days": "%lld日",
        "drill.interval.months": "約%lldか月",
        "drill.interval.oneYear": "約1年",
        "drill.header.spoken.new": "新規 %@、復習 %@、もう一度 %@。このカードは新規",
        "drill.header.spoken.review": "新規 %@、復習 %@、もう一度 %@。このカードは復習",
        "drill.header.spoken.reAsk": "新規 %@、復習 %@、もう一度 %@。このカードはもう一度",
        "drill.header.spoken.none": "新規 %@、復習 %@、もう一度 %@",
        "drill.done.title": "今日の分は完了",
        "drill.done.nextReview": "次の復習：%@",
        "drill.done.outsideScope": "範囲外の未出題カード：%@枚",
        "drill.done.changeScope": "範囲を変える…",
        "drill.startFailure.title": "データを開けません",
        "drill.startFailure.message": "カードまたは学習記録の読み込みに失敗",
        "drill.startFailure.retry": "再試行",
        "drill.failure.save.title": "回答の保存に失敗",
        "drill.failure.save.message": "もう一度評価をタップ",
    ]

    /// Every resource Core returns, once per state that picks a different key, with the
    /// arguments its English takes. Adding a key to Core means adding it here: the
    /// source-scan tests fail until this list names every key Core's sources declare.
    static func everyCase() -> [Case] {
        let strings: [LocalizedStringResource] = [
            FailureStrings.dismiss,
            ScopeStrings.title, ScopeStrings.done, ScopeStrings.noteNewCards,
            ScopeStrings.noteReviews, ScopeStrings.topicsHeader, ScopeStrings.levelsHeader,
            ScopeStrings.pickAtLeastOne, ScopeStrings.allShown,
        ]
        return strings.map { Case(resource: $0, arguments: []) }
            + [Case(resource: ScopeStrings.unseenCount("1,402"), arguments: ["1,402"])]
            + drillCases()
    }

    /// The drill's resources (``DrillStrings``, ``IntervalLabel``, ``DrillFailure``), once
    /// per key, with the English each argument renders as.
    static func drillCases() -> [Case] {
        let plain: [LocalizedStringResource] = [
            DrillStrings.showAnswer, DrillStrings.alternatives, DrillStrings.doneTitle,
            DrillStrings.changeScope, DrillStrings.startFailureTitle,
            DrillStrings.startFailureMessage, DrillStrings.retry,
            DrillFailure.saveFailed.title, DrillFailure.saveFailed.message,
            IntervalLabel.days(1).text, IntervalLabel.year.text,
        ]
            + DrillPile.allCases.map(DrillStrings.kind)
            + Grade.allCases.map(DrillStrings.grade)
        let counts = ["1,820", "12", "0"]
        let headers = ([nil] + DrillPile.allCases.map(Optional.some)).map { pile in
            Case(
                resource: DrillStrings.header(
                    new: counts[0],
                    review: counts[1],
                    reAsk: counts[2],
                    pile: pile,
                ),
                arguments: counts,
            )
        }
        return plain.map { Case(resource: $0, arguments: []) } + headers + [
            Case(
                resource: DrillStrings.kindLine(
                    kind: DrillStrings.kind(.review),
                    topic: "仕事",
                    level: 5,
                ),
                arguments: ["Review", "仕事", 5],
            ),
            Case(
                resource: DrillStrings.gradeWithInterval(
                    DrillStrings.grade(.again),
                    interval: IntervalLabel.days(1).text,
                ),
                arguments: ["Forgot", "1 day"],
            ),
            Case(resource: IntervalLabel.days(29).text, arguments: [29]),
            Case(resource: IntervalLabel.months(2).text, arguments: [2]),
            Case(resource: DrillStrings.nextReview("Thu, Oct 15"), arguments: ["Thu, Oct 15"]),
            Case(resource: DrillStrings.outsideScope("1,402"), arguments: ["1,402"]),
        ]
    }

    /// `Sources/FlashComposeCore/Resources/Localizable.xcstrings`.
    private static func catalog() throws -> StringCatalog {
        let url = coreSources.appending(path: "Resources/Localizable.xcstrings")
        return try JSONDecoder().decode(StringCatalog.self, from: Data(contentsOf: url))
    }

    /// The keys the `LocalizedStringResource(…)` calls in Core's sources declare.
    static func declaredKeys() throws -> Set<String> {
        try Set(ResourceDeclarationScan.declarations(inSourcesAt: coreSources).compactMap(\.key))
    }

    /// The format specifiers in `format`, in order (`%@`, `%lld`, `%1$@`, …), so a
    /// translation that drops or retypes an argument fails rather than crashing at runtime.
    static func formatSpecifiers(in format: String) -> [String] {
        let pattern = /%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?[@dDiuUxXoOfeEgGcCsSp%]/
        return format.matches(of: pattern).map { String(format[$0.range]) }.filter { $0 != "%%" }
    }

    @Test
    func `every resource is looked up in Core's resource bundle, not the main bundle`() {
        for testCase in Self.everyCase() {
            let resource = testCase.resource
            guard case let .atURL(url) = resource.bundle else {
                Issue.record("\(resource.key) is not looked up in Core's bundle")
                continue
            }
            #expect(url.pathExtension == "bundle", "\(resource.key)")
            #expect(url != Bundle.main.bundleURL, "\(resource.key)")
        }
    }

    @Test
    func `every resource Core's sources declare has a key, a defaultValue, and bundle module`(
    ) throws {
        let declarations = try ResourceDeclarationScan.declarations(inSourcesAt: Self.coreSources)
        #expect(!declarations.isEmpty, "the scan found no LocalizedStringResource call")
        for declaration in declarations {
            #expect(
                declaration.followsTheConvention,
                "\(declaration.file): LocalizedStringResource(\(declaration.arguments.prefix(60))…)",
            )
        }
    }

    @Test
    func `the catalog holds exactly the keys Core's sources declare`() throws {
        let declared = try Self.declaredKeys()
        let catalogued = try Set(Self.catalog().strings.keys)
        #expect(declared.subtracting(catalogued).isEmpty, "missing from Localizable.xcstrings")
        #expect(
            catalogued.subtracting(declared).isEmpty,
            "in Localizable.xcstrings but declared nowhere",
        )
    }

    @Test
    func `every key Core's sources declare has a case here`() throws {
        let declared = try Self.declaredKeys()
        let covered = Set(Self.everyCase().map(\.resource.key))
        #expect(declared.subtracting(covered).isEmpty, "missing from everyCase()")
        #expect(covered.subtracting(declared).isEmpty, "in everyCase() but declared nowhere")
    }

    @Test
    func `the scan reads a key and the whole call across an interpolation`() throws {
        let source = """
        // LocalizedStringResource("commented.out", defaultValue: "No", bundle: .module)
        LocalizedStringResource("a.key", defaultValue: "Hi \\(f(x)) (1)", bundle: .module)
        LocalizedStringResource(computedKey, bundle: .main)
        """
        let found = ResourceDeclarationScan.declarations(in: source, file: "Fixture.swift")
        try #require(found.count == 2)
        #expect(found[0].key == "a.key")
        #expect(found[0].arguments.hasSuffix("bundle: .module"))
        #expect(found[0].followsTheConvention)
        #expect(found[1].key == nil)
        #expect(!found[1].followsTheConvention)
    }

    @Test
    func `the catalog's English is exactly what Core renders in English`() throws {
        let catalog = try Self.catalog()
        for testCase in Self.everyCase() {
            let key = testCase.resource.key
            let english = try #require(
                catalog.strings[key]?.localizations[catalog.sourceLanguage]?.stringUnit?.value,
                "\(key) has no English value",
            )
            let formatted = String(format: english, arguments: testCase.arguments)
            #expect(formatted == testCase.resource.resolved(in: .english), "\(key)")
        }
    }

    @Test
    func `every catalog key has a translated Japanese value with the English specifiers`(
    ) throws {
        let catalog = try Self.catalog()
        for (key, entry) in catalog.strings.sorted(by: { $0.key < $1.key }) {
            guard let japanese = entry.localizations["ja"]?.stringUnit else {
                Issue.record("missing ja for key \"\(key)\"")
                continue
            }
            #expect(!japanese.value.isEmpty, "empty ja for key \"\(key)\"")
            #expect(japanese.state == "translated", "ja for key \"\(key)\" is not translated")
            let english = entry.localizations[catalog.sourceLanguage]?.stringUnit?.value ?? ""
            #expect(
                Self.formatSpecifiers(in: japanese.value).sorted()
                    == Self.formatSpecifiers(in: english).sorted(),
                "ja for key \"\(key)\" does not carry the English format specifiers",
            )
        }
    }

    @Test
    func `the specifier scan reads positional and length-modified specifiers`() {
        #expect(Self.formatSpecifiers(in: "%1$@ of %2$lld, 100%%") == ["%1$@", "%2$lld"])
        #expect(Self.formatSpecifiers(in: "none").isEmpty)
    }

    @Test
    func `every scope key has its Japanese value`() throws {
        let catalog = try Self.catalog()
        let scopeKeys = Set(catalog.strings.keys.filter { $0.hasPrefix("scope.") })
        #expect(scopeKeys == Set(Self.scopeJapanese.keys))
        for (key, japanese) in Self.scopeJapanese {
            #expect(
                catalog.strings[key]?.localizations["ja"]?.stringUnit?.value == japanese,
                "\(key)",
            )
        }
    }

    @Test
    func `every drill key has its Japanese value`() throws {
        let catalog = try Self.catalog()
        let drillKeys = Set(catalog.strings.keys.filter { $0.hasPrefix("drill.") })
        #expect(drillKeys == Set(Self.drillJapanese.keys))
        for (key, japanese) in Self.drillJapanese {
            #expect(
                catalog.strings[key]?.localizations["ja"]?.stringUnit?.value == japanese,
                "\(key)",
            )
        }
    }

    @Test
    func `the catalog and Core's bundle both declare English as the development language`() throws {
        #expect(try Self.catalog().sourceLanguage == "en")
        guard case let .atURL(url) = FailureStrings.dismiss.bundle else {
            Issue.record("FailureStrings.dismiss is not looked up in Core's bundle")
            return
        }
        #expect(Bundle(url: url)?.developmentLocalization == "en")
    }
}

extension Locale {
    /// The catalog's source language. Expectations resolve in it explicitly, so a test's
    /// expected string does not depend on the language of the machine running it.
    static let english = Locale(identifier: "en")
}

extension LocalizedStringResource {
    /// The string this resource renders as in `locale` — what a view would show a
    /// reader whose language is `locale`.
    func resolved(in locale: Locale) -> String {
        var resource = self
        resource.locale = locale
        return String(localized: resource)
    }
}
