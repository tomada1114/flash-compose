# Roadmap

This page records the app's direction: the outcomes it is working toward now, the ones
that come next, and the ones only intended for later. It sits between two other homes
and repeats neither:

- `AGENTS.md`'s `## Product` says what the app is, its core interaction, and its
  non-goals. Nothing here contradicts a non-goal; moving one is the owner's call, made
  in that section first.
- The issue tracker holds the units of work, their priority tiers, and their `blocked:`
  and `on hold` labels (`triaging-issues`). This page links issues by number and never
  copies their bodies.

It records direction and authorizes nothing. An issue is implemented because it is
filed, tiered, and picked, never because a line here names it. It is not a design document
either: a design change a line depends on is written, in the present tense, into
`AGENTS.md`'s Architecture section and [`docs/architecture.md`](../architecture.md),
and linked from here. What has shipped is in
`CHANGELOG.md`, not on this page.

The owner decides what the page says; an agent proposes a change to it in a pull
request, and the change lands only once the owner has approved it.

- **Last reviewed:** 2026-10-13, at the kickoff, when the first issues were filed

## Now

The outcomes being worked on, one to three of them. Each has its issues filed.

- **Drill the whole catalog, scheduled by FSRS-6 across launches** — the core
  interaction; if this loop is not quick and quiet, nothing else matters. Issues: #3
  (tracking): #6, #12, #13, #14, #16, #18, #19, #22.
  Done when: on the owner's iPhone, installed with `just run-device`, the first card is
  on screen within a second of a cold launch; reveal and a one-tap grade go straight to
  the next card; due reviews come before new cards; and a card graded today comes back,
  after a relaunch, on the day its grade button showed.
- **Steer new cards by topic and level, and see when the day is done** — the owner
  wanted the scope in the first version. Issues: #4 (tracking): #15, #20. Done when:
  turning topics and levels on and off in the scope sheet changes the 新規 count and
  where the next new card comes from, survives a relaunch, and never hides a due review;
  and exhausting a narrow scope (旅行 × L1) shows 今日の分は完了 with the next review day.
- **The app is FlashCompose, not the template** — iPhone only and portrait, the Japanese
  UI, and the design lock, with the template's to-do and networking code gone. Issues:
  #5 (tracking): #7, #8, #9, #21. Done when: `just check` passes with no to-do or HTTP code left; on an iPhone set to
  Japanese every label is Japanese; and screenshots in light, dark, the largest text
  size, and Increase Contrast match the design lock.

## Next

The outcomes that follow once Now's are done. An issue may already exist for one, often
parked as `on hold`; none is required.

None yet, on purpose: the owner chooses what follows the first version after using it,
from the requests parked as `on hold` during daily use (`triaging-issues`' "Requests from
daily use"). The simulator CI jobs, paused until the first version is built, come back
on when Now's outcomes are done (#11, parked as `on hold`).

## Later

Direction the app intends to take but has not ordered. No issue is filed for a line
here, apart from a parked one that a line names.

- **Subtopic and grammar-tag filters** — the 37 subtopics and 39 tags are on every card
  already; brought forward when the five topics feel too coarse.
- **Adaptive level** — the old app's placement and automatic level changes, new cards
  drawn from a band around the level; when choosing levels by hand stops matching how
  the drill feels.
- **Daily goals and limits** — new-card and review quotas; if the endless drill turns
  the next day's reviews into a burden.
- **A per-card timer** and "fast" answers — if the drill feels too relaxed to be 瞬間.
- **Hearing the model answer** — the device's own text-to-speech; no network, no
  permission.
- **Statistics** — streaks, counts, a calendar, mastery; the answer log already holds
  what they need.
- **Vocabulary cards** — the old repository's 340 word, idiom, phrasal-verb, and phrase
  cards; when the sentence drill runs dry.
- **Practise ahead** — cards not yet due, once the scope is done for the day.
- **iCloud sync** — needs a second device, a capability, and so the paid Developer
  Program (`docs/architecture.md` › Distribution); a design change.
- **Reminders** — a daily notification, a privacy-gated permission; a design change.
- **A review focus switch** — the scope limiting due reviews too, for cramming one topic
  before a trip; one queue condition and one stored setting, no migration.
- **Undoing a grade** — if mistaken taps prove common; the answer log keeps what undo
  needs.
- **Hiding a card**, with a list to bring hidden cards back — if a bad card turns up.
- **A card browser, search, and favourites.**
