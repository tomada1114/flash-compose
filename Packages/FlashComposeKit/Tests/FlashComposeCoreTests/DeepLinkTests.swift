import FlashComposeCore
import Foundation
import Testing

/// ``DeepLink``: the one URL shape the app opens — `flash-compose://`, the drill — and the
/// scheme it is registered under.
///
/// The URLs below spell the scheme as a literal on purpose — an oracle independent of
/// ``DeepLink/scheme``. `scripts/bootstrap.sh` rewrites that literal here, in
/// `DeepLink.swift`, and in `project.yml` together; only the upper-cased spelling is
/// derived, because the rename does not rewrite an upper-cased placeholder.
@Suite("DeepLink")
struct DeepLinkTests {
    /// The key in `project.yml`'s `info:` block that lists the URL schemes the app claims.
    static let schemesKey = "CFBundleURLSchemes:"

    // MARK: - Helpers

    /// The URL schemes a `project.yml` registers: the value after ``schemesKey``, as a
    /// flow list on the same line (`[a, b]`) or, when that line holds nothing more, as
    /// the block list (`- a`) on the lines after it. Each element is compared whole, so
    /// `flash-compose-dev` does not count as `flash-compose`.
    static func registeredSchemes(inManifest manifest: String) -> [String] {
        let lines = manifest.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyLine = lines.firstIndex(where: { $0.hasPrefix(schemesKey) }) else {
            return []
        }
        let inline = lines[keyLine].dropFirst(schemesKey.count)
            .trimmingCharacters(in: .whitespaces)
        let elements: [String] = if inline.isEmpty {
            Array(lines[(keyLine + 1)...].prefix { $0.hasPrefix("- ") }.map { $0.dropFirst(2) })
                .map(String.init)
        } else {
            inline.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .split(separator: ",")
                .map(String.init)
        }
        return elements
            .map { AppLogTests.unquoted($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Parsing

    @Test
    func `the bare scheme opens the root, the drill`() throws {
        let url = try #require(URL(string: "flash-compose://"))
        #expect(DeepLink.destination(for: url) == .drill)
    }

    @Test
    func `the scheme is compared without regard to case`() throws {
        let url = try #require(URL(string: "\(DeepLink.scheme.uppercased())://"))
        #expect(url.scheme != DeepLink.scheme, "the fixture must really be upper-cased")
        #expect(DeepLink.destination(for: url) == .drill)
    }

    // MARK: - Rejecting

    /// Every shape other than exactly `flash-compose://`, each with its own reason —
    /// among them the removed detail-screen link, which no longer opens anything.
    @Test(arguments: [
        ("another scheme", "https://"),
        ("the removed detail link", "flash-compose://todo/3F2504E0-4F89-11D3-9A0C-0305E82C3301"),
        ("a host", "flash-compose://drill"),
        ("no authority", "flash-compose:"),
        ("a path without a host", "flash-compose:/drill"),
        ("a trailing slash", "flash-compose:///"),
        ("a query string", "flash-compose://?scope=tech"),
        ("an empty query string", "flash-compose://?"),
        ("a fragment", "flash-compose://#drill"),
        ("a user", "flash-compose://me@"),
        ("a port", "flash-compose://:80"),
    ])
    func `a link of any other shape opens nothing`(reason: String, link: String) throws {
        let url = try #require(URL(string: link), "\(reason): the fixture must be a URL")
        #expect(DeepLink.destination(for: url) == nil, "\(reason): \(link)")
    }

    // MARK: - The registered scheme

    @Test
    func `the scheme Core parses is the one project yml registers`() throws {
        let manifest = AppLogTests.repositoryRoot.appendingPathComponent("project.yml")
        let schemes = try Self.registeredSchemes(
            inManifest: String(contentsOf: manifest, encoding: .utf8),
        )
        #expect(
            schemes.contains(DeepLink.scheme),
            """
            \(manifest.path) registers \(schemes) under \(Self.schemesKey).
            DeepLink.scheme and project.yml must name the same URL scheme, or the system
            never hands the app the links Core knows how to open.
            """,
        )
    }

    @Test
    func `the scheme reader reads a flow list and a block list`() {
        let read = Self.registeredSchemes(inManifest:)
        #expect(read("            CFBundleURLSchemes: [flash-compose]\n") == ["flash-compose"])
        #expect(read("CFBundleURLSchemes: [\"a\", 'b']\n") == ["a", "b"])
        #expect(read("CFBundleURLSchemes:\n  - a\n  - b\nnext: 1\n") == ["a", "b"])
        #expect(read("CFBundleURLSchemes: [flash-compose-dev]\n") != ["flash-compose"])
        #expect(read("name: FlashCompose\n").isEmpty)
    }
}
