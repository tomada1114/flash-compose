# UX guidelines

| | |
|---|---|
| Product | FlashCompose — a 瞬間英作文 drill for one learner |
| Platforms | iOS 27, iPhone only, portrait only (SwiftUI on `tomada1114/ios-template`) |
| App type | Learning / education — a spaced-repetition flashcard drill |
| Related | Requirements: [requirements.md](../product/requirements.md) · UX flows: [ux-flows.md](../product/ux-flows.md) (screens D1–D3, S1, E1, E2; flows F1–F7) · Design direction: [design-direction.md](design-direction.md) |

Status: settled 2026-10-13 (kickoff). Screens and their layouts are in `ux-flows.md`;
this document holds only the rules every screen follows.

## Principles

- **The thumb never moves.** Reveal and the three grades share the bottom of the screen;
  nothing in the card loop needs the top. Decides: per-card actions live at the bottom,
  rare ones (the scope) at the top trailing edge; no per-card menu. Gives up: room for
  more per-card actions (bookmarking, hiding) without redesigning the bottom bar.
- **The schedule is the app's job.** Beyond the scope, the learner chooses nothing:
  no skip, no study-ahead, no goal, no settings. Decides: every "what comes next" is
  Core's queue (requirements §3.2). Gives up: the control an Anki power user expects.
- **Quiet by default.** Restrained motion, one light haptic, no sound, no celebration,
  no streak, no score. Decides: the end of the day (D3) is a calm statement with the next
  review day, not a reward screen. Gives up: gamified motivation.

## Navigation

- **Model:** one root screen, the drill (D1–D3), in the template's single
  `NavigationStack`; the scope is a sheet (S1). No tabs, no pushed screens. Why: there is
  one core interaction and one rarely used control (rejected: a home screen, in
  requirements' decision log).
- **Back:** nothing to go back to. S1 closes with 完了, a swipe down, or the system's
  dismissal, all the same; its changes are already saved (ux-flows S1).
- **Deep links:** none of the app's own. The template's URL scheme opens the app on the
  drill.

## Platform conventions

- **iOS:**
  - Portrait only; iPhone only. Safe areas respected; the bottom bar (reveal, grades)
    is a `safeAreaInset(edge: .bottom)`.
  - Toolbar items use the system placements, so they take Liquid Glass and stay where
    the OS puts them. The scope button is a symbol-only toolbar item with the
    accessible name 出題範囲.
  - No custom gestures: no swipe-to-grade, no long-press menus. Every action is a
    visible button.
  - Auto-lock stays the system's: the idle timer is never disabled. Why: the drill is
    self-paced, and a phone left on the table should lock.
  - The session lives in memory while iOS keeps the app alive; returning to the app
    shows the same card on the same face. A relaunch starts a new session (waiting
    re-asks are dropped, requirements §3.2).
  - No hardware-keyboard shortcuts in this version (the old web app's grade keys stay
    behind).

## States

| State | Trigger | Shows | Primary action | Copy pattern (ja / en) |
|---|---|---|---|---|
| First run | No progress yet | D1 with a new card — no empty state, no onboarding | 答えを見る | — |
| Scope has no new card, reviews remain | §3.5 not yet met | The drill carries on with reviews; nothing announces it | — | — |
| Done for today | requirements §3.5 | D3 | 範囲を変える… | 「今日の分は完了」「次の復習：{日付}」「範囲外の未出題カード：{n}枚」 / "Done for today" "Next review: {date}" "Unseen outside the scope: {n}" |
| Scope matches no never-seen card | S1's count is 0 | The count line's text changes; the sheet still closes | — | 「この範囲は全カード出題済み」 / "Every card in this scope shown" |
| Start-up | Cold launch | The system launch screen; then the root view's plain background with no indicator; a centred system `ProgressView` only if the drill is not ready 300 ms after the first frame, kept at least 500 ms once shown | — | — |
| Data could not be opened | The bundled catalog cannot be read, or the progress store cannot be opened | E1, full screen, instead of the drill | 再試行 | 「データを開けません」「カードまたは学習記録の読み込みに失敗」 / "Can't open the data" "Couldn't load the cards or your progress" (button "Try Again") |
| An answer could not be saved | Saving a grade throws | E2, an alert presented from the root (`FailureAlert`); D2 stays on the same card | OK | 「回答の保存に失敗」「もう一度評価をタップ」 / "Couldn't save your answer" "Tap a grade again" |

Not applicable, by the requirements' non-goals: offline (no network), permission denied
(no privacy-gated permission), signed-out and unauthorized (no accounts), no results
(no search).

## Feedback and loading

| Rule | Value |
|---|---|
| Saving a grade | Save, then advance: the next card appears when the local save has returned. Why: E2 must be able to leave the same card on screen with nothing recorded; a local save is far below what a person perceives (rejected: optimistic advance with a rollback, which would have to un-show a card) |
| Double taps | From the first tap on a grade until the next card is on screen, the three grade buttons ignore taps. The reveal button likewise ignores a second tap |
| Reveal | Immediate; the answer face replaces the question face (Motion below) |
| Haptic | One `.selection` haptic (`sensoryFeedback`) on every grade — the same for ×, △, and ○. Why: a grade is a choice, not a success or a failure; a distinct × haptic would read as a penalty. None on reveal, none in S1. The system's haptics switch is respected by `sensoryFeedback` itself |
| Sound | None. Why: the drill is used where sound is unwelcome (rejected: the old app's sound effects, which need assets and a silent-mode rule) |
| Counts | The header counts (ux-flows §2) change in the same frame as the card |
| Toasts | None in this app |
| Error placement | A failure at start-up → full screen (E1). A failure during the drill → the root alert (E2). There are no inline errors: the app has no form |
| Destructive actions | None exist: no delete, no reset (requirements' non-goals) |

## Motion

- **Amount:** restrained — the owner chose standard, low-movement transitions over a card
  that slides left to right.
- **Card change** (a grade → the next D1): a cross-fade.
- **Reveal** (D1 → D2): the answer area fades in; the prompt moves to its smaller place
  without a separate animation.
- **Counts:** the system numeric-text content transition on each changed number.
- **Durations:** none of the app's own. Every animation is
  `DesignTokens.Motion.animation(reduceMotion:)` — the system default — so the design
  lock decides motion personality in one place.
- **Reduce Motion:** that same call returns `nil`, so every state change above happens
  instantly; nothing a person needs is carried by motion alone.
- No flip, slide, parallax, confetti, or looping animation anywhere.

## Language and copy

- **UI languages:** English is the source language — keys and `defaultValue`s in code,
  as the template requires — with a Japanese translation in the String Catalog. The
  app follows the device's language, so the owner's iPhone shows Japanese. RTL: no.
  Japanese ships alongside English from the first version; `docs/architecture.md`
  states it as the present design (the app keeps no ADRs).
- **Card content is not UI text:** the prompt, the model answer, the alternatives, the
  point, and the topic names (from `content/taxonomy.json`) are shown verbatim
  (`Text(verbatim:)`) in either UI language. An English UI still shows Japanese topic
  names.
- **Text expansion:** the grade buttons must hold both "忘れた / 微妙 / 覚えてた" and
  "Forgot / Hard / Got it" side by side at the default text size; at accessibility sizes
  they stack (ux-flows D2).
- **Formatting:** dates through `Date.FormatStyle` in the current locale —
  `10月15日（水）` in Japanese, `Wed, Oct 15` in English; tomorrow reads `明日（木）` /
  `Tomorrow`. Counts with grouping separators (`1,402`). Interval labels come from one
  Core formatter: ja `1日`…`29日`, `約Nか月` from 30 days, `約1年` at 365; en `1 day`,
  `N days`, `≈N mo`, `≈1 yr`.
- **Register (ja):** short and plain by default — a noun-ending phrase (体言止め) or
  a fragment, not a sentence: 「今日の分は完了」「回答の保存に失敗」「1つ以上を選択」. です・ます
  only where a full sentence cannot be avoided (none in the first version's copy).
  Button labels are verbs in the dictionary form (答えを見る, 範囲を変える…, 再試行, 完了);
  the three grade labels are the learner's own words
  (忘れた, 微妙, 覚えてた), as in the old app. No exclamation marks, no emoji in UI copy.
- **Register (en):** sentence case, second person, no exclamation marks.
- **Ellipsis:** a button that opens more choices ends with … (範囲を変える…), the
  template's copy rule.

| Use | Don't use | For |
|---|---|---|
| 新規 / New | 未学習, 新出 | A card never seen |
| 復習 / Review | 学習済み, 期限切れ | A card due today |
| もう一度 / Again | ラーニング, 再学習, ミス | A card waiting for a re-ask in this session |
| 出題範囲 / Scope | フィルタ, 設定, デッキ | The topics and levels new cards come from |
| 評価 / grade | 正解, 不正解, 採点結果 | The learner's ×/△/○ — the app never judges an answer right or wrong |
| 忘れた・微妙・覚えてた / Forgot · Hard · Got it | 不正解・難しい・正解, Again · Hard · Good | The three grade buttons |

## Accessibility targets

| Target | This product |
|---|---|
| Level | WCAG 2.2 AA as it applies to a native iOS app, plus the template's `designing-ui` rules (light and dark, Increase Contrast, 4.5:1 text) |
| Focus | Touch first. With a hardware keyboard (Full Keyboard Access) the system focus ring is used unchanged; no custom focus drawing |
| Minimum target size | 44×44 pt for every tappable element (`DesignTokens.Size.minimumHitTarget`); the grade buttons are as tall as their text needs, never under 44 pt |
| Dynamic Type | Every text is a text style; every screen is checked at `accessibility-extra-extra-extra-large`. The grade buttons stack at accessibility sizes; the answer area scrolls; the header counts wrap and never truncate a number |
| VoiceOver order | D1: the counts as one element ("新規 1,820、復習 12、もう一度 0。このカードは復習"), the kind label, the prompt, 答えを見る. D2: the model answer, the alternatives, the point, then the grades |
| VoiceOver focus | After the reveal, focus moves to the model answer, so it is read next. After a grade, focus moves to the new card's prompt |
| Grade buttons' names | The grade and the interval: "忘れた、次回1日後" / "Forgot, next in 1 day"; on a re-ask, the grade alone |
| Announcements | No live regions: there are no toasts; E2 is a system alert, which VoiceOver announces; count changes are read when the counts are focused |
| Color use | Never the only carrier: grades carry ×/△/○ and a word; the card's kind is a word (新規 / 復習 / もう一度); the underline under a count is also spoken ("このカードは復習") |
| Reduce Motion | See Motion |
| Contrast | Measured in [design-direction.md](design-direction.md)'s "Measured contrast" table |

Verification for the implementing session: a VoiceOver pass through F1 and F3; every
screen at `accessibility-extra-extra-extra-large`, in dark, and with Increase Contrast
(`running-the-app`); Reduce Motion on for F1.

## App-type rules

- **A miss explains itself and comes back:** the point says why; × sends the card to
  もう一度 rather than to a tally. Why: a running count of misses raises the cost of
  coming back (learning-app patterns).
- **No accuracy, streak, or score on screen** in this version. Why: progress is the
  three counts; statistics are Later.
- **Sessions have no length:** leaving at any moment loses nothing but waiting re-asks,
  by design (requirements §3.2).

## Reference products

| Product | Flow studied | Adopted | Rejected | Why |
|---|---|---|---|---|
| instant-composition (the owner's web app) | Its drill: flip, self-grade, re-asks, interval labels | Three grades and their words, re-ask timing, intervals on the grade buttons, the "again" mark on a re-ask | Timer, keyboard grade keys, daily quotas, sound effects | The owner asked for its core without its weight |
| Anki | New / Learning / Review counts with the current card's pile marked; intervals on the answer buttons | The three counts with an underline; intervals on the buttons | A fourth grade (Easy); deck options | The owner described the same counts; one learner needs no options |

## Non-goals

| Not doing | Why | Covered instead by |
|---|---|---|
| Swipe or long-press to grade | Invisible until discovered; three grades do not map to two directions | Three bottom buttons |
| Keyboard shortcuts | iPhone only | — |
| Sound effects | See Feedback | One haptic |
| A card flip or slide animation | The owner chose standard motion | Cross-fade |
| Celebration on finishing | Quiet by default | D3's calm statement |
| Onboarding or a tutorial | One owner who knows the method | — |
| Landscape, iPad layouts | Requirements | — |

## Decision log

| Date | Decided | Rejected options | Why |
|---|---|---|---|
| 2026-10-13 | Header shows 新規 › 復習 › もう一度, the card on screen counted in its pile and underlined (owner's description, confirmed with a mock-up) | Adding a fourth "done today" count; scope button only | The owner's own description; the order is the path a card travels |
| 2026-10-13 | Grade buttons show the interval each grade would set | Labels only | The old app showed them; they make a grade's weight visible |
| 2026-10-13 | Scope sheet lists levels one per row with the TOEIC score only | A 2×5 chip grid; CEFR/TOEFL/IELTS | TOEIC alone for now; choosing the scale per goal is Later (owner) |
| 2026-10-13 | Portrait only | Rotation | One layout for a one-question drill |
| 2026-10-13 | Standard, low-movement card transitions | Cards sliding left to right | Owner: the flow is about the counts, not the card's motion |
| 2026-10-13 | UI in Japanese via a translation of the English source; follows the device language | Japanese fixed regardless of device; English only | Template keeps English source; the owner's phone shows Japanese; English-only would put English buttons on Japanese cards |
| 2026-10-13 | One light `.selection` haptic on every grade; no sound | No feedback; haptic plus sound | Works in silence; a grade is not a success or failure |
| 2026-10-13 | です・ます sentences, verb buttons, self-talk grade labels | Casual throughout; polite throughout | The usual iOS register; polite grade labels would not fit three across |
| 2026-10-13 | Amended by the owner: plain and short by default — 体言止め or a fragment; です・ます only where a sentence is unavoidable; buttons stay verbs, grades stay self-talk | です・ます sentences throughout | The owner wants terse UI copy |
| 2026-10-13 | No ADRs in this app (owner); Japanese as a shipped language is stated as present state in `docs/architecture.md` | An ADR per decision | ADRs make change costly; the owner wants features easy to change |
| 2026-10-13 | Save then advance; grade buttons ignore taps until the next card | Optimistic advance with rollback | E2 must leave the same card with nothing recorded; local saves are imperceptible |
| 2026-10-13 | Competitor research skipped | A research pass | The owner's own web app and Anki already fix the flows; no remaining question hinged on a competitor |
