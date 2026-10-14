import SwiftUI

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

/// The design lock's colours (`docs/design-system.md` › Design lock › Custom colors), by
/// role: the five Color Sets `App/Assets.xcassets` holds, and the semantic system colours
/// the lock names for the drill's surfaces.
///
/// A view names a role here, never a Color Set's name or a system colour directly, so a
/// role moves in one place. The Color Sets live in the app's asset catalog, which is the
/// main bundle at run time; a `#Preview` inside this package has no such catalog and
/// draws them clear. The system colours are UIKit's; `FlashComposeUI` also compiles for
/// macOS under `swift build`, where the nearest AppKit colour stands in, never shipped.
enum ColorRoles {
    /// The fill of the one primary action per screen (答えを見る, 再試行); white text on it.
    static let action = Color("Action")
    /// The fill of the ○ button only.
    static let good = Color("Good")
    /// Text and glyph on ``good``.
    static let onGood = Color("OnGood")
    /// The 1 pt stroke around the ○ button, so its edge holds 3:1 on white.
    static let goodEdge = Color("GoodEdge")
    /// All secondary text: the kind line, the small prompt on D2, alternatives, interval
    /// labels, notes. System `secondaryLabel` measures under 4.5:1 on white.
    static let inkSecondary = Color("InkSecondary")

    /// Behind the drill: `systemBackground`.
    static var background: Color {
        #if os(iOS)
            Color(uiColor: .systemBackground)
        #else
            Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// The card: `secondarySystemBackground`.
    static var card: Color {
        #if os(iOS)
            Color(uiColor: .secondarySystemBackground)
        #else
            Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// The point box inside the card: `tertiarySystemBackground`.
    static var pointBox: Color {
        #if os(iOS)
            Color(uiColor: .tertiarySystemBackground)
        #else
            Color(nsColor: .textBackgroundColor)
        #endif
    }

    /// The × and △ buttons: `systemGray5`.
    static var neutralGrade: Color {
        #if os(iOS)
            Color(uiColor: .systemGray5)
        #else
            Color(nsColor: .quaternaryLabelColor)
        #endif
    }
}
