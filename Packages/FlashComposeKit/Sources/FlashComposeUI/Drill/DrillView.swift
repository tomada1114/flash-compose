import FlashComposeCore
import SwiftUI

/// The drill (`docs/product/ux-flows.md` D1–D3, E1): the root screen of `RootView`'s
/// navigation stack, rendering ``DrillViewModel`` and nothing else.
///
/// Deliberately thin — the queue, the counts, the wording, and every rule about what may
/// happen next are the view model's and unit-tested there. This view turns each tap into
/// one view-model call and draws the state it reads back: the header above the card, the
/// face that is up, and the face's action in a bottom `safeAreaInset`, where the thumb
/// stays through reveal → grade → reveal. The toolbar is left free for the scope button.
///
/// It presents no alert of its own: a failed save (E2) presents from `RootView`, which
/// observes ``DrillViewModel/failure``. It owns neither model: `AppModel` builds both.
struct DrillView: View {
    private let model: DrillViewModel
    private let startup: StartupIndicator

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.scenePhase)
    private var scenePhase
    @AccessibilityFocusState private var focus: DrillFocus?
    /// Counts grade taps, so each one fires the one selection haptic.
    @State private var gradeTaps = 0

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorRoles.background)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .animation(animation, value: model.phase)
            .animation(animation, value: model.card)
            .sensoryFeedback(.selection, trigger: gradeTaps)
            .task { await model.start() }
            .task { await startup.watch() }
            .task { await model.watchPracticeDay() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    model.sceneDidBecomeActive()
                }
            }
            .onChange(of: model.face) { old, new in
                if let next = DrillFocus.after(old, new) {
                    focus = next
                }
            }
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var animation: Animation? {
        DesignTokens.Motion.animation(reduceMotion: reduceMotion)
    }

    @ViewBuilder private var content: some View {
        if startup.isVisible {
            ProgressView()
        } else {
            switch model.phase {
            case .starting:
                // The plain background: the start-up is under the indicator's delay.
                Color.clear

            case .failed:
                StartupFailureView()
                    .transition(.opacity)

            case let .ready(face):
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    DrillHeaderView(header: model.header)
                        .animation(animation, value: model.header)
                    faceView(face)
                }
                .padding([.horizontal, .top])
            }
        }
    }

    @ViewBuilder private var bottomBar: some View {
        if !startup.isVisible {
            switch model.phase {
            case .starting:
                EmptyView()

            case .failed:
                bar(
                    PrimaryActionButton(title: DrillStrings.retry) {
                        Task { await model.retry() }
                    }
                    .accessibilityIdentifier("retryButton"),
                )

            case .ready(.question):
                bar(
                    PrimaryActionButton(title: DrillStrings.showAnswer, action: model.reveal)
                        .accessibilityIdentifier("showAnswerButton"),
                )

            case .ready(.answer):
                bar(
                    GradeBar(options: model.card?.gradeOptions ?? []) { grade in
                        gradeTaps += 1
                        Task { await model.grade(grade) }
                    }
                    // The view model ignores a grade until the next card is up; ignoring
                    // the tap too keeps a double tap from firing a second haptic.
                    .allowsHitTesting(!model.isGrading),
                )

            case .ready(.done):
                EmptyView()
            }
        }
    }

    /// Builds the drill over `model` and `startup`, which `AppModel` owns.
    init(model: DrillViewModel, startup: StartupIndicator) {
        self.model = model
        self.startup = startup
    }

    @ViewBuilder
    private func faceView(_ face: DrillViewModel.Face) -> some View {
        switch face {
        case .question:
            if let card = model.card {
                QuestionFace(card: card, reveal: model.reveal, focus: $focus)
                    .id(card.card.id)
                    .transition(.opacity)
            }

        case .answer:
            if let card = model.card {
                AnswerFace(card: card, focus: $focus)
                    .id(card.card.id)
                    .transition(.opacity)
            }

        case .done:
            DoneFace(nextReview: model.nextReviewText)
                .transition(.opacity)
        }
    }

    /// The bottom bar's inset: the system's side margin, a small gap above, and the
    /// drill's background behind, so the card never shows through.
    private func bar(_ content: some View) -> some View {
        content
            .padding(.horizontal)
            .padding(.top, DesignTokens.Spacing.medium)
            .padding(.bottom, DesignTokens.Spacing.small)
            .background(ColorRoles.background)
    }
}
