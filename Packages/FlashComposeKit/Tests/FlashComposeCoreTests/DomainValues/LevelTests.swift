import FlashComposeCore
import Testing

@Suite("Level")
struct LevelTests {
    @Test(arguments: [1, 2, 5, 9, 10])
    func `a level from 1 to 10 is accepted`(value: Int) throws {
        #expect(try Level(value).rawValue == value)
    }

    @Test(arguments: [0, 11, -1, 100, Int.min, Int.max])
    func `a level outside 1 to 10 is rejected`(value: Int) {
        #expect(throws: LevelError.outOfRange) {
            try Level(value)
        }
    }

    @Test
    func `every level is listed once, lowest first`() {
        #expect(Level.allCases.map(\.rawValue) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    }

    @Test
    func `levels order by number`() throws {
        let low = try Level(2)
        let high = try Level(10)
        #expect(low < high)
        #expect(!(high < low))
        #expect(try Level(2) == low)
    }
}
