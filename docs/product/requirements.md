# FlashCompose — Requirements

- **Status:** Signed off 2026-10-13
- **Platform and stack:** an iPhone app for iOS 27 or later, built on
  `tomada1114/ios-template`: SwiftUI, an XcodeGen project, all code in the local package
  `FlashComposeKit` (Core / UI / Platform), SwiftData behind a Core port, Swift 6, and the
  template's gates. Local only: no server, no account, no network access. Installed on
  the owner's own iPhone from Xcode (`just run-device`).

## 1. Overview

- **What it is:** a 瞬間英作文 (instant English composition) drill. The app shows a short
  Japanese sentence; the learner says the English out loud or in their head, taps to see
  the model answer with its alternatives and a one-line point, and grades themselves
  ×忘れた / △微妙 / ○覚えてた. An FSRS-6 scheduler decides when each card comes back. The
  drill keeps going until the learner stops, introducing new cards from the topics and
  levels they chose.
- **Who it is for:** its owner, a Japanese speaker practising spoken English. Single
  user, one iPhone, no accounts.
- **Why a new app:** the owner's earlier web app,
  [`instant-composition`](https://github.com/tomada1114/instant-composition), grew into a
  full service — sign-in, an AWS backend, LLM conversation, vocabulary decks, daily
  quotas and settings. Its 1,952 reviewed cards and its review logic are the valuable
  part. This app keeps only those, on the phone, offline. The web app is retired: from
  now on this repository is the cards' only home.
- **Core interaction:** see the Japanese → say the English → reveal → grade with one tap
  → the next card. If this loop is not quick and pleasant, nothing else matters.
- **First version is a success when:** on the owner's iPhone, the app drills without
  end — every due review first, then new cards from the chosen scope — schedules every
  graded card by FSRS-6 so it comes back on the right day across launches, and stops
  only when nothing is due and the scope has no new card left.

## 2. Scope

### MVP
- **Card catalog** — the 1,952 cards ship inside the app, read-only, with every field
  the old repository has, typed (§3.1). The drill needs something to show.
- **Drill** — prompt, reveal, three grades, next card; due reviews first, then new
  cards at random; in-session re-asks (§3.2). This is the core interaction.
- **Scheduling** — the old app's FSRS-6, its 04:00 day boundary, and its rule that only
  a card's first answer of a day moves its schedule (§3.3). Without it the drill is a
  shuffle, not practice.
- **Scope selection** — the learner chooses which of the 5 topics and which of the 10
  levels new cards come from (§3.4). The owner chose to have it in the first version.
- **End of the day's practice** — what the drill shows when nothing is due and the
  scope has no new card left (§3.5).
- **Progress kept across launches** — each card's schedule survives quitting the app
  and rebooting the phone, and every answer is kept in a log (§3.6).

### Later
- **Subtopic selection** — the 37 subtopics are kept on every card from day one; only
  the UI waits. The owner chose topics only for the first version.
- **Grammar-tag filter** — the 39 tags are kept on every card from day one; only the UI
  waits.
- **Adaptive level** — the old app's placement test and automatic level up/down, with
  new cards drawn from a band around the level. Waits because manual level selection
  covers the need first.
- **Daily goals and limits** — new-card and review quotas, a settings screen. The owner
  wants an endless drill first.
- **Per-card timer** and "fast" answers. Pulled forward if the drill feels too relaxed
  to be 瞬間.
- **Text-to-speech** of the model answer.
- **Statistics** — streaks, counts, a calendar, mastery.
- **Vocabulary cards** — the old repository's 340 word, idiom, phrasal-verb, and
  phrase cards.
- **Practise ahead** — cards not yet due, once the scope is done for the day.
- **iCloud sync** between devices.
- **Reminders** — a daily notification (a privacy-gated permission).
- **Review focus switch** — let the scope limit due reviews too, for cramming one topic
  (say, before a trip). Left out because, switched on, it hides reviews until their
  topic is chosen again and then releases them all at once. Adding it later is one
  condition in the queue and one stored setting; nothing stored has to migrate.
- **Undoing a grade** — the owner chose to let a grade tapped by mistake stand for now. The
  answer log keeps the state needed to add it.
- **Hiding a card** ("もう出さない"), with a list to bring hidden cards back. The cards are
  reviewed, so a bad one is rare.
- **Card browser and search; favourites.**

### Non-goals
- **Accounts, sign-in, any server, any network access** — the app is one person's, on
  one phone.
- **LLM features** — no conversation, no answer checking, no card generation.
- **Typed or spoken answers checked by the app** — the learner grades themselves; that
  is the method.
- **Adding, editing, or deleting cards in the app** — cards are edited in this
  repository and ship with the app.
- **Importing progress from the web app** — the iPhone app starts fresh.
- **Resetting progress from inside the app** — deleting the app resets it.
- **Tooling from the old repository** — its card lint, LLM review stamps, statistics
  scripts, and vocabulary pipeline stay behind.
- **iPad layouts** — iPhone only; on an iPad it runs as an iPhone app.
- **TestFlight or App Store distribution** in this version — and so no store listing,
  privacy policy page, or onboarding written for strangers.
- **Analytics, crash reporting to a third party, ads, payments.**

## 3. Features

### 3.1 Card catalog

#### Overview
- **Purpose:** the material the drill shows.
- **Access:** not a screen; loaded when the app starts.

#### Specifications

| Item | Specification |
|------|---------------|
| Source | `instant-composition` `content/cards/<topic>/<subtopic>.json` (1,952 cards, 37 files) plus `content/taxonomy.json`, `content/levels.json`, `content/grammar.json`, copied once. From then on this repository is the cards' only home; the old repository is not used again |
| Format | Free to change: JSON, a database file, or anything Swift-native — `docs/architecture.md` records the choice. What the format must allow: the catalog ships inside the app, and an app update can add, fix, or remove cards without migrating the learner's progress |
| Where it lives | Read-only, inside the app. The learner's progress lives apart from it (§3.6) |
| Card fields | `id` (e.g. `c_2a5d9v8h`), `ja` (prompt, ≤ 20 chars in the current set), `en` (model answer, ≤ 70 chars), `alternatives` (2–3 other answers), `point` (a one-line explanation in Japanese, ≤ 60 chars), `topic`, `subtopic`, `level` (1–10), `grammar` (tag ids) |
| Fields not used | `createdAt`, `stamps` (the old authoring pipeline's review hashes) |
| Definitions | 5 topics and 37 subtopics with Japanese names; 10 levels with TOEIC/CEFR hints and a Japanese summary; 39 grammar tags with Japanese names |
| Integrity | A test holds every card to the definitions: a known topic and subtopic, a level 1–10, known grammar tags, a unique id, non-empty `ja`, `en`, and `point`, and at least one alternative |
| Identity | A card's `id` is the key its progress is stored under. The old repository's rule (`content/guides/identity.md`) comes along: a fix that keeps the question keeps the id; a change that makes earlier answers incomparable gets a new id, and an id is never reused. The ids of cards already retired there (`content/tombstones.jsonl`) come along too, so a new card cannot take one |

#### Edge Cases
- **A card dropped by a later catalog update:** its stored progress is ignored and the
  card is never shown again.
- **A card replaced by a new id:** the new card starts as new; the old card's progress
  is ignored.

### 3.2 Drill

#### Overview
- **Purpose:** the core interaction — one card at a time, self-graded.
- **Access:** what the app opens to.

#### Specifications

| Item | Specification |
|------|---------------|
| Front | The Japanese prompt (`ja`), and, set small, whether the card is new, a due review, or a re-ask, with its topic and level — so a review from outside the scope explains itself |
| Reveal | One tap shows the back; grading is not possible before it |
| Back | The model answer (`en`), its alternatives, and the point |
| Grades | × 忘れた (again), △ 微妙 (hard), ○ 覚えてた (good). No "easy" grade, as in the old app |
| After a grade | The next card appears at once |
| Order | Due reviews first — from every topic and level, whatever the scope — the least likely remembered first (lowest FSRS retrievability); then new cards from the scope, uniformly at random. A card answered today is not dealt again, except as a re-ask |
| Re-asks | Within the session a card comes back after other cards: after 4 when graded ×, after 8 when graded △, and after 12 when a new card gets its first ○. At most 10 re-asks per card per session. When no first-time card is left, waiting re-asks come straight away, in the order they fell due, never the card just shown while another waits |
| Re-asks and the schedule | A re-ask never moves the card's schedule (§3.3) |
| Session end | There is no end: the drill continues until the learner leaves it, or until §3.5 applies. Leaving the app keeps the session in memory while iOS keeps the app alive; a relaunch drops waiting re-asks |

#### Edge Cases
- **First launch:** no progress yet, so the drill opens on a new card from the default
  scope (everything). No onboarding.
- **The scope has no never-seen card left:** due reviews still come; after them, §3.5.
- **The scope changes mid-session:** the next new card comes from the new scope; due
  reviews and waiting re-asks are unaffected.

### 3.3 Scheduling

#### Overview
- **Purpose:** decide when each graded card is due again.
- **Access:** not a screen.

#### Specifications

| Item | Specification |
|------|---------------|
| Algorithm | FSRS-6 long-term scheduler, the old app's port of ts-fsrs 5.4.2, with the same results for the same inputs (the old repository's golden vectors) |
| Grades | again 1, hard 2, good 3 |
| Parameters | ts-fsrs's 21 default weights, desired retention 0.9, longest interval 365 days, interval fuzz seeded by card id and repetition count |
| Practice day | Runs from 04:00 to 03:59 local time; an answer at 01:30 belongs to the day before. Intervals count practice days, not hours |
| What moves a card | Only its first answer of a practice day, and never a re-ask — not even a re-ask shown after 04:00 has started a new day. A card whose last moving answer was before today, and which is due, is dealt as a review |
| Shortest interval | 1 practice day, so a card graded × today is due tomorrow at the earliest; today it returns only as a re-ask |

### 3.4 Scope selection

#### Overview
- **Purpose:** choose which cards the drill introduces.
- **Access:** a filter over the one drill, opened from the drill screen. The app always
  opens straight into the drill; there is no home screen or category list. Layout is the
  UX stage's.

#### Specifications

| Item | Specification |
|------|---------------|
| Topics | The 5 topics — 日常, 雑談・人付き合い, 仕事, 旅行, IT・技術 — each on or off. Subtopics are not selectable in this version |
| Levels | L1 to L10, each on or off; any combination, not only a contiguous range |
| Match | A card is in scope when its topic is on **and** its level is on |
| What the scope limits | New cards only. Due reviews always come from every topic and level, so changing the scope never hides a review or releases a backlog |
| Default | Every topic and every level on |
| At least one | The last topic and the last level that are on cannot be turned off |
| Count | The screen shows how many never-seen cards the current choice matches |
| Kept | Across launches, until changed |
| Takes effect | From the next card dealt. Waiting re-asks stay in the session whatever the scope |

### 3.5 End of the day's practice

#### Overview
- **Purpose:** say clearly that nothing is left today, instead of an empty card.

#### Specifications

| Item | Specification |
|------|---------------|
| When | No review is due today in any topic or level, the scope has no never-seen card left, and no re-ask is waiting |
| Shows | That today's practice is done, and the day the next review is due |
| Offers | A way to change the scope, with how many never-seen cards the topics and levels outside it still hold |
| Leaving it | Changing the scope to one with never-seen cards resumes the drill at once; otherwise the screen stays until the next practice day, when due reviews resume it |

With 1,952 cards and no limit on new cards, this practically happens only with a narrow
scope (旅行 × L1 holds 33 cards) or after the whole catalog has been introduced. What a
heavy day actually changes is the next day's review load — and since reviews come first,
the drill regulates itself.

### 3.6 Progress kept across launches

| Item | Specification |
|------|---------------|
| Stored per card | Its FSRS state: stability, difficulty, repetitions, lapses, last practice day, due day — keyed by card id |
| Answer log | One entry per grade, re-asks included, never edited: card id, when it was graded, its practice day, the grade, whether it was the day's first answer (the one that moved the schedule) or a re-ask, the card's FSRS state before and after, and how long the card was on screen before the reveal. Nothing in the first version reads it back except the tests; it is kept because a log cannot be rebuilt later — for statistics, undo, or tuning FSRS to the learner |
| Grades are final | A grade tapped by mistake stands; there is no undo |
| Stored once | The chosen scope (§3.4) |
| Where | On the device only. iOS device backups include it; nothing else copies it |
| Uninstall | Deletes all progress and the log; there is no export |

## 4. Cross-cutting rules

- **Time:** the practice day follows the phone's current time zone at the moment of
  each answer. If 04:00 passes during a session, the next card is dealt for the new
  day.
- **Speed:** on the owner's iPhone the first card is on screen within 1
  second of a cold launch, and the next card appears with no visible loading after a
  grade.
- **Data:** nothing leaves the phone.
- **Licensing:** the FSRS code keeps ts-fsrs's MIT notice, as the old port did.
- **Errors, feedback, accessibility, wording:** the UX stage owns them.

## 5. Data

| Entity | Fields | Where | Kept |
|------|---------------|---|---|
| Card | §3.1 | Bundled, read-only | As long as the app version ships it |
| Card progress | card id, stability, difficulty, reps, lapses, last day, due day | On-device store | Until uninstall |
| Answer | card id, graded at, practice day, grade, first-of-day or re-ask, FSRS state before and after, time to reveal | On-device store, append-only | Until uninstall |
| Scope | topics on (subset of 5), levels on (subset of 1–10) | On-device preferences | Until changed or uninstall |
| Retired card ids | ids no new card may take | With the catalog | Always |

## 6. Open questions

- The catalog's format and how cards are edited in this repository from now on — recorded in
  `docs/architecture.md`, within §3.1's constraint.
- How often a build installed from Xcode must be reinstalled depends on whether the
  owner's Apple account is in the paid Developer Program — the distribution decision in
  `docs/architecture.md` checks the current limit against Apple's documentation.

## 7. Decision log

- 2026-10-13 Topic/subtopic and level selection are in the first version (rejected:
  typed data only with the UI deferred, because the owner wants to use them now; level
  selection only).
- 2026-10-13 Name FlashCompose, repository `flash-compose` (rejected: Shunkan;
  InstantComposition).
- 2026-10-13 For the owner only, installed from Xcode onto their iPhone (rejected:
  TestFlight; App Store, because each adds distribution work to the first version).
- 2026-10-13 iPhone only (rejected: iPhone and iPad, because one family's layouts are
  enough for one person's phone).
- 2026-10-13 The scope is a filter over one drill that the app opens straight into
  (rejected: a home screen listing categories, each starting its own drill, because it
  adds a screen and a tap before every session).
- 2026-10-13 Topics only — the 5 topics — are selectable (rejected: topics with their 37
  subtopics). Subtopics stay on every card for later.
- 2026-10-13 Levels are toggled one by one, L1–L10, any combination (rejected: a
  contiguous lower–upper range; one "my level" with a band around it).
- 2026-10-13 The scope limits new cards only; due reviews always come from everything
  (rejected: the scope limits reviews too, because changing it would hide reviews and
  later release them in a burst; a switch between the two, because switched on it brings
  both problems back — Later if a cramming need appears).
- 2026-10-13 Every answer is logged, and grades are final (rejected: the log with
  one-step undo — the recommendation; per-card state only, because a log cannot be
  rebuilt later).
- 2026-10-13 No hiding of cards in the first version (rejected: hide with a list to
  restore, because it adds a screen for a rare need).
- 2026-10-13 This repository is the cards' only home from now on; the format may change
  (rejected: keep authoring in `instant-composition` and re-import; copy as-is and decide
  later). The owner retires the old repository.
- 2026-10-13 Carried over from the old app, open to objection: FSRS-6 with three grades,
  the 04:00 day, first-answer-of-the-day scheduling, re-asks (4 / 8 / 12, at most 10),
  reviews before new cards, new cards at random (the owner's request).
- 2026-10-13 Sign-off accepted four proposals as written: the last topic and the last
  level stay on; the log records time to reveal; the first card within 1 second of a
  cold launch with no visible loading between cards; the card front marks new, review,
  or re-ask with its topic and level.
- 2026-10-13 (after sign-off, from the UX stage) The UI is in Japanese — a translation
  of the template's English source that follows the device language — and copy is
  terse (noun endings over です・ます); see `ux-guidelines.md`.
- 2026-10-13 (owner) No ADRs: decisions are written as the present state of the design
  docs, and git holds their history (rejected: an ADR per hard-to-reverse choice,
  because it makes changing a feature costly).
