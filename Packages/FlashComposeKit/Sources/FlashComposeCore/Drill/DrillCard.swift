import Foundation

/// One of the three grade buttons on the answer face (D2): the grade, and the interval it
/// would set when this answer moves the card's schedule.
public struct GradeOption: Equatable, Sendable, Identifiable {
    /// The order the buttons stand in, left to right: × forgot, △ hard, ○ got it — as in
    /// the old app, where ← graded again and → good. ``Grade/allCases`` is alphabetical,
    /// not this.
    public static let displayOrder: [Grade] = [.again, .hard, .good]

    /// The grade the button records.
    public let grade: Grade
    /// The days until the card would be due again; `nil` when this answer moves nothing —
    /// a re-ask, or a card already answered today (`docs/product/ux-flows.md` D2).
    public let intervalDays: Int?

    /// The button's identity: its grade.
    public var id: Grade {
        grade
    }

    /// The glyph the button leads with, shown verbatim: ×, △, or ○.
    public var symbol: String {
        switch grade {
        case .again:
            "\u{00D7}"

        case .good:
            "\u{25CB}"

        case .hard:
            "\u{25B3}"
        }
    }

    /// The grade's word: 忘れた / Forgot, 微妙 / Hard, 覚えてた / Got it.
    public var title: LocalizedStringResource {
        DrillStrings.grade(grade)
    }

    /// The interval the button shows, such as `1日` / `1 day`; `nil` when it shows none.
    public var intervalLabel: LocalizedStringResource? {
        intervalDays.map { IntervalLabel(days: $0).text }
    }

    /// What VoiceOver reads: the grade and the interval (`忘れた、次回1日後`), or the grade
    /// alone when the button shows no interval.
    public var accessibilityLabel: LocalizedStringResource {
        guard let intervalLabel else {
            return title
        }
        return DrillStrings.gradeWithInterval(title, interval: intervalLabel)
    }

    /// Pairs a grade with the interval it would set; the drill is what decides both.
    public init(grade: Grade, intervalDays: Int?) {
        self.grade = grade
        self.intervalDays = intervalDays
    }
}

/// One count in the drill header (`docs/product/ux-flows.md` §2): its pile's name, the
/// count formatted with grouping, and whether the card on screen is from it.
public struct DrillHeaderItem: Equatable, Sendable, Identifiable {
    /// The pile counted.
    public let pile: DrillPile
    /// The count, formatted with grouping in the drill's locale, such as `1,820`.
    public let count: String
    /// Whether the card on screen came from this pile, which the header underlines.
    public let isCurrent: Bool

    /// The item's identity: its pile.
    public var id: DrillPile {
        pile
    }

    /// The count's name: 新規 / New, 復習 / Review, もう一度 / Again.
    public var title: LocalizedStringResource {
        DrillStrings.kind(pile)
    }

    /// Gathers one count; the drill is what decides it.
    public init(pile: DrillPile, count: String, isCurrent: Bool) {
        self.pile = pile
        self.count = count
        self.isCurrent = isCurrent
    }
}

/// The drill header (`docs/product/ux-flows.md` §2) as the view shows it: the three
/// counts and what VoiceOver reads for them.
public struct DrillHeader: Equatable, Sendable {
    /// 新規, 復習, もう一度, in the order a card travels, the card on screen's pile marked.
    public let items: [DrillHeaderItem]
    /// The counts and the card on screen's pile as one sentence, such as
    /// `新規 1,820、復習 12、もう一度 0。このカードは復習`.
    public let accessibilityLabel: LocalizedStringResource

    /// The header for `counts`, each count grouped in `locale`, such as `1,820`.
    public init(counts: HeaderCounts, locale: Locale) {
        func formatted(_ count: Int) -> String {
            count.formatted(.number.locale(locale))
        }
        items = [(DrillPile.new, counts.new), (.review, counts.review), (.reAsk, counts.reAsk)]
            .map { pile, count in
                DrillHeaderItem(
                    pile: pile,
                    count: formatted(count),
                    isCurrent: counts.currentPile == pile,
                )
            }
        accessibilityLabel = DrillStrings.header(
            new: formatted(counts.new),
            review: formatted(counts.review),
            reAsk: formatted(counts.reAsk),
            pile: counts.currentPile,
        )
    }
}

/// The card on screen as the drill shows it (D1, D2): the card, the pile it was dealt
/// from, and what its front and its grade buttons say.
///
/// Built once when the card is dealt and kept until it is graded, so its kind and its
/// intervals stay as they were when 04:00 passes or the scope changes while it is on
/// screen (`docs/product/ux-flows.md` F3, F7).
public struct DrillCard: Equatable, Sendable {
    /// The card: its prompt, answer, alternatives, and point are data, shown verbatim.
    public let card: Card
    /// The pile it was dealt from: its kind, and the header count underlined.
    public let pile: DrillPile
    /// Its topic's Japanese name from the catalog, shown verbatim in either language.
    public let topicName: String
    /// The three grade buttons, in ``GradeOption/displayOrder``.
    public let gradeOptions: [GradeOption]

    /// The kind on the card's front: 新規 / New, 復習 / Review, or もう一度 / Again.
    public var kind: LocalizedStringResource {
        DrillStrings.kind(pile)
    }

    /// The line above the prompt: kind, topic, and level, such as `復習 · 仕事 · L5`.
    public var kindLine: LocalizedStringResource {
        DrillStrings.kindLine(kind: kind, topic: topicName, level: card.level.rawValue)
    }

    /// Gathers what the front and the buttons show; the drill is what decides it.
    public init(card: Card, pile: DrillPile, topicName: String, gradeOptions: [GradeOption]) {
        self.card = card
        self.pile = pile
        self.topicName = topicName
        self.gradeOptions = gradeOptions
    }
}
