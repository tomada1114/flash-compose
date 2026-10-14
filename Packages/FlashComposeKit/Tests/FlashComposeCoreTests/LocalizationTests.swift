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

    /// Every resource Core returns, once per state that picks a different key, with the
    /// arguments its English takes. Adding a key to Core means adding it here: the
    /// source-scan tests fail until this list names every key Core's sources declare.
    static func everyCase() -> [Case] {
        let strings: [LocalizedStringResource] = [
            TodoListStrings.title, TodoListStrings.draftPlaceholder, TodoListStrings.add,
            TodoListStrings.emptyTitle, TodoListStrings.emptyDescription,
            TodoListStrings.failureTitle, FailureStrings.dismiss, TodoListStrings.retry,
            TodoListStrings.markDone, TodoListStrings.markNotDone,
            TodoListStrings.hideCompleted, TodoListStrings.allDoneTitle,
            TodoListStrings.allDoneDescription,
            TodoDetailStrings.created, TodoDetailStrings.notFoundTitle,
            TodoDetailStrings.notFoundDescription,
            ScopeStrings.title, ScopeStrings.done, ScopeStrings.noteNewCards,
            ScopeStrings.noteReviews, ScopeStrings.topicsHeader, ScopeStrings.levelsHeader,
            ScopeStrings.pickAtLeastOne, ScopeStrings.allShown,
        ]
        let failures: [TodoListFailure] = [.deleteFailed, .loadFailed, .saveFailed]
        return strings.map { Case(resource: $0, arguments: []) }
            + failures.map { Case(resource: $0.message, arguments: []) }
            + [Case(resource: ScopeStrings.unseenCount("1,402"), arguments: ["1,402"])]
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
    func `the catalog and Core's bundle both declare English as the development language`() throws {
        #expect(try Self.catalog().sourceLanguage == "en")
        guard case let .atURL(url) = TodoListStrings.title.bundle else {
            Issue.record("TodoListStrings.title is not looked up in Core's bundle")
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
