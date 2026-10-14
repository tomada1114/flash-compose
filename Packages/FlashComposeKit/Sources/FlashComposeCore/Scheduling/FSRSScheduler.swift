// FSRS-6's long-term schedule, ported from the old app's port
// (tomada1114/instant-composition, packages/domain/src/fsrs.ts) of ts-fsrs 5.4.2's
// LongTermScheduler (src/impl/long_term_scheduler.ts and src/strategies/seed.ts), whose
// notice follows: the formulas are in FSRSMemoryModel.swift and the intervals in
// FSRSIntervalModel.swift. Elapsed days are the difference of two practice days, never of
// wall-clock time.
//
// MIT License
//
// Copyright (c) 2026 Open Spaced Repetition
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/// Where one grade leaves a card.
public struct GradeOutcome: Hashable, Sendable {
    /// The card's state after the grade.
    public let state: FSRSState
    /// Days from the answer to `state.dueDay`, at least the shortest interval: what the
    /// grade's button shows.
    public let intervalDays: Int

    /// Pairs a state with its interval; the scheduler is what decides both.
    public init(state: FSRSState, intervalDays: Int) {
        self.state = state
        self.intervalDays = intervalDays
    }
}

/// Each grade's outcome for a card answered today: what the grade buttons show.
public struct GradePreview: Hashable, Sendable {
    /// × forgot.
    public let again: GradeOutcome
    /// △ unsure.
    public let hard: GradeOutcome
    /// ○ remembered.
    public let good: GradeOutcome

    /// Gathers the three outcomes; the scheduler is what decides them.
    public init(again: GradeOutcome, hard: GradeOutcome, good: GradeOutcome) {
        self.again = again
        self.hard = hard
        self.good = good
    }

    /// The outcome of `grade`.
    public subscript(grade: Grade) -> GradeOutcome {
        switch grade {
        case .again:
            again

        case .good:
            good

        case .hard:
            hard
        }
    }
}

/// FSRS-6's long-term scheduler: the state a grade leaves a card in, the outcome of each
/// grade before one is chosen, and how likely a card is still remembered
/// (`docs/architecture.md` › Scheduling).
///
/// A pure function of its inputs: the fuzz is seeded by the card id and the rep count
/// rather than drawn from a generator, so the preview a button shows and the state the
/// tap then stores are the same, and a repeat gives the same day.
public struct FSRSScheduler: Sendable {
    private let memory: FSRSMemoryModel
    private let intervals: FSRSIntervalModel

    /// A scheduler over `tuning`; the app uses the default, which the golden vectors fix.
    public init(tuning: FSRSTuning = Tuning.default.fsrs) {
        memory = FSRSMemoryModel(tuning: tuning)
        intervals = FSRSIntervalModel(tuning: tuning, intervalModifier: memory.intervalModifier)
    }

    /// Elapsed days, with a day before the last answer — a clock moved back — reading as
    /// the same day rather than a negative wait, which FSRS has no meaning for.
    private static func elapsedDays(since lastDay: PracticeDay, until today: PracticeDay) -> Int {
        max(0, today.days(since: lastDay))
    }

    /// Each grade's next state and interval for `card` answered on `today`.
    ///
    /// - Parameter previous: The card's state, or `nil` for a card never graded: it is
    ///   scheduled as a new card, and its first again is not a lapse.
    public func preview(
        _ previous: FSRSState?,
        on today: PracticeDay,
        card: CardID,
    ) -> GradePreview {
        preview(previous, on: today, seedKey: card.rawValue)
    }

    /// The outcome one `grade` on `today` leaves `card` in; the same as that grade's entry
    /// in ``preview(_:on:card:)``.
    public func schedule(
        _ previous: FSRSState?,
        grade: Grade,
        on today: PracticeDay,
        card: CardID,
    ) -> GradeOutcome {
        preview(previous, on: today, card: card)[grade]
    }

    /// The chance the learner still recalls the card on `today`:
    /// `R(t, S) = (1 + F·t/S)^(−w20)`, with `F = 0.9^(−1/w20) − 1` and `t` the practice days
    /// since its last answer. 1 on that day, and 0.9 when `t` equals the stability.
    public func retrievability(of state: FSRSState, on today: PracticeDay) -> Double {
        memory.forgettingCurve(
            elapsedDays: Double(Self.elapsedDays(since: state.lastDay, until: today)),
            stability: state.stability,
        )
    }

    /// ``preview(_:on:card:)`` with the fuzz seeded by any string rather than a ``CardID``,
    /// for the golden vectors, whose card ids predate the catalog's format.
    package func preview(
        _ previous: FSRSState?,
        on today: PracticeDay,
        seedKey: String,
    ) -> GradePreview {
        let reps = (previous?.reps ?? 0) + 1
        let elapsed = previous.map { Self.elapsedDays(since: $0.lastDay, until: today) } ?? 0
        let againMemory = nextMemory(previous, elapsedDays: elapsed, grade: .again)
        let hardMemory = nextMemory(previous, elapsedDays: elapsed, grade: .hard)
        let goodMemory = nextMemory(previous, elapsedDays: elapsed, grade: .good)
        let days = intervals.intervals(
            again: againMemory.stability,
            hard: hardMemory.stability,
            good: goodMemory.stability,
            elapsedDays: elapsed,
            seed: "\(seedKey)\(reps)",
        )
        let lapses = previous?.lapses ?? 0
        func outcome(_ grade: Grade, _ next: FSRSMemory, intervalDays: Int) -> GradeOutcome {
            let lapsed = grade == .again && previous != nil
            return GradeOutcome(
                state: FSRSState(
                    stability: next.stability,
                    difficulty: next.difficulty,
                    reps: reps,
                    lapses: lapsed ? lapses + 1 : lapses,
                    lastDay: today,
                    dueDay: today.adding(days: intervalDays),
                ),
                intervalDays: intervalDays,
            )
        }
        return GradePreview(
            again: outcome(.again, againMemory, intervalDays: days.again),
            hard: outcome(.hard, hardMemory, intervalDays: days.hard),
            good: outcome(.good, goodMemory, intervalDays: days.good),
        )
    }

    private func nextMemory(_ previous: FSRSState?, elapsedDays: Int, grade: Grade) -> FSRSMemory {
        guard let previous else {
            return memory.initialMemory(grade: grade)
        }
        return memory.nextMemory(
            FSRSMemory(stability: previous.stability, difficulty: previous.difficulty),
            elapsedDays: Double(elapsedDays),
            grade: grade,
        )
    }
}
