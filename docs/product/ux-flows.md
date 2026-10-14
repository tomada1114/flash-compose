# FlashCompose — Screens and Flows

- **Status:** Settled 2026-10-13 (kickoff)
- **Platform:** iPhone only, portrait only, iOS 27 (SwiftUI on `tomada1114/ios-template`).
- **Input:** [requirements.md](requirements.md), signed off 2026-10-13. Section numbers
  (§3.2 …) refer to it.
- **App-wide behavior** — errors, feedback, motion, wording, accessibility targets — is
  in [ux-guidelines.md](../design/ux-guidelines.md) and is cited here, not restated.
- Labels are drawn in Japanese, the UI language `ux-guidelines.md` settles. Sizes are
  for a 375-point-wide iPhone at the default text size; every text uses a system text
  style and grows with Dynamic Type.

## 1. Screen inventory

| # | Screen or state | Serves | Presentation |
|---|---|---|---|
| D1 | Drill — question | §3.2 | The root screen; the app opens on it |
| D2 | Drill — answer | §3.2, §3.3 | The same screen after the reveal |
| D3 | Drill — done for today | §3.5 | The same screen when nothing is left |
| S1 | Scope sheet | §3.4 | A sheet over the drill |
| E1 | Could not open the data | §3.1, §3.6 | Replaces the drill at launch |
| E2 | Could not save an answer | §3.6 | An alert over D2 |

There is no home screen, settings screen, tab bar, or onboarding (§3.2 Edge Cases). The
system launch screen covers the start-up until D1 is ready (§4: first card within 1
second of a cold launch), so there is no loading screen of the app's own.

## 2. The drill header (D1, D2, D3)

The three counts and the scope button sit above the card on every drill state.

```
┌─────────────────────────────────────┐
│ 新規 1820 › 復習 12 › もう一度 0  [⚲] │  ← counts; [⚲] = 出題範囲 (scope) button
│             ‾‾‾‾‾‾                  │  ← underline: the pile the card on screen came from
├─────────────────────────────────────┤
```

| Count | What it counts | Changes when |
|---|---|---|
| 新規 | Never-seen cards in the current scope (§3.4), the card on screen included | A new card gets its first grade: −1. The scope changes: recounted |
| 復習 | Reviews due today in every topic and level not yet answered today, the card on screen included | A due review gets its first grade of the day: −1. 04:00 passes: recounted |
| もう一度 | Cards waiting for a re-ask in this session, the card on screen included when it is a re-ask | A grade schedules a re-ask (×, △, or a new card's first ○): +1. A re-ask is shown and graded without scheduling another: −1. A relaunch: 0 |

- The counts read left to right in the order a card travels: it is dealt from 新規 or
  復習, moves into もう一度 when it must come back, and leaves when it no longer must.
- The underline marks which count the card on screen belongs to; on D3 there is none.
- At the first card of a session, もう一度 is 0.
- The scope button is a toolbar item at the top trailing edge — the hard-to-reach zone
  suits an action used rarely. It opens S1.
- At accessibility text sizes the counts may wrap to a second line; they never truncate
  a number.

## 3. Wireframes

### D1 — Drill: question

```
┌─────────────────────────────────────┐
│ 新規 1820 › 復習 12 › もう一度 0  [⚲] │
│             ‾‾‾‾‾‾                  │
├─────────────────────────────────────┤
│                                     │
│  復習 · 仕事 · L5                    │  ← kind · topic · level (.footnote, secondary)
│                                     │
│                                     │
│                                     │
│      我々は先に論点を整理すべき。          │  ← ja, .title2, centered, wraps
│                                     │
│                                     │
│                                     │
│   (tapping anywhere here reveals)   │
│                                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │           答えを見る              │ │  ← prominent button, bottom (thumb zone)
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

- **Kind label:** `新規` for a card never seen, `復習` for a due review, `もう一度` with a
  return-arrow symbol for a re-ask. Topic is the topic's Japanese name; level is `L1`–`L10`.
- **Reveal:** the bottom button, or a tap anywhere on the card area. VoiceOver reaches it
  as one button, 答えを見る.
- No grade is possible from D1 (§3.2).

Variants:

```
新規 · 旅行 · L2                       ↩ もう一度 · 仕事 · L5
  (underline under 新規)                 (underline under もう一度)
```

### D2 — Drill: answer

```
┌─────────────────────────────────────┐
│ 新規 1820 › 復習 12 › もう一度 0  [⚲] │
│             ‾‾‾‾‾‾                  │
├─────────────────────────────────────┤
│  復習 · 仕事 · L5                    │
│  我々は先に論点を整理すべき。              │  ← ja again, .body, secondary
│ ─────────────────────────────────── │
│                                     │
│  We should clarify the issues       │  ← en, .title3, primary
│  first.                             │
│                                     │
│  別解                                │  ← .footnote, secondary
│  · We ought to clarify the issues   │  ← alternatives, .body, one per line
│    first.                           │
│  · We should sort out the points    │
│    first.                           │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 💡 clarify は曖昧な論点を明確にする。  │ │  ← point, .callout, in a grouped box
│ └─────────────────────────────────┘ │
│        (scrolls if it overflows)    │
├─────────────────────────────────────┤
│ ┌──────────┐┌──────────┐┌──────────┐│
│ │    ×     ││    △     ││    ○     ││  ← three equal buttons, bottom
│ │  忘れた   ││   微妙    ││  覚えてた  ││
│ │   1日    ││   3日    ││   8日    ││  ← days until the card is due (§3.3)
│ └──────────┘└──────────┘└──────────┘│
└─────────────────────────────────────┘
```

- **Order:** × left, ○ right — as in the old app, where ← graded again and → good.
- **Interval labels:** the days each grade would set if this answer moves the schedule:
  `1日`–`29日`; from 30 days `約Nか月` (N = days ÷ 30, rounded); 365 days `約1年`. A
  re-ask never moves the schedule (§3.3), so on a re-ask and on any card already
  answered today the labels are left out.
- **After a grade:** the card is saved and the next card's D1 appears (motion per
  ux-guidelines.md). If the save fails, E2.
- The answer area scrolls; the grade buttons stay pinned at the bottom. The longest
  card in the set — `c_4m6f2p9m` (L10): a 56-character answer, three alternatives, and a
  point — is the layout's stress case; the example above is `c_2t5h9y9g` (仕事, L5).
- The reveal and the buttons share the bottom position, so the thumb stays where it is
  through reveal → grade → reveal.

Accessibility-size variant (text at the largest accessibility sizes): the grade buttons
stack, in the same order, and the answer area scrolls above them.

```
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ ×  忘れた                1日     │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ △  微妙                  3日     │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ ○  覚えてた               8日     │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### D3 — Drill: done for today

```
┌─────────────────────────────────────┐
│ 新規 0 › 復習 0 › もう一度 0      [⚲] │  ← no underline
├─────────────────────────────────────┤
│                                     │
│                                     │
│                 ✓                   │
│                                     │
│           今日の分は完了               │  ← .title3
│                                     │
│       次の復習：10月15日（水）           │  ← the earliest due day over all cards
│                                     │
│     範囲外の未出題カード：1,402枚        │  ← never-seen cards outside the scope
│                                     │
│                                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │          範囲を変える…             │ │  ← opens S1
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

- When every card in the catalog has been seen, the outside-scope line is left out and
  the button stays (changing the scope cannot resume the drill then; the line about the
  next review says when it resumes).
- The next-review line names a weekday and, for tomorrow, says `明日（木）`.
- D3 is re-checked when the app returns to the foreground and when 04:00 passes; due
  reviews then turn it back into D1 (flow F5).

### S1 — Scope sheet

```
┌─────────────────────────────────────┐
│  出題範囲                       完了   │  ← sheet title; 完了 closes
├─────────────────────────────────────┤
│  新規カードの出題範囲。                  │  ← header note (.footnote, secondary)
│  復習は範囲に関係なく出題。                │
│                                     │
│  トピック                             │
│ ┌─────────────────────────────────┐ │
│ │ 日常                         ✓  │ │
│ │ 雑談・人付き合い                  ✓  │ │
│ │ 仕事                         ✓  │ │
│ │ 旅行                            │ │
│ │ IT・技術                      ✓  │ │
│ └─────────────────────────────────┘ │
│                                     │
│  レベル                              │
│ ┌─────────────────────────────────┐ │
│ │ L1   TOEIC 300               ✓  │ │
│ │ L2   TOEIC 400               ✓  │ │
│ │ L3   TOEIC 500                  │ │
│ │ …                               │ │
│ │ L10  TOEIC 990+                 │ │
│ └─────────────────────────────────┘ │
│  1つ以上を選択                         │  ← shown under a section with one row left
├─────────────────────────────────────┤
│        この範囲の未出題：412枚           │  ← live count, pinned at the bottom
└─────────────────────────────────────┘
```

- **Rows:** a tap toggles the checkmark. Topic rows use the Japanese names in
  `content/taxonomy.json`'s order; level rows show `L<n>` and the TOEIC score from
  `content/levels.json` — TOEIC only for now (choosing which scale to show is Later).
- **The last row on** in a section is disabled, with the note `1つ以上を選択`
  under that section (§3.4).
- **Applies at once:** each tap is saved and recounts the live count; the next new card
  comes from it. There is no Cancel — the sheet closes with 完了, a swipe down, or the
  system's dismissal, all the same.
- **Count:** never-seen cards matching the topics and levels on. At 0 the line reads
  `この範囲は全カード出題済み`; the sheet still closes, and the drill carries on with
  reviews, then D3.
- Opened at its large height; it scrolls at accessibility text sizes, the count staying
  pinned.

### E1 — Could not open the data

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│                 ⚠                   │
│                                     │
│          データを開けません             │  ← .title3
│                                     │
│   カードまたは学習記録の読み込みに失敗      │  ← .body, secondary; what failed,
│                                     │     no error codes or file paths
│                                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │             再試行                │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

- Shown instead of D1 when the bundled catalog cannot be read or the progress store
  cannot be opened. 再試行 repeats the start-up; the drill appears if it succeeds.
- Nothing is deleted or reset to recover; the wording follows ux-guidelines.md.

### E2 — Could not save an answer

```
┌─────────────────────────────────────┐
│  (D2 dimmed behind)                 │
│   ┌─────────────────────────────┐   │
│   │       回答の保存に失敗           │   │
│   │                             │   │
│   │    もう一度評価をタップ           │   │
│   ├─────────────────────────────┤   │
│   │            OK               │   │
│   └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

- Presented from the app's root, as the template presents every failure
  (`FailureAlert`), so it shows whatever is on top.
- After OK, D2 stays with the same card; the grade was not recorded, the schedule did
  not move, and the counts did not change. Grading again retries.

## 4. Flows

### F1 — Drill one card (the core interaction)

1. D1 shows the next card; the underline marks its pile.
2. The learner says the English, then taps 答えを見る or the card.
3. D2 shows the answer, the alternatives, the point, and the three grades with their
   intervals.
4. The learner taps ×, △, or ○.
5. The answer is logged; on the card's first answer of the day the schedule moves
   (§3.3); a re-ask is set when the grade calls for one (§3.2).
6. The counts update; D1 shows the next card. If nothing is left, D3 (F4).

```
[D1 question] -> (reveal) -> [D2 answer] -> (grade) -> [save] -> [D1 next card]
                                                         |            |
                                                         |       (nothing left)
                                                         v            v
                                                   [E2 alert]     [D3 done]
                                                         |
                                                    (OK) v
                                              [D2 same card, grade again]
```

### F2 — A card comes back in the same session

1. On D2 the learner grades a card × (or △; or ○ on a new card's first answer).
2. もう一度 goes up by one; the card waits behind 4 other cards for ×, 8 for △, 12 for
   a new card's first ○ (§3.2).
3. When its turn comes, D1 shows it with `↩ もう一度`, the underline under もう一度.
4. On D2 the grade buttons show no intervals (a re-ask does not move the schedule).
5. ○ ends it and もう一度 goes down; × or △ queues it again, up to 10 re-asks per card.
6. When no first-time card is left, waiting re-asks come one after another without the
   wait, never the same card twice in a row while another waits.

```
[D2] --(×/△, or new card's first ○)--> [もう一度 +1] --(after N cards)--> [D1 ↩もう一度]
                                                                             |
                                                                   (reveal)  v
                                         [もう一度 −1] <--(○)-- [D2, no intervals]
                                                                  |
                                                        (×/△, < 10 re-asks)
                                                                  v
                                                        [wait again]
```

### F3 — Change the scope

1. The learner taps [⚲] on any drill state; S1 opens.
2. Each tap on a topic or level row toggles it, is saved, and recounts the live count.
   The last row on in a section cannot be turned off.
3. The learner closes S1 (完了, swipe, system).
4. The card on screen stays. 新規 is recounted; the next new card comes from the new
   scope. 復習 and もう一度 do not change.
5. If S1 was opened from D3 and the new scope has never-seen cards, D3 turns into D1
   with a new card at once.

```
[D1/D2/D3] -> (⚲) -> [S1] -> (toggle rows; live count) -> (close) -> [drill, 新規 recounted]
                                                                          |
                                                    (from D3, scope has new cards)
                                                                          v
                                                                  [D1 new card]
```

### F4 — Reach the end of the day

1. The learner grades the last card: no review is due, the scope has no never-seen
   card, and no re-ask waits (§3.5).
2. D3 shows the next review day and the never-seen count outside the scope.
3. Either the learner widens the scope (F3 → D1), or leaves the app.

### F5 — Come back after the end of the day

1. The app returns to the foreground (or stays open across 04:00).
2. D3 re-checks: if 04:00 has passed and reviews are due, D1 shows the first of them.
3. Otherwise D3 stays as it was.

### F6 — Cold launch

1. The system launch screen shows while the catalog and the progress store open.
2. D1 shows the first card: the least likely remembered due review, or a random new
   card in scope (§3.2). もう一度 is 0 — waiting re-asks do not survive a relaunch.
3. If nothing is left, D3. If the data cannot be opened, E1 → 再試行 → step 1.

```
[launch screen] -> (catalog + store open) -> [D1 first card] / [D3 done]
        |
   (open fails)
        v
      [E1] -> (再試行) -> [launch]
```

### F7 — 04:00 passes during a session

1. The learner is drilling at 03:58; the practice day is yesterday's.
2. 04:00 passes. The card on screen keeps its kind and its intervals; its grade counts
   for the day it is graded on (§4).
3. From the next card, the queue is today's: 復習 is recounted with the reviews due
   today; cards answered before 04:00 can be due again.
4. A re-ask waiting from before 04:00 still comes back as a re-ask and does not move the
   schedule (§3.3).

## 5. Cross-cutting behavior per screen

`ux-guidelines.md` holds the rules; this table points each screen at its sections.

| Screen | Sections of ux-guidelines.md |
|---|---|
| D1, D2 | Feedback and loading (save then advance, double taps, haptic); Motion (card change, reveal, counts); Language and copy (glossary, interval labels); Accessibility targets (VoiceOver order and focus, grade buttons' names, Dynamic Type) |
| D3 | States (done for today); Language and copy (dates, tomorrow) |
| S1 | States (scope matches no never-seen card); Navigation (closing the sheet); Accessibility targets (Dynamic Type) |
| E1 | States (data could not be opened); Language and copy |
| E2 | States (an answer could not be saved); Feedback and loading (error placement) |
| Start-up | States (start-up: indicator thresholds) |
