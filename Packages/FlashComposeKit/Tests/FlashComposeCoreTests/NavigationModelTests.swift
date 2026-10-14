import FlashComposeCore
import Foundation
import Testing

/// ``NavigationModel``: the navigation path as Core state, and what a deep link does to it.
///
/// ``AppRoute`` has no case yet, so no test can push one: the path starts, and stays, at
/// the root.
@MainActor
@Suite("NavigationModel")
struct NavigationModelTests {
    @Test
    func `starts at the root`() {
        #expect(NavigationModel().path.isEmpty)
    }

    @Test
    func `popToRoot at the root leaves it there`() {
        let navigation = NavigationModel()
        navigation.popToRoot()
        #expect(navigation.path.isEmpty)
    }

    @Test
    func `opening the root link lands on the drill`() throws {
        let navigation = NavigationModel()
        let url = try #require(URL(string: "flash-compose://"))
        #expect(navigation.open(url))
        #expect(navigation.path.isEmpty)
    }

    @Test(arguments: [
        "https://example.com/",
        "flash-compose://card/c_7k2m9x4q",
        "flash-compose://settings",
    ])
    func `opening an invalid link leaves the path alone`(link: String) throws {
        let navigation = NavigationModel()
        let url = try #require(URL(string: link))
        #expect(!navigation.open(url))
        #expect(navigation.path.isEmpty)
    }
}
