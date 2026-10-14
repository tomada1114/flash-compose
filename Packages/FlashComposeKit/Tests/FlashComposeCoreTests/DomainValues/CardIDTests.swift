import FlashComposeCore
import Testing

@Suite("CardID")
struct CardIDTests {
    @Test(arguments: ["c_2t5h9y9g", "c_7k2m9x4q", "c_2a5d9v8h", "c_9z2a3n4p"])
    func `an id in the catalog's format is accepted and kept as written`(raw: String) throws {
        let id = try CardID(raw)
        #expect(id.rawValue == raw)
    }

    @Test(arguments: [
        "c_0a1b2c3d", // banned digits 0 and 1
        "c_2t5h9y9", // one character short
        "c_2t5h9y9gg", // one character long
        "c_2t5h9y9g2t", // a fifth pair
        "c_2T5h9y9g", // an uppercase letter
        "C_2t5h9y9g", // an uppercase prefix
        "c_2i5h9y9g", // banned letter i
        "c_2l5h9y9g", // banned letter l
        "c_2o5h9y9g", // banned letter o
        "c_1t5h9y9g", // banned digit 1
        "c_t25h9y9g", // letter before digit
        "c-2t5h9y9g", // wrong separator
        "x_2t5h9y9g", // wrong prefix
        "2t5h9y9g", // no prefix
        "c_2t5h9y9g\n", // a trailing newline
        " c_2t5h9y9g", // a leading space
        "c_\u{FF12}t5h9y9g", // a full-width digit
        "",
    ])
    func `an id outside the format is rejected`(raw: String) {
        #expect(throws: CardIDError.doesNotMatchFormat) {
            try CardID(raw)
        }
    }

    @Test
    func `ids are equal exactly when their text is`() throws {
        let first = try CardID("c_2t5h9y9g")
        let same = try CardID("c_2t5h9y9g")
        let other = try CardID("c_7k2m9x4q")
        #expect(first == same)
        #expect(first != other)
        #expect(Set([first, same, other]).count == 2)
    }
}
