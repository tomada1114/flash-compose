import FlashComposeCore
import Testing

@Suite("Grade")
struct GradeTests {
    @Test(arguments: [(Grade.again, 1), (.hard, 2), (.good, 3)])
    func `each grade carries the number FSRS rates it with`(grade: Grade, rating: Int) {
        #expect(grade.rawValue == rating)
        #expect(Grade(rawValue: rating) == grade)
    }

    @Test
    func `there are exactly three grades and no easy`() {
        #expect(Set(Grade.allCases) == [.again, .hard, .good])
        #expect(Grade.allCases.count == 3)
        #expect(Grade(rawValue: 4) == nil)
        #expect(Grade(rawValue: 0) == nil)
    }
}
