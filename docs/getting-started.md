# Getting Started

## Prerequisites

- [Xcode][xcode], the version in `.xcode-version` (CI pins
  exactly that one), **with its iOS platform installed** — Xcode › Settings › Components.
  `xcode-select --install` alone is not enough: the app target needs the full IDE and
  an iOS Simulator runtime.
- [mise][mise] — installs the pinned CLI tools from `mise.toml`
- [Just][just] (optional — every recipe's
  underlying commands are plain shell; see [CONTRIBUTING.md](../CONTRIBUTING.md))

## Setup

```bash
git clone https://github.com/tomada1114/flash-compose.git
cd flash-compose
mise trust     # approve this repo's mise.toml (asked once per clone)
just install
just check
```

mise refuses to read config files it has not been told to trust, so a fresh clone
needs `mise trust` first. `just install` then runs `mise install` (SwiftLint,
SwiftFormat, XcodeGen, xcbeautify, actionlint, ShellCheck, typos — all pinned), points
`core.hooksPath` at `.githooks/` for the pre-commit gate, and generates
`FlashCompose.xcodeproj`. `just check` runs the full local gate once, so you start from green.

## Everyday Commands

```bash
just check     # the full local gate: verify-hooks → fmt → lint → test-scripts → check-harness → test → build
just test      # Swift Testing suites on the host Mac + 80% line / 75% function coverage floors on FlashComposeCore
just test-fast TodoItemTests   # only the matching tests, no coverage floor (while iterating)
just uitest    # the XCUITest launch test on an iOS Simulator
just test-ios  # every package test suite on an iOS Simulator (no coverage floor)
just smoke     # Release build + "does it actually launch" assertion
```

[CONTRIBUTING.md](../CONTRIBUTING.md) lists every recipe.

## Running on the Simulator

```bash
just run                                   # build (Debug), install, and launch on a simulator
SIMULATOR_DEVICE="iPhone 17 Pro" just run  # choose the device by name (or UDID)
just logs                                  # stream this app's log output; Ctrl-C to stop
just reset-permissions                     # forget this app's privacy grants on the booted simulator
```

`just run` boots the simulator, brings Device Hub (Xcode 27's
replacement for Simulator.app) to the front, and replaces any
running copy of the app with the fresh build. `just logs` follows the subsystem the
app logs under (`AppLog`, which is the bundle identifier). After `just reset-permissions`
the next request for a permission prompts again, as on a fresh install.

## Running on your own iPhone

```bash
just run-device                      # build (Debug), install, and launch on a connected iPhone
IOS_DEVICE="<name or UDID>" just run-device   # when more than one device is connected
```

It needs a one-time `Config/Local.xcconfig` holding your development team, which is
gitignored and never committed. [Running on your own iPhone](running-on-device.md)
covers the setup, the bundle identifier, and a free Personal Team's limits.

## Removing the example code

The to-do list is an illustration for a new app to replace — example code in a skill
or a doc is likewise a sketch of the pattern, never something the app must keep. Work
through this list after `scripts/bootstrap.sh` (the paths below carry your app's name
once it has run).

**Core:**

- [ ] `Packages/FlashComposeKit/Sources/FlashComposeCore/TodoItem.swift` — the domain value
- [ ] `Packages/FlashComposeKit/Sources/FlashComposeCore/TodoRepository.swift` — the port and its
      error type, and its null object
      `Packages/FlashComposeKit/Sources/FlashComposeCore/UnavailableTodoRepository.swift`
- [ ] `Packages/FlashComposeKit/Sources/FlashComposeCore/TodoListViewModel.swift` and
      `Packages/FlashComposeKit/Sources/FlashComposeCore/TodoDetailViewModel.swift` — the view models
- [ ] `AppModel.todoList` and `AppModel.makeTodoDetailViewModel(id:)` in
      `Packages/FlashComposeKit/Sources/FlashComposeCore/AppModel.swift` — put your own shared view
      models and route factories there instead
- [ ] `Packages/FlashComposeKit/Sources/FlashComposeCore/TodoListStrings.swift` and
      `Packages/FlashComposeKit/Sources/FlashComposeCore/TodoDetailStrings.swift` — the wording
- [ ] The `todoList.*` and `todoDetail.*` keys in
      `Packages/FlashComposeKit/Sources/FlashComposeCore/Resources/Localizable.xcstrings`, and the
      `TodoListStrings` and `TodoDetailStrings` cases in
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/LocalizationTests.swift`
- [ ] `AppLog.todos`, the `todos` log category, in
      `Packages/FlashComposeKit/Sources/FlashComposeCore/AppLog.swift` — add a `Logger` for your own
      concern instead
- [ ] The Core tests: `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/TodoItemTests.swift`,
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/TodoListViewModelTests.swift`,
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/TodoListViewModelEditingTests.swift`,
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/TodoListViewModelHideCompletedTests.swift`,
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/TodoListViewModelLookupTests.swift`,
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/TodoListViewModelFixture.swift`,
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/TodoDetailViewModelTests.swift`, the to-do
      cases in `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/AppModelTests.swift`, and
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/TodoRepositoryContractTests.swift`

**Platform:**

- [ ] The adapter
      `Packages/FlashComposeKit/Sources/FlashComposePlatform/Persistence/SwiftDataTodoRepository.swift`,
      and `TodoRecord` in the schema
      `Packages/FlashComposeKit/Sources/FlashComposePlatform/Persistence/AppSchemaV1.swift` with its
      typealias in
      `Packages/FlashComposeKit/Sources/FlashComposePlatform/Persistence/AppMigrationPlan.swift` — keep
      the schema, the plan, and
      `Packages/FlashComposeKit/Sources/FlashComposePlatform/Persistence/PersistenceStore.swift` for
      your own `@Model` types (editing V1 is safe only while no build has shipped), or
      remove the whole `Persistence/` directory, and the container in `App/`, if the app
      keeps no SwiftData store
- [ ] Its tests: `Packages/FlashComposeKit/Tests/FlashComposePlatformTests/SwiftDataTodoRepositoryTests.swift`,
      `Packages/FlashComposeKit/Tests/FlashComposePlatformTests/PersistenceStoreTests.swift`, and the
      frozen schema copy `Packages/FlashComposeKit/Tests/FlashComposePlatformTests/PreRenameSchemaV1.swift`

**Test support:**

- [ ] The fake `Packages/FlashComposeKit/Tests/FlashComposeTestSupport/InMemoryTodoRepository.swift`
      and the contract `Packages/FlashComposeKit/Tests/FlashComposeTestSupport/TodoRepositoryContract.swift`

**UI:**

- [ ] `Packages/FlashComposeKit/Sources/FlashComposeUI/TodoListView.swift`,
      `Packages/FlashComposeKit/Sources/FlashComposeUI/TodoDetailView.swift`, and
      `Packages/FlashComposeKit/Sources/FlashComposeUI/TodoDoneToggle.swift`
- [ ] The previews' repository: `Packages/FlashComposeKit/Sources/FlashComposeUI/PreviewTodoRepository.swift`

**App:**

- [ ] `makeRepository()` in `App/FlashComposeApp.swift`, and the `TodoRepository` it hands
      to `AppModel` — wire your own port's adapter there
- [ ] The `TodoListView` root screen and the `.todoDetail` branch of
      `Packages/FlashComposeKit/Sources/FlashComposeUI/RootView.swift` — your first screen and your
      routes' screens go there

**UI tests:**

- [ ] `LaunchUITests/LaunchTests.swift` — every test adds, opens, deletes, or hides a
      to-do; point them at what your first screen shows

**Routing:**

- [ ] `AppRoute.todoDetail` in `Packages/FlashComposeKit/Sources/FlashComposeCore/Navigation/AppRoute.swift`,
      the `todo` host `Packages/FlashComposeKit/Sources/FlashComposeCore/Navigation/DeepLink.swift`
      parses, and the cases that use them in
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/DeepLinkTests.swift` and
      `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/NavigationModelTests.swift`

**Preferences:**

- [ ] `PreferenceKeys.hideCompleted` in
      `Packages/FlashComposeKit/Sources/FlashComposeCore/Preferences/PreferenceKeys.swift`, its
      line in `Packages/FlashComposeKit/Tests/FlashComposeCoreTests/PreferenceKeysTests.swift`, and
      the `init(hideCompleted:)` that reads it in
      `Packages/FlashComposeKit/Sources/FlashComposeUI/PreviewPreferences.swift`

**Keep, as the pattern your own code copies:**

- The port/fake/contract shape: a `Sendable` protocol in Core, its adapter in
  `FlashComposePlatform`, one fake and one contract function in `FlashComposeTestSupport` — the
  `TodoRepository` files above are the worked example until your first port exists
- `HTTPClient` — `Packages/FlashComposeKit/Sources/FlashComposeCore/Networking/HTTPClient.swift`
  and `Packages/FlashComposeKit/Sources/FlashComposePlatform/Networking/URLSessionHTTPClient.swift`
- `PreferencesStoring` — `Packages/FlashComposeKit/Sources/FlashComposeCore/Preferences/PreferencesStoring.swift`
  and `Packages/FlashComposeKit/Sources/FlashComposePlatform/Preferences/UserDefaultsPreferences.swift`
- `NavigationModel` — `Packages/FlashComposeKit/Sources/FlashComposeCore/Navigation/NavigationModel.swift`
- `AppModel` — `Packages/FlashComposeKit/Sources/FlashComposeCore/AppModel.swift` — and `RootView` —
  `Packages/FlashComposeKit/Sources/FlashComposeUI/RootView.swift`: the shared view models, the route
  factories, and the one navigation stack
- `DesignTokens` — `Packages/FlashComposeKit/Sources/FlashComposeUI/DesignSystem/DesignTokens.swift`
- `AppLog` — `Packages/FlashComposeKit/Sources/FlashComposeCore/AppLog.swift`

**An order that keeps `just check` green at each step:**

1. Add your own Core model, view model, and their tests beside the example, so the
   coverage floor always has something to measure.
2. Put your first screen's view model on `AppModel` and the screen at the root of
   `RootView`, in place of `todoList` and `TodoListView`; wire your adapter in
   `App/FlashComposeApp.swift` in place of `makeRepository()`; and point
   `LaunchUITests/LaunchTests.swift` at it (`just uitest`).
3. Delete the UI files and the previews' repository.
4. Replace `AppRoute.todoDetail` and the `todo` deep link with a route of your own,
   updating `DeepLinkTests` and `NavigationModelTests` in the same step, and replace
   `AppModel.makeTodoDetailViewModel(id:)` and `RootView`'s `.todoDetail` branch with
   your route's factory and screen.
5. Delete `TodoListViewModel` and `TodoDetailViewModel` with their tests (the four
   `TodoListViewModel*Tests.swift` files, `TodoDetailViewModelTests.swift`, the to-do
   cases in `AppModelTests.swift`, and `TodoListViewModelFixture.swift`), the two
   strings files, their catalog keys, and their `LocalizationTests` cases together.
6. Delete `PreferenceKeys.hideCompleted` with its `PreferenceKeysTests` line and
   `PreviewPreferences`' `init(hideCompleted:)` in
   `Packages/FlashComposeKit/Sources/FlashComposeUI/PreviewPreferences.swift` — a stored key's
   removal is a migration for any app already installed, so do it before you ship.
7. Delete the Platform persistence files and their test, then the fake, the contract,
   and `TodoRepositoryContractTests`, then `TodoRepository`,
   `UnavailableTodoRepository`, `TodoItem` with `TodoItemTests`, and `AppLog.todos`.

`rg -i 'todo'` then lists anything left — including the mentions in `AGENTS.md`,
`docs/architecture.md`, `.claude/rules/`, and the skills that cite the to-do list as
the worked example (skills are edited under `.agents/skills/`, then `just agents-sync`).

## Open in Xcode

```bash
just generate
open FlashCompose.xcodeproj
```

Remember: `FlashCompose.xcodeproj` is generated from `project.yml` and gitignored. Change
targets and settings in `project.yml`, then `just generate`.

## App Icon

The template ships `App/Assets.xcassets/AppIcon.appiconset` with empty 1024×1024 slots
(default, dark, and tinted) — the app builds and runs without icon artwork. Add yours either as an image in that asset
catalog (Xcode › the App target's Assets), or as an Icon Composer `.icon` file, which
gives the iOS 26 layered, Liquid Glass icon. Which one, and what it looks like, is an
app decision: record it in the app's design lock, as the `designing-ui` skill
([SKILL.md](../.agents/skills/designing-ui/SKILL.md)) says.

[xcode]: https://developer.apple.com/xcode/
[mise]: https://mise.jdx.dev/
[just]: https://just.systems/man/en/installation.html
