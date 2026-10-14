# Architecture

This is FlashCompose's design document: how the app is layered, which patterns it uses
and why, and where a new piece of code goes. `AGENTS.md` holds the rules and the
commands; this file holds the reasoning behind them. [FlashCompose](#flashcompose) is
the app's own design — its principles, data, scheduling, and flows. The sections after
it are the patterns FlashCompose keeps from `tomada1114/ios-template`, still shown
through the template's to-do list until the drill replaces it
([Follow-ups](#follow-ups)): a domain value, a view model, a repository port, a
SwiftData adapter, a fake, a contract test, and a UI test.

## Decisions at a glance

| Decision | Choice | Why |
|---|---|---|
| Minimum OS | iOS 27 (`project.yml`, `Package.swift`), built with Xcode 27 (`.xcode-version`) | FlashCompose runs on its owner's own iPhone, which runs the current iOS, so the floor is the current major release: every API the SDK ships, Liquid Glass included, is usable without an `#available` branch, and the one simulator runtime CI's Xcode ships is the floor itself |
| Device family | iPhone only (`TARGETED_DEVICE_FAMILY: "1"` on the app and UI-test targets), portrait only, one scene | One person's phone owes one family's layouts, and a one-question drill needs one orientation. On an iPad it runs as an iPhone app; iPad layouts are a Product non-goal |
| Capabilities and permissions | None: no entitlements file, no capability, no privacy-gated permission | Nothing in the first version needs one: no network, no sync, no notifications (Product non-goals; reminders and iCloud sync are Later). A free Personal Team, which signs the app ([Distribution](#distribution)), cannot take the advanced capabilities anyway |
| Presentation pattern | MVVM with `@MainActor @Observable` view models in Core | The view model is plain Swift that `swift test` drives in milliseconds, so every decision a screen makes is unit-tested and coverage-gated; the view stays a thin renderer |
| Card catalog | Read-only JSON inside `FlashComposeCore` (`Resources/Catalog/`), decoded by Core at launch; never copied into the store | Cards ship with the app and change only in this repository, so an update that adds, fixes, or removes cards migrates nothing; as a Core resource, the catalog's integrity test runs under `just test` ([Card catalog](#card-catalog)) |
| Persistence | Progress — each card's FSRS state and the append-only answer log — in SwiftData, behind the Core `ProgressStore` port | First-party (no dependency), migrations built in, and the port keeps it replaceable: Core never imports SwiftData ([Progress store](#progress-store)) |
| Scheduler | FSRS-6, ported into Core from the old app's port of ts-fsrs 5.4.2 | Reproduces the old app's results exactly, checked against its golden vectors, without the app's first dependency ([Scheduling](#scheduling)) |
| Networking | None: FlashCompose sends no request, and the package holds no HTTP client, adapter, or `network` log category | No network access is a Product non-goal; an unused layer under the coverage floor would only invite a feature the non-goals forbid |
| Preferences | `UserDefaults` behind a synchronous Core `PreferencesStoring` port; the scope is FlashCompose's one setting | First-party and synchronous; the port keeps key names in one Core file where a test pins them ([Scope](#scope)) |
| Navigation | One `NavigationStack(path:)`, in `FlashComposeUI`'s `RootView`, bound to a Core `NavigationModel`; a custom URL scheme (`flash-compose`, `project.yml`'s `info:` block) parsed by Core's `DeepLink`. The drill is the root and the scope a sheet, so the path stays empty until a pushed screen exists | Which screen shows is Core state a test drives, so a deep link and state restoration have something to hold on to; the seam stays for the pushed screens Later brings (a card browser, statistics). A custom scheme is an `Info.plist` entry, not an entitlement; `flash-compose://` opens the app on the drill |
| Shipped languages | English (the source) and Japanese, following the device's language | The owner's iPhone runs in Japanese, and English buttons around a Japanese prompt would read as two apps ([Localization](#localization)) |
| Distribution | Installed on the owner's iPhone from Xcode (`just run-device`) only; no TestFlight, no App Store | One learner, one phone; store distribution is a Product non-goal for this version ([Distribution](#distribution)) |
| Module layout | One local Swift package, `FlashComposeKit`, with `FlashComposeCore` / `FlashComposeUI` / `FlashComposePlatform` | Module boundaries the compiler enforces, and a package `swift test` can run without a simulator |
| Project file | XcodeGen (`project.yml`); `FlashCompose.xcodeproj` is generated and gitignored | No merge conflicts in a `.pbxproj`, and the whole app target is reviewable as text |
| Language mode | Swift 6, warnings as errors | Data-race safety is checked from the first line; there is never a "migrate later" |
| Dependencies | None | Every third-party package is a supply-chain and upgrade cost; adding one is a human's decision (`AGENTS.md` › Security and human approval). FSRS-6 is ported rather than added for the same reason ([Scheduling](#scheduling)) |

Patterns deliberately **not** adopted: The Composable Architecture (a dependency and a
learning curve for what `@Observable` plus ports already give), Combine for state (the
Observation framework replaces it), singletons or a global service locator (the
composition root passes everything explicitly), and Core Data (SwiftData is its
successor on this OS floor).

## FlashCompose

What the app is and is not: `AGENTS.md` › Product and
[`docs/product/requirements.md`](product/requirements.md) (the § numbers below are its
sections). Its screens and flows are [`docs/product/ux-flows.md`](product/ux-flows.md),
its app-wide UX rules [`docs/design/ux-guidelines.md`](design/ux-guidelines.md), and how
it looks the Design lock in [`docs/design-system.md`](design-system.md#design-lock).

### Principles

- **Offline and alone.** Everything runs on the phone, with no network, account, or
  server, and no screen waits on anything but local storage. Rules out sync, remote card
  updates, and any HTTP client.
- **Cards ship; progress stays.** The catalog is read-only data inside the app, and only
  the learner's progress is stored. Rules out seeding cards into the store, editing
  cards in the app, and an update that has to migrate progress because a card changed.
- **A card's id is its identity.** Progress and the answer log are keyed by card id —
  never by position, file, or text — and an id is never reused. Rules out a fix to a
  card's wording silently resetting its schedule, and a new card inheriting an old one's.
- **The schedule is Core's.** What comes next — the queue, FSRS-6, re-asks, the practice
  day — is decided in `FlashComposeCore` against an injected clock, time zone, and random
  number generator, and tested there. Rules out ordering in a view or a store query.
- **The log is append-only.** Every grade is written once and never edited, because a
  log cannot be rebuilt later (§3.6). Rules out undo by deleting an answer, and keeping
  only the latest state.

### Shape

| Domain | Layer | Where |
|---|---|---|
| Card catalog — cards, topics, subtopics, levels, grammar tags, retired ids; decoding | Core | `FlashComposeCore/Catalog/`; the data in `FlashComposeCore/Resources/Catalog/` |
| Scheduling — FSRS-6 memory and intervals, the Alea fuzz, the practice day | Core | `FlashComposeCore/Scheduling/` |
| Drill — today's queue, re-asks, the header counts, the end of the day; `DrillViewModel` | Core | `FlashComposeCore/Drill/` |
| Scope — the topics and levels turned off, the never-seen count; `ScopeViewModel` | Core | `FlashComposeCore/Scope/` |
| Progress — `CardProgress`, `Answer`, the `ProgressStore` port | Core | `FlashComposeCore/Progress/` |
| Progress adapter — the SwiftData models in `AppSchemaV1`, `SwiftDataProgressStore` | Platform | `FlashComposePlatform/Persistence/` |
| Scope storage — two `PreferenceKeys` entries | Core keys, Platform adapter | the existing Preferences seam |
| Screens D1–D3, S1, E1, E2 | UI | `FlashComposeUI/Drill/`, `FlashComposeUI/Scope/` |
| `InMemoryProgressStore`, `ProgressStoreContract` | Test support | `Tests/FlashComposeTestSupport/` |

What crosses each boundary: `CardProgress` and `Answer` values cross the
`ProgressStore` port; nothing about the catalog does, because Core reads it itself from
`Bundle.module`, as it reads its String Catalog — a resource the app ships, not storage
or an OS service, so it needs no port. Toward the UI, view models expose state and
`LocalizedStringResource` wording; card text reaches a view as a plain `String`, rendered
with `Text(verbatim:)`.

### Card catalog

- **Files.** `Sources/FlashComposeCore/Resources/Catalog/` holds
  `cards/<topic>/<subtopic>.json` (37 files, 1,952 cards), `taxonomy.json` (5 topics and
  37 subtopics, their Japanese names and order), `levels.json` (10 levels, their TOEIC
  and CEFR hints and Japanese summary), `grammar.json` (39 tags), and `retired-ids.json`.
  All were copied once from `tomada1114/instant-composition` at `6fcefb2`; from then on
  this repository is the cards' only home (§3.1). One file per subtopic keeps a card
  edit a small diff, and two branches editing different subtopics never conflict.
- **Fields.** A card is `id`, `ja`, `en`, `alternatives`, `point`, `topic`, `subtopic`,
  `level`, and `grammar`, spelled as the old JSON spells them. `Card` keeps those names
  except `ja` and `en`, which it calls `japanese` and `english` because SwiftLint's
  `identifier_name` refuses a two-letter name, so the decoder maps those two keys to
  them. The old `createdAt` and `stamps` (its authoring pipeline's review hashes) are not
  carried.
- **Retired ids.** `retired-ids.json` lists every card id the old repository retired —
  its 77 card tombstones, without the 10 vocabulary ones — each with its `replacedBy` id
  when it has one, and every id this repository retires from now on.
- **Loading.** At launch Core decodes every file — about 700 KB of JSON — into one
  in-memory catalog value, off the main actor, while the progress store opens. A file
  that cannot be read or decoded fails the start-up (E1); the app never runs on part of
  the catalog.
- **Integrity.** A Core test reads the real files under `just test` and holds every card
  to the definitions: a known topic and subtopic, a level from 1 to 10, known grammar
  tags, non-empty `ja`, `en`, and `point`, at least one alternative, and an id that
  matches the format below, appears once, and is not retired.
- **Editing.** Cards are edited in this repository only, by hand or by an agent, as JSON;
  the integrity test is the gate, and the `editing-cards` skill holds the procedure.

### Card identity

A card id is contract: it is the key the learner's progress and answers are stored
under. Whether a change keeps it turns on one question, carried from the old
repository's `content/guides/identity.md`: could the answers recorded before the change
still be compared, as answers to the same question, with those recorded after it?

- **Yes — edit in place, same id:** a typo or outright error; a more natural `ja` with
  the same meaning; a word swap in `en` that keeps its skeleton; adding, removing, or
  replacing alternatives; rewriting `point`; retagging `topic`, `subtopic`, `level`, or
  `grammar`.
- **No — a new id:** the meaning of `ja` changes; the skeleton of `en` changes (tense,
  pattern, main clause); the main grammar item changes; or `en` grows to about 1.5 times
  its words or shrinks to about two thirds. The old id goes into `retired-ids.json` with
  `replacedBy`, and its progress is no longer read — the new card starts as new.
- **Deleting** a card retires its id without `replacedBy`. An id is never reused.
- **Format:** `c_` and four digit–letter pairs, `^c_(?:[2-9][a-hjkmnp-z]){4}$`
  (`c_7k2m9x4q`). Digits and letters alternate so the `typos` spell check never meets a
  run of letters it could flag, and `0`, `1`, `i`, `l`, and `o` are left out as easily
  confused.

Progress stored under an id the catalog no longer has is kept and ignored, and that
card is never shown again (§3.1).

### Progress store

- **What is stored.** `CardProgress`, one per card that has moved: stability,
  difficulty, repetitions, lapses, last practice day, due practice day, keyed by card id.
  `Answer`, one per grade, re-asks included: card id, the instant it was graded, its
  practice day, the grade, whether it was the day's first answer or a re-ask, the FSRS
  state before (none for a new card) and after, and the seconds the card was on screen
  before the reveal (§3.6).
- **Where.** SwiftData, behind the Core `ProgressStore` port: two `@Model` entities in
  the app's `AppSchemaV1`, in the one container `PersistenceStore` opens. That schema
  replaces the template's to-do schema rather than following it as `AppSchemaV2`: no
  build carrying the to-do schema has been installed outside the owner's Mac, so no
  store on a device holds it.
- **One grade, one save.** Recording a grade appends the answer and replaces the card's
  progress in a single save, so the log and the state never disagree; a failed save
  rolls back both and the card stays on screen (E2, save then advance).
- **Read at launch, written per grade.** Start-up fetches every progress row — at most
  one per card. Nothing in this version reads the log back except the tests.

### Scope

- Two `PreferenceKeys` entries over `PreferencesStoring` record the topic ids turned
  **off** and the levels turned **off**, each as one `String`; empty means everything
  on, the default. Recording what is off means a topic a later catalog adds starts on,
  as everything does on first launch.
- An id recorded as off that the catalog no longer has is ignored, and "at least one
  topic and one level stay on" holds over the current catalog.
- The key names are contract (`PreferenceKeysTests`).

### Session

Waiting re-asks, the card on screen, and which face it shows live in `DrillViewModel`
and are never stored: a relaunch starts a new session and drops waiting re-asks (§3.2).

### Scheduling

- **The algorithm.** FSRS-6's long-term scheduler, ported into
  `FlashComposeCore/Scheduling/` from `tomada1114/instant-composition`'s port of ts-fsrs
  5.4.2 (`packages/domain/src/fsrs.ts`, `fsrs-memory.ts`, `fsrs-interval.ts`, with its
  Alea generator), keeping ts-fsrs's MIT notice in each file it reaches. Grades are
  again 1, hard 2, good 3; no easy.
- **The parameters.** ts-fsrs's 21 default weights, desired retention 0.9, a longest
  interval of 365 days, and interval fuzz seeded by the card id and its repetition count
  — held in one `Tuning` type (`designing-core-logic`).
- **The oracle.** The old repository's `tests/fixtures/fsrs-golden.json` (generated with
  ts-fsrs 5.4.2) is a test resource here, and the port reproduces it exactly (§3.3).
- **Not a package.** `open-spaced-repetition/swift-fsrs` (MIT) was considered and is not
  used: its FSRS-6 support exists only on `main` (merged 2026-05-12; its latest tag,
  `v5.0.0` of 2024-10-29, is FSRS-5), and its fuzz seed is fixed to the review time, the
  repetition count, and difficulty × stability (`Sources/FSRS/Scheduler/AbstractScheduler.swift`),
  so it can neither seed by card id nor reproduce the golden vectors — and it would be
  the app's first dependency. Checked through the GitHub API on 2026-10-13.
- **The practice day** is a calendar date, not an instant: the local date of the answer's
  instant minus four hours, in the time zone current at that answer. Intervals and
  elapsed days are differences of practice days, never of instants (§3.3, §4).
- **What moves a card:** only its first answer of a practice day, never a re-ask (§3.3).

### Core flows

- **Cold launch** (F6). `App/` opens the container and the preferences and hands them to
  `AppModel` → Core decodes the catalog and fetches every progress row → `DrillViewModel`
  builds today's queue → D1 with the first card, or D3; E1 when either load fails.
- **Grade** (F1, F2). A tap on D2 → `DrillViewModel` computes the new FSRS state when
  this is the card's first answer today → `ProgressStore` records the answer and the
  state in one save → the queue and re-asks update → D1 with the next card and the new
  counts. A failed save → E2, with nothing recorded and nothing changed.
- **Scope change** (F3). A row tap on S1 → `ScopeViewModel` writes the preference and
  recounts never-seen cards → the next new card comes from the new scope; from D3, a
  scope with never-seen cards turns the screen into D1.
- **Coming back** (F5, F7). The scene becoming active, or 04:00 passing, makes Core
  recompute today: due reviews turn D3 into D1, and from the next card the queue is the
  new day's.

### Quality targets

| Target | Check |
|---|---|
| The first card on screen within 1 second of a cold launch on the owner's iPhone, and no visible loading between cards (§4) | Measured on the device at the first `just run-device` — `os_signpost` intervals around the catalog decode and the progress fetch — and recorded in that pull request; no gate |
| FSRS results equal to the old app's for the same inputs | The golden-vector suite, `just test` |
| Every card valid against the definitions; no id duplicated or reused | The catalog integrity test, `just test` |
| The answer log and the progress never disagree; a failed save changes nothing | `ProgressStoreContract` against the fake and the SwiftData adapter, `just test` |
| Nothing leaves the phone | No networking code and no capability; review only, no gate |
| The UX targets in `docs/design/ux-guidelines.md` — the largest text size, VoiceOver, Increase Contrast, Reduce Motion | Screenshots and a VoiceOver pass per `running-the-app`, in the pull request that builds the screen |

### Distribution

FlashCompose is installed only on its owner's iPhone, from Xcode, with
`just run-device`, signed by a free Personal Team. Apple's membership page says a
personal team's provisioning profiles "expire 7 days from issuance", after which the app
must be rebuilt and reinstalled, and that a personal team installs up to 3 apps per
device and cannot build the advanced capabilities
(<https://developer.apple.com/support/compare-memberships/>, checked 2026-10-13). So
the owner runs `just run-device` at least once a week, and the empty capability set is
also all a personal team allows. Deleting the app deletes all progress; there is no
export (§3.6).

### Open

- **Whether reinstalling keeps the progress.** Installing over the expired build, with the
  same bundle identifier and without deleting the app, should keep its data container —
  stated only in Apple Developer Forums answers, unchecked against Apple's
  documentation. Settled at the first weekly reinstall on the device; if the store does
  not survive, distribution goes back to the owner (the paid program, or an export).
- **The measured first-card time** on the device (Quality targets).

### Follow-ups

Code work these decisions imply; each becomes an issue.

- Remove the to-do sample — its code, tests, previews, launch-test steps, and the
  passages that describe it here, in `docs/getting-started.md`, and in `README.md` — and
  replace its `AppSchemaV1`.
- The drill (D1–D3, E1, E2) and the scope sheet (S1) with their view models and the scope
  keys.
- The design-lock screenshots `designing-ui` asks for.
- The launch test driven through the drill instead of the to-do list.

## Layers

```
App/                         composition root — @main, builds adapters, hands them to Core
 ├─ FlashComposeUI                  SwiftUI views: render Core state, forward user intents
 │   └─ FlashComposeCore            domain values, view models, ports (protocols), wording, logging
 └─ FlashComposePlatform            adapters behind Core ports: SwiftData, UserDefaults
     └─ FlashComposeCore
Tests/FlashComposeTestSupport       each port's fake and contract function (test code only)
```

- **Core ← UI** and **Core ← Platform**; both ← `App/`. `FlashComposeUI` and `FlashComposePlatform`
  are siblings and never import each other. A view therefore cannot reach SwiftData, and
  an adapter cannot reach a view — the only place both halves meet is `App/`.
- **Core imports no UI, persistence, or OS-integration framework** — SwiftUI, UIKit,
  AppKit, Cocoa, SwiftData, CoreData, CloudKit, UserNotifications, CoreLocation, Photos,
  PhotosUI, StoreKit, WidgetKit. It is enforced twice: `.swiftlint.yml`'s
  `no_ui_import_in_core` and `ArchitectureBoundaryTests`, whose lists change together.
  `Foundation`, `Observation`, and `os` are allowed.
- **`App/` holds no logic.** It decides which adapter each port gets, and nothing else.
- **Shared presentation values live in `FlashComposeUI`**, in `DesignSystem/DesignTokens.swift`
  (spacing, radius, hit target, motion), never in Core; `docs/design-system.md` records
  why each has its value.

### Why the package also builds for macOS

`Package.swift` lists `.macOS(.v27)` next to `.iOS(.v27)` so `swift test` runs the whole
package on the host Mac: seconds instead of a simulator boot, and the only way
`scripts/coverage.sh` can read coverage from `swift test`. The cost is that every target
must compile for macOS too. Core does by construction; in `FlashComposeUI` and `FlashComposePlatform`
an iOS-only API (`.navigationBarTitleDisplayMode`, `UIApplication`, a `UIKit` type) goes
behind `#if os(iOS)`. The app itself is iOS-only — `project.yml` builds it for the iOS
Simulator, and CI's `app` job proves it compiles and launches there.

## View models

A view model is a `@MainActor @Observable final class` in Core. The template's is
`TodoListViewModel`.

- **Action-shaped.** The view calls one method per user intent — `addDraft()`,
  `toggle(_:)`, `delete(atOffsets:)` — and never mutates published state itself. State is
  `public private(set)`; the only settable property is what a control binds to
  (`draftTitle`).
- **Derived state lives here.** `canAdd`, `showsEmptyState`, `showsLoadFailure`,
  `showsProgress` are computed in Core so the view has no `if` of its own worth testing.
- **Wording lives here.** Core returns `LocalizedStringResource` from its String Catalog
  (`TodoListStrings`, `TodoListFailure.message`); a view renders it with `Text(_:)` and
  shows user data with `Text(verbatim:)`.
- **Time and identity are injected** (`now: () -> Date`, `makeID: () -> UUID`) so a test
  pins both. The same goes for anything nondeterministic an app adds: a `Clock`, a
  `Locale`, a random number generator.
- **Construction has no side effects.** Nothing is read until `load()`; the view calls it
  from `.task` on first appearance.
- **Ownership.** A view model every scene shares (`TodoListViewModel`) is built once by
  Core's `AppModel`, which `App/` creates in `@State` (so it outlives any one view tree);
  the view holds it with `@Bindable` only to bind controls. A pushed screen's own view
  model (`TodoDetailViewModel`) is built by an `AppModel` factory when the route is
  pushed, and the screen keeps it in `@State` for as long as it is shown (Composition
  root, below).

### Reentrancy

A `@MainActor` method that `await`s can be re-entered by the next tap before it resumes.
The view model is written for that:

- An in-flight add sets `isAdding`, which disables Add, so a double tap stores one item.
- After an `await`, a row is found again by identifier rather than by a remembered index —
  the list may have changed in between (`toggle(_:)`).
- The draft is cleared only if it still holds what was submitted, so text typed while a
  save was in flight survives (`addDraft()`).
- Loads overlap — the list's `.task`, pull-to-refresh, Retry, and the detail screen's
  `.task` all call `load()` — and the newest one wins. Each load takes a generation
  number; one that returns after a newer load started drops its result, success or
  failure, so a slow, stale fetch never overwrites a newer one.
- A load replaces `items` wholesale, so a write that finished while it was in flight
  could vanish: the fetch may have read the store before the write landed. Every add,
  toggle, and delete the repository acknowledges during the newest load is recorded and
  replayed over the loaded items — a save replaces or adds by identifier, a delete
  removes — which changes nothing when the fetch already saw the write. Replaying, rather
  than loading again after the edit, costs no second fetch and cannot loop.
- A cancelled load is a no-op: no failure, `items` untouched, and `phase` back to what it
  was before the load, so a first load cancelled when its screen left leaves the list
  `idle` and the next appearance asks again. The view model reads `Task.isCancelled`
  after the fetch rather than a port case: `TodoRepositoryError` has no cancellation
  case, so a store that sees its caller cancel can only report a failure, which the
  cancelled caller no longer wants (the `designing-errors` skill, Cancellation
  propagates).

Each of these has a test in `TodoListViewModelTests` that drives the interleaving through
the fake's `onSave` hook, or its `onFetch` hook, which runs after a fetch has read the
store and before it returns — the window in which a fetch's answer goes stale.

## Navigation

Which screen shows is Core state, not `@State` inside a view, so a deep link and state
restoration have something to hold on to and a test can drive navigation without a view.

- **Routes are a Core enum.** `AppRoute` (`Sources/FlashComposeCore/Navigation/`) has one case
  per pushable screen, carrying an identifier rather than the value it shows:
  `.todoDetail(TodoItem.ID)`. The destination's view model looks the item up when the
  screen renders (`TodoDetailViewModel.content`, through
  `TodoListViewModel.item(withID:)`, which searches every item, not only the visible
  ones), so a pushed screen shows the current state, and an identifier nothing holds
  shows a not-found state.
- **The path is a Core view model.** `NavigationModel` is a `@MainActor @Observable`
  class holding `path: [AppRoute]`, with one action per intent: `show(_:)` pushes,
  `popToRoot()` returns, `open(_:)` handles a deep link. It is owned per scene: `App/`'s
  scene root holds it in `@State` and hands it to the root view, while the shared view
  models it routes between stay app-level, in `AppModel`. It never moves into
  `AppModel`: a navigation path belongs to a scene, not to the app. FlashCompose is
  iPhone only and runs one scene, but per-scene ownership keeps navigation correct
  without depending on that.
- **One `NavigationStack(path:)`, in `RootView`.** `FlashComposeUI`'s `RootView` binds the
  stack to `NavigationModel.path`, shows the root screen (`TodoListView`, a plain screen
  with no stack of its own), and declares every destination in one
  `navigationDestination(for: AppRoute.self)` switch; a row's `NavigationLink(value:)`
  pushes a route. The back button writes the path back, which is why `path` is the one
  settable property. A new screen therefore adds an `AppRoute` case and a branch of that
  switch, and edits no other screen.
- **A pushed screen with a view model of its own gets it from `AppModel`.** The switch
  cannot build one over a port itself — `FlashComposeUI` may not import `FlashComposePlatform` — so it
  calls the route's factory: `.todoDetail(id)` renders
  `TodoDetailView(model: app.makeTodoDetailViewModel(id: id))`. The screen keeps the
  first model it is handed in `@State`, so the fresh model a later re-render builds is
  discarded unused (which is why construction has no side effects), and each
  destination is identified by its route, so a deep link that swaps one pushed item for
  another gets a fresh screen and model.
- **Deep links are parsed in Core.** `DeepLink.route(for:)` accepts exactly
  `flash-compose://todo/<uuid>` — the scheme in any case, the host `todo`, one `UUID` path
  component — and rejects every other shape rather than guessing; `DeepLink.url(for:)`
  is its inverse. The scene root forwards `.onOpenURL` to its `NavigationModel.open(_:)`,
  which replaces the path with the parsed route or logs the rejected link's scheme and
  host in the `navigation` category. The scheme is registered under `project.yml`'s `info:` block
  (XcodeGen writes the gitignored `App/Info.plist` from it on every `just generate`, and
  the build merges it with the `INFOPLIST_KEY_*` settings); `DeepLinkTests` fails when
  the scheme Core parses and the one `project.yml` registers differ, and
  `scripts/bootstrap.sh` rewrites both together.
- **Tabs are an app's decision.** A tab-based app keeps one `NavigationModel` per tab, one
  stack each; tabs versus a single stack is the design lock's navigation field
  (`designing-ui`). `NavigationSplitView` and state restoration (`@SceneStorage` over
  `path`) are likewise an app's to add.

## Repositories

A repository is a **port**: a `Sendable` protocol Core declares, in Core's vocabulary.
`TodoRepository` is the worked example.

```swift
public protocol TodoRepository: Sendable {
    func fetchAll() async throws(TodoRepositoryError) -> [TodoItem]
    func save(_ item: TodoItem) async throws(TodoRepositoryError)
    func delete(id: TodoItem.ID) async throws(TodoRepositoryError)
}
```

- **Value types only across the port.** `TodoItem` is a Core struct; the SwiftData
  `@Model` (`TodoRecord`) is internal to `FlashComposePlatform` and never crosses. That is what
  keeps SwiftData's non-`Sendable` model objects on the adapter's actor and lets every
  Core test run without SwiftData.
- **`async` everywhere**, because an implementation is an actor with its own executor
  (SwiftData's `@ModelActor`, or the fake), and crossing into it is a suspension point.
- **Typed throws with a closed Core error enum.** `TodoRepositoryError` has three cases;
  the adapter maps every SwiftData error into one of them and logs the detail
  (`.private`), so Core handles a closed set and never learns which store failed. Error
  payloads carry identifiers, never titles — an error can reach a log or a crash report.
- **The ordering is Core's.** `TodoItem.isOrderedBefore(_:_:)` defines display order and
  every implementation sorts by it, so a store's query language never decides behavior.
- **A null object for "no store".** When the on-disk store cannot be opened, `App/` hands
  the view model `UnavailableTodoRepository`, which fails every call. The app launches,
  shows its load failure with a retry, and never pretends an edit was saved. The
  alternatives — crashing, or silently falling back to an in-memory store whose edits
  vanish on relaunch — are both worse for the user.

### The SwiftData adapter

`SwiftDataTodoRepository` is an `actor` annotated `@ModelActor`: SwiftData gives it a
`ModelContext` bound to its own serial executor, so no model object leaves the actor and
the main actor never waits on a write it did not ask for.

- **One store, one container, for the whole app.** `PersistenceStore.makeContainer(storage:)`
  is the only place a `ModelContainer` is opened, from the app-wide `AppSchemaV1` and
  `AppMigrationPlan`. `App/` opens it once and hands it to every repository's
  `init(modelContainer:)` (the initializer `@ModelActor` generates); no repository opens a
  container of its own, because a second container with a different schema over the same
  default store file risks failing to open or damaging the store. Each repository is its
  own actor with its own `ModelContext` over the shared container, so two of them see each
  other's saved writes (`PersistenceStoreTests`).
- **`Storage`** picks the file: `.onDisk` (SwiftData's default store, for the app),
  `.inMemory` (UI tests under `-uiTesting`, and host tests), or `.file(URL)` (a test that
  must close a store and reopen the same file, as a migration test does).
- **A failed open is logged, then rethrown.** `makeContainer` logs SwiftData's error as a
  fault (`.private`: it can quote a path) and throws it unchanged; `App/` answers with
  `UnavailableTodoRepository` for every port the store would have served.
- **A failed save rolls the context back**, or the pending change would be written by
  the next successful save.
- **The schema is versioned from day one** (`AppSchemaV1`, `AppMigrationPlan`), and it
  is the whole app's, not one entity's: `TodoRecord` beside `SwiftDataProgressStore`'s
  `CardProgressRecord` and `AnswerRecord`. V1 is edited in place while no build carrying
  it has been installed outside the owner's Mac ([Progress store](#progress-store)).
  The stored shape is contract (below): from the first such install, the next change to
  a record, or another entity, adds `AppSchemaV2` and a migration stage instead of
  editing V1, and a repository over the shared container. The store records the
  model's entities, attributes, and version identifier — never the Swift names of the
  schema or the plan — so a store written before both were renamed to their `App`
  names opens unchanged (`PersistenceStoreTests` reopens one written by a frozen copy of
  the old schema, `PreRenameSchemaV1`).
- **`@Attribute(.unique)` on the identifier** makes a save with a known id an update.
  CloudKit sync does not allow unique constraints; an app that turns sync on replaces it
  with a fetch-before-insert in a new schema version, and that choice is a design change that rewrites this entry.

### Fakes and contracts

Every port has exactly one fake and one contract function, both in
`Tests/FlashComposeTestSupport`:

- **`InMemoryTodoRepository`** — a real conforming actor, not a mock: tests hand it data
  and failures (`fail(_:with:)`), then read what happened (`calls`, `snapshot`). No
  expectations are declared up front.
- **`TodoRepositoryContract.check(_:)`** — every promise the port's `///` makes, written
  once over the protocol. `FlashComposeCoreTests` runs it against the fake and
  `FlashComposePlatformTests` against the SwiftData adapter with an in-memory store, both under
  `just test` and in CI. A fake stands in for the adapter only while both keep the same
  promises; this is what checks it. The contract has its own oracle tests — deliberately
  broken implementations it must reject — so it cannot pass vacuously.

`FlashComposeTestSupport` is a library target only because a test target cannot be depended on.
No product exports it and `ArchitectureBoundaryTests` fails if a shipped module imports
it. Previews use their own small `PreviewTodoRepository` in `FlashComposeUI` (Debug only).

### Preferences

`PreferencesStoring` is the seam for small user settings — the ones that must survive a
relaunch but are not the user's data. The port and its keys are in
`FlashComposeCore/Preferences`, the `UserDefaultsPreferences` adapter in
`FlashComposePlatform/Preferences`, and `InMemoryPreferences` plus `PreferencesContract` in
`Tests/FlashComposeTestSupport`. The worked example is Hide Completed on the to-do list.

```swift
public protocol PreferencesStoring: Sendable {
    func value<Value: PreferenceValue>(for key: PreferenceKey<Value>) -> Value
    func set<Value: PreferenceValue>(_ value: Value, for key: PreferenceKey<Value>)
}
```

- **Synchronous, unlike every other port.** `UserDefaults` is synchronous and
  thread-safe, so an `async` port would only add suspension points — and the reentrancy
  they bring — to a `@MainActor` view model. Nothing can fail that a caller could act
  on, so it does not throw either: an unset key, or a stored value of the wrong type,
  answers the key's default, and the adapter logs the wrong type under
  `AppLog.preferences`. The adapter stores only its suite's name, so it is a `Sendable`
  struct; the fake is a final class over a `Mutex`.
- **A key carries its type and default.** `PreferenceKey<Value>` pairs a name with a
  default, and `PreferenceValue` admits only `Bool`, `Int`, `Double`, and `String` —
  types `UserDefaults` stores natively. A richer setting is stored as one of these and
  converted in Core.
- **Key names are contract.** Every key is a constant in `PreferenceKeys`, and
  `PreferenceKeysTests` pins each name and default. A renamed key reads as unset, so a
  rename silently resets every user's setting: it is a migration in Core, not an edit
  to that test (What is contract and what is private, below).
- **Read on load, not in `init`.** `TodoListViewModel` reads `hideCompleted` at the
  start of `load()`, so constructing a view model still touches no storage.
- **UI tests start clean.** `UserDefaultsPreferences.scratch(suiteName:)` removes a
  suite's domain before handing back an adapter over it. Under `-uiTesting`, `App/` uses
  a scratch suite named after `AppLog.subsystem`, because `just uitest` reuses the
  simulator and one run's setting would otherwise leak into the next. Unit tests of the
  adapter each use a scratch suite named with a fresh UUID.

## Composition root

`App/FlashComposeApp.swift` is the one place that knows both halves of every port. It picks the
storage and the preferences suite from the launch arguments, opens the one SwiftData
container (`PersistenceStore`) and builds every SwiftData repository over it, falls back
to the null object when the container will not open, and builds one `AppModel` in
`@State`, handing it the adapters as ports through its initializer. Each scene's root
(`SceneRoot`) owns that scene's `NavigationModel`, forwards opened URLs to it
(`.onOpenURL`), and renders `FlashComposeUI`'s `RootView` over the app model and the navigation
model. `App/` chooses adapters and nothing else.

`AppModel` (`Sources/FlashComposeCore/AppModel.swift`) is a `@MainActor @Observable final
class` in Core that does the rest of the wiring:

- **It holds the view models every scene shares** — today `todoList`, the one
  `TodoListViewModel` every window shows — built once over the ports it was handed.
- **It has one `make…ViewModel(…)` factory per route whose screen needs a view model of
  its own** — today `makeTodoDetailViewModel(id:)`, which builds a
  `TodoDetailViewModel` over the shared list. A factory whose model needs a port builds
  it over a port `AppModel`'s initializer was handed and keeps as a named stored
  property.
- **It is not a service locator.** There is no registry, no lookup by type, and no
  global: every dependency is a named initializer parameter `App/` passes, and every
  model is built by a named method. A second port is a new initializer parameter.
- **It is in Core, not `App/`,** so `AppModelTests` builds a route's view model over the
  fakes in `FlashComposeTestSupport` and the coverage floor sees the wiring. Factory closures
  assembled in `App/` were the alternative: they would leave the wiring where no
  coverage-gated test reaches it.
- **It is app-level, never per scene.** Per-window state — the navigation path — stays
  in the scene's own `NavigationModel` (Navigation, above).

## Concurrency

- Swift 6 language mode, complete checking, warnings as errors.
- View models are `@MainActor`; ports are `Sendable` and `async`; adapters and fakes are
  actors. `PreferencesStoring` is the one synchronous port (Preferences, above), so its
  adapter is a struct and its fake a final class over a `Mutex`. Values crossing actors are `Sendable` structs and enums.
- `@unchecked Sendable` and `nonisolated(unsafe)` are not used to silence a diagnostic —
  doing so needs human sign-off (`AGENTS.md`).
- A closure a test injects (`now`, `makeID`, the fake's `onSave` and `onFetch`) is
  `@Sendable`; capture values, not a `@MainActor` static.

## Logging

Shipped code logs through `AppLog` in Core — `os.Logger`, one subsystem (the bundle
identifier, checked against `project.yml` by `AppLogTests`) and one category per concern
(`todos`, `persistence`, `preferences`, `navigation`). `print`, `debugPrint`, and `NSLog` are
rejected under `Packages/*/Sources/` and `App/` by `.swiftlint.yml`'s
`no_print_in_sources`: an app launched from the Home Screen has nowhere to send stdout. Anything user-derived is
interpolated `.private`; identifiers, counts, and operation names are `.public`.
`just logs` streams the subsystem from the booted simulator.

A log message is an autoclosure that needs an explicit `self`, which SwiftFormat's
`redundantSelf` rule strips — log a local constant instead of a `self.` property
(`TodoListViewModel.load()`).

## Localization

Core owns every fixed string a reader sees, in `Sources/FlashComposeCore/Resources/Localizable.xcstrings`,
through `LocalizedStringResource(_:defaultValue:bundle: .module, comment:)`. English is
the source language (`defaultLocalization: "en"`), and Japanese ships beside it: every
string carries a `ja` value, and the app follows the device's language, so the owner's
iPhone shows Japanese. The agent that adds a string writes its Japanese in the same pull
request, following `docs/design/ux-guidelines.md`'s glossary and terse register; there is
no separate translation review — the owner files an issue when a string reads wrong in
use. Card content — the prompt, the answer, the alternatives, the point, and the topic
names — is data, not wording: a view shows it with `Text(verbatim:)` in either language.
`swift test` copies the catalog uncompiled, so tests resolve English from `defaultValue`
(the `english` helper in `FlashComposeCoreTests`); `xcodebuild` compiles it into the app.
The app's `Info.plist` declares `CFBundleLocalizations: [en, ja]` (`project.yml`): iOS
picks an app's language from its main bundle, which holds no `.lproj`, so without the key
the app runs in English on a Japanese iPhone and never reaches Core's `ja` catalog.

## Testing

| Layer | Test | Where | Runs in |
|---|---|---|---|
| Domain values, view models | Swift Testing suites against fakes | `Tests/FlashComposeCoreTests` | `just test`, CI `test` (coverage-gated) |
| Port promises | the contract function, against the fake | `Tests/FlashComposeCoreTests` | `just test`, CI `test` |
| Adapters | the contract function, against the real adapter; adapter-only cases | `Tests/FlashComposePlatformTests` | `just test`, CI `test` — when the framework runs on the host |
| Module boundaries | `ArchitectureBoundaryTests` | `Tests/FlashComposeCoreTests` | `just test`, CI `test` |
| The bundled card catalog, FSRS-6 | the catalog integrity test over the real files; the golden-vector suite | `Tests/FlashComposeCoreTests` | `just test`, CI `test` |
| Launch and the core interaction | XCUITest | `LaunchUITests/` | `just uitest`, CI `app` (iOS Simulator) |

- **Where a test goes.** A decision is tested in Core. An adapter is tested only for its
  translation, by the contract. An adapter whose framework needs a simulator, a device,
  or a permission prompt (notifications, location, photos) cannot run under `swift test`
  on the host; its contract run happens on a simulator or device, and its output goes in
  the pull request.
- **Coverage floor.** `scripts/coverage.sh` gates `Sources/FlashComposeCore` at 80% of lines and
  75% of functions. `FlashComposeUI` and `FlashComposePlatform` are outside it by design: views render
  and adapters translate, so neither holds a decision a unit test could catch. The floor
  is raised, never lowered.
- **Swift Testing everywhere except UI automation**, which Apple still offers only in
  XCTest. Test names are backticked sentences; error paths assert the thrown error's
  payload.
- **Fakes, not mocks.** One fake per port in `FlashComposeTestSupport`, held to the contract.

## What is contract and what is private

Contract is what something outside a change can observe: another module, a user's
device that ran an earlier build, or the user.

| Contract | What depends on it | What changing it requires |
|---|---|---|
| **Core's public API** | `FlashComposeUI`, `FlashComposePlatform`, `App/`, the tests | Update every caller in the same pull request; a new public declaration carries a `///` saying why; a new port is a design change (`AGENTS.md` › Before changing the architecture) |
| **The bundle identifier** (`PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`) | The app's data container and Keychain items on every device, App Store Connect, push and other capabilities, `AppLog.subsystem`, `just run`/`just logs` | Fixed once a build has left your machine: a new identifier is a new app, and the user's data stays behind. `project.yml` and `AppLog.subsystem` change together (`AppLogTests`) |
| **The stored schema** (`AppSchemaV1` and its successors) | Every store already on a user's device | A new `VersionedSchema` plus an `AppMigrationPlan` stage, with a test that opens a store written by the previous version. Never edit a shipped schema version |
| **The URL scheme** (`DeepLink.scheme`, registered in `project.yml`) | Links to the app in messages, notes, and other apps | Fixed once a build has left your machine: a renamed scheme breaks every link in the wild. `project.yml` and `DeepLink.scheme` change together (`DeepLinkTests`); a new link shape is a new `DeepLink` case with its tests, and an old shape keeps parsing |
| **`UserDefaults` keys and file formats** | Saved preferences and files on a user's device | Read the old key or format and migrate it in Core, with a test that starts from the old value. Every key is a `PreferenceKeys` constant, pinned by `PreferenceKeysTests` |
| **Card ids** (the catalog's `id`, and `retired-ids.json`) | The progress and the answer log on the owner's iPhone, keyed by card id | Keep the id when a fix leaves earlier answers comparable; otherwise mint a new id and retire the old one. An id is never reused ([Card identity](#card-identity)); the catalog integrity test refuses a duplicate or a reused id |

Everything else is private: `internal` declarations, how an adapter talks to its
framework, view structure, file and type layout, test helpers, log messages.

## Where new code goes

**A new screen or feature**

1. Domain values and their invariants in `FlashComposeCore` (TDD — the `tdd` skill).
2. A port in `FlashComposeCore` if the feature needs storage or an OS service; its fake and
   contract in `Tests/FlashComposeTestSupport`.
3. A `@MainActor @Observable` view model in `FlashComposeCore`, tested against the fake. A
   model every scene shares is a stored property of `AppModel`; a pushed screen's own
   model gets a `make…ViewModel(…)` factory on `AppModel`, tested in `AppModelTests`.
4. The adapter in `FlashComposePlatform`, with the contract run against it in
   `Tests/FlashComposePlatformTests`.
5. The view in `FlashComposeUI`, rendering the view model; `#Preview` per state; accessibility
   identifiers on what a UI test touches.
6. A case in `AppRoute`, and its branch in `RootView`'s `navigationDestination`
   switch, which builds the screen's model through its `AppModel` factory (Navigation,
   above).
7. The wiring in `App/` — only when the feature brings a new port: its adapter, passed
   to `AppModel`'s initializer (Composition root, above).

**A new OS integration** (notifications, location, photos, purchases): the same port and
adapter shape. The framework import lives only in `FlashComposePlatform`; the permission's
usage-description string goes in `project.yml` as an `INFOPLIST_KEY_…` setting; the
decision of when to ask lives in Core.

**A new stored model**: a new `@Model` in the next schema version, never an edit to a
shipped one.
