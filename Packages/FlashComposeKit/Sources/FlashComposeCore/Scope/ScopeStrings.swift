import Foundation

/// Every fixed piece of wording the scope sheet (S1) shows, from Core's String Catalog.
///
/// Topic names and TOEIC labels are catalog content, not wording: they reach the view as
/// plain strings on ``ScopeRow``.
public enum ScopeStrings {
    /// The sheet's title.
    public static var title: LocalizedStringResource {
        LocalizedStringResource(
            "scope.title",
            defaultValue: "Scope",
            bundle: .module,
            comment: """
            Title of the sheet where the learner picks which topics and levels new cards \
            come from.
            """,
        )
    }

    /// The button that closes the sheet.
    public static var done: LocalizedStringResource {
        LocalizedStringResource(
            "scope.done",
            defaultValue: "Done",
            bundle: .module,
            comment: "Button that closes the scope sheet.",
        )
    }

    /// The header note's first line: the scope steers new cards.
    public static var noteNewCards: LocalizedStringResource {
        LocalizedStringResource(
            "scope.note.newCards",
            defaultValue: "Where new cards come from.",
            bundle: .module,
            comment: """
            First line of the note at the top of the scope sheet: the scope picks where new \
            cards come from.
            """,
        )
    }

    /// The header note's second line: reviews ignore the scope.
    public static var noteReviews: LocalizedStringResource {
        LocalizedStringResource(
            "scope.note.reviews",
            defaultValue: "Reviews ignore the scope.",
            bundle: .module,
            comment: """
            Second line of the note at the top of the scope sheet: due reviews come from every \
            topic and level.
            """,
        )
    }

    /// The topics section's header.
    public static var topicsHeader: LocalizedStringResource {
        LocalizedStringResource(
            "scope.topics",
            defaultValue: "Topics",
            bundle: .module,
            comment: "Header of the scope sheet's section listing the topics.",
        )
    }

    /// The levels section's header.
    public static var levelsHeader: LocalizedStringResource {
        LocalizedStringResource(
            "scope.levels",
            defaultValue: "Levels",
            bundle: .module,
            comment: "Header of the scope sheet's section listing the levels.",
        )
    }

    /// The note under a section with exactly one row on, whose row cannot be turned off.
    public static var pickAtLeastOne: LocalizedStringResource {
        LocalizedStringResource(
            "scope.pickAtLeastOne",
            defaultValue: "Pick at least one",
            bundle: .module,
            comment: "Note under a scope section whose only checked row cannot be unchecked.",
        )
    }

    /// What replaces the count when the scope holds no never-seen card.
    public static var allShown: LocalizedStringResource {
        LocalizedStringResource(
            "scope.allShown",
            defaultValue: "Every card in this scope shown",
            bundle: .module,
            comment: "Shown instead of the count when every card in the scope has been shown before.",
        )
    }

    /// The live count of never-seen cards in the scope; `count` is already formatted with
    /// grouping, such as `1,402`.
    public static func unseenCount(_ count: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "scope.unseenCount",
            defaultValue: "Unseen in this scope: \(count)",
            bundle: .module,
            comment: """
            Live count at the bottom of the scope sheet. The argument is the number of \
            never-seen cards, formatted with grouping.
            """,
        )
    }
}
