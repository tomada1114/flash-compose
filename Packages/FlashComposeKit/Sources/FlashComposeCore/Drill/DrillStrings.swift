import Foundation

/// Every fixed piece of wording the drill (D1–D3, E1) shows, from Core's String Catalog.
///
/// Card content — the prompt, the answer, the alternatives, the point, and the topic
/// names — is data, not wording: it reaches the view as plain strings on ``DrillCard``.
/// The failed save's alert wording is ``DrillFailure``'s; interval labels are
/// ``IntervalLabel``'s.
public enum DrillStrings {
    /// The button that reveals the answer.
    public static var showAnswer: LocalizedStringResource {
        LocalizedStringResource(
            "drill.showAnswer",
            defaultValue: "Show answer",
            bundle: .module,
            comment: "Button under the prompt that reveals the model answer.",
        )
    }

    /// The heading over the alternative answers.
    public static var alternatives: LocalizedStringResource {
        LocalizedStringResource(
            "drill.alternatives",
            defaultValue: "Alternatives",
            bundle: .module,
            comment: "Heading over the other acceptable answers, under the model answer.",
        )
    }

    /// The done screen's headline.
    public static var doneTitle: LocalizedStringResource {
        LocalizedStringResource(
            "drill.done.title",
            defaultValue: "Done for today",
            bundle: .module,
            comment: "Headline of the screen shown when no card is left today.",
        )
    }

    /// The done screen's button that opens the scope sheet.
    public static var changeScope: LocalizedStringResource {
        LocalizedStringResource(
            "drill.done.changeScope",
            defaultValue: "Change scope…",
            bundle: .module,
            comment: "Button on the done screen that opens the scope sheet.",
        )
    }

    /// The start-up failure's headline.
    public static var startFailureTitle: LocalizedStringResource {
        LocalizedStringResource(
            "drill.startFailure.title",
            defaultValue: "Can't open the data",
            bundle: .module,
            comment: "Headline shown instead of the drill when the cards or the progress could not be loaded.",
        )
    }

    /// The start-up failure's explanation.
    public static var startFailureMessage: LocalizedStringResource {
        LocalizedStringResource(
            "drill.startFailure.message",
            defaultValue: "Couldn't load the cards or your progress",
            bundle: .module,
            comment: "Explanation under the start-up failure's headline.",
        )
    }

    /// The button that repeats the start-up.
    public static var retry: LocalizedStringResource {
        LocalizedStringResource(
            "drill.startFailure.retry",
            defaultValue: "Try Again",
            bundle: .module,
            comment: "Button that loads the cards and the progress again after a failure.",
        )
    }

    /// The name of a pile: 新規 / New, 復習 / Review, もう一度 / Again — the card's kind on
    /// its front and a count's title in the header.
    public static func kind(_ pile: DrillPile) -> LocalizedStringResource {
        switch pile {
        case .new:
            LocalizedStringResource(
                "drill.kind.new",
                defaultValue: "New",
                bundle: .module,
                comment: "Kind of a card never seen before, and the header count of such cards.",
            )

        case .reAsk:
            LocalizedStringResource(
                "drill.kind.reAsk",
                defaultValue: "Again",
                bundle: .module,
                comment: """
                Kind of a card shown again in this session, and the header count of cards \
                waiting to come back.
                """,
            )

        case .review:
            LocalizedStringResource(
                "drill.kind.review",
                defaultValue: "Review",
                bundle: .module,
                comment: "Kind of a card due for review today, and the header count of such cards.",
            )
        }
    }

    /// The line above the prompt: the card's kind, its topic's name, and its level, such
    /// as `復習 · 仕事 · L5`.
    public static func kindLine(
        kind: LocalizedStringResource,
        topic: String,
        level: Int,
    ) -> LocalizedStringResource {
        LocalizedStringResource(
            "drill.card.kindLine",
            defaultValue: "\(kind) · \(topic) · L\(level)",
            bundle: .module,
            comment: """
            Small line above the prompt. The arguments are the card's kind (New, Review, or \
            Again), its topic's name, and its level number.
            """,
        )
    }

    /// A grade button's word: 忘れた / Forgot, 微妙 / Hard, 覚えてた / Got it.
    public static func grade(_ grade: Grade) -> LocalizedStringResource {
        switch grade {
        case .again:
            LocalizedStringResource(
                "drill.grade.again",
                defaultValue: "Forgot",
                bundle: .module,
                comment: "Grade button: the learner could not produce the English.",
            )

        case .good:
            LocalizedStringResource(
                "drill.grade.good",
                defaultValue: "Got it",
                bundle: .module,
                comment: "Grade button: the learner produced the English.",
            )

        case .hard:
            LocalizedStringResource(
                "drill.grade.hard",
                defaultValue: "Hard",
                bundle: .module,
                comment: "Grade button: the learner produced the English with effort or only in part.",
            )
        }
    }

    /// What VoiceOver reads for a grade button that shows an interval, such as
    /// `忘れた、次回1日後` / `Forgot, next in 1 day`.
    public static func gradeWithInterval(
        _ grade: LocalizedStringResource,
        interval: LocalizedStringResource,
    ) -> LocalizedStringResource {
        LocalizedStringResource(
            "drill.grade.spoken",
            defaultValue: "\(grade), next in \(interval)",
            bundle: .module,
            comment: """
            Spoken name of a grade button. The arguments are the grade's word and the \
            interval until the card comes back, such as "1 day".
            """,
        )
    }

    /// What VoiceOver reads for the header: the three counts, already formatted with
    /// grouping, and which pile the card on screen is from; `pile` is `nil` when no card
    /// is on screen.
    public static func header(
        new: String,
        review: String,
        reAsk: String,
        pile: DrillPile?,
    ) -> LocalizedStringResource {
        switch pile {
        case .new:
            LocalizedStringResource(
                "drill.header.spoken.new",
                defaultValue: "New \(new), Review \(review), Again \(reAsk). This card is new",
                bundle: .module,
                comment: """
                Spoken drill header while a new card is on screen. The arguments are the \
                New, Review, and Again counts, formatted with grouping.
                """,
            )

        case .reAsk:
            LocalizedStringResource(
                "drill.header.spoken.reAsk",
                defaultValue: "New \(new), Review \(review), Again \(reAsk). This card is an Again card",
                bundle: .module,
                comment: """
                Spoken drill header while a card shown again in this session is on screen. \
                The arguments are the New, Review, and Again counts, formatted with grouping.
                """,
            )

        case .review:
            LocalizedStringResource(
                "drill.header.spoken.review",
                defaultValue: "New \(new), Review \(review), Again \(reAsk). This card is a review",
                bundle: .module,
                comment: """
                Spoken drill header while a review is on screen. The arguments are the New, \
                Review, and Again counts, formatted with grouping.
                """,
            )

        case nil:
            LocalizedStringResource(
                "drill.header.spoken.none",
                defaultValue: "New \(new), Review \(review), Again \(reAsk)",
                bundle: .module,
                comment: """
                Spoken drill header when no card is on screen. The arguments are the New, \
                Review, and Again counts, formatted with grouping.
                """,
            )
        }
    }

    /// The day the next review is due; `day` is already worded by ``DayWording``.
    public static func nextReview(_ day: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "drill.done.nextReview",
            defaultValue: "Next review: \(day)",
            bundle: .module,
            comment: """
            Line on the done screen. The argument is the day the next review is due, such \
            as "Thu, Oct 15" or "Tomorrow".
            """,
        )
    }

    /// The never-seen cards outside the scope; `count` is already formatted with grouping.
    public static func outsideScope(_ count: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "drill.done.outsideScope",
            defaultValue: "Unseen outside the scope: \(count)",
            bundle: .module,
            comment: """
            Line on the done screen. The argument is the number of never-seen cards in the \
            topics and levels turned off, formatted with grouping.
            """,
        )
    }
}
