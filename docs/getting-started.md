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
just test-fast ScopeSelectionTests   # only the matching tests, no coverage floor (while iterating)
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

## The worked examples

Example code in a skill or a doc is a sketch of a pattern, never something the app must
keep; the drill's files are the real instance of each pattern a new concern copies.
Read these before adding one of your own:

- **A port, its adapter, its fake, and its contract:** the `Sendable` protocol
  `Packages/FlashComposeKit/Sources/FlashComposeCore/Progress/ProgressStore.swift`, with its
  null object `UnavailableProgressStore.swift` beside it; the adapter
  `Packages/FlashComposeKit/Sources/FlashComposePlatform/Persistence/SwiftDataProgressStore.swift`
  over the schema `AppSchemaV1.swift`, the plan `AppMigrationPlan.swift`, and the one
  container `PersistenceStore.swift`; the fake
  `Packages/FlashComposeKit/Tests/FlashComposeTestSupport/InMemoryProgressStore.swift` and the
  contract `Packages/FlashComposeKit/Tests/FlashComposeTestSupport/ProgressStoreContract.swift`,
  which `ProgressStoreContractTests` runs against the fake and
  `SwiftDataProgressStoreTests` against the adapter
- **Preferences:** `PreferencesStoring` —
  `Packages/FlashComposeKit/Sources/FlashComposeCore/Preferences/PreferencesStoring.swift` —
  and `Packages/FlashComposeKit/Sources/FlashComposePlatform/Preferences/UserDefaultsPreferences.swift`,
  with the stored keys in `PreferenceKeys.swift`, pinned by `PreferenceKeysTests`
- **View models:** `DrillViewModel` —
  `Packages/FlashComposeKit/Sources/FlashComposeCore/Drill/DrillViewModel.swift` — and
  `ScopeViewModel` in `Packages/FlashComposeKit/Sources/FlashComposeCore/Scope/`, with their
  wording in `DrillStrings` and `ScopeStrings` and the catalog
  `Packages/FlashComposeKit/Sources/FlashComposeCore/Resources/Localizable.xcstrings`
- **The composition root:** `AppModel` —
  `Packages/FlashComposeKit/Sources/FlashComposeCore/AppModel.swift`, the shared view models
  built over the ports — `RootView` —
  `Packages/FlashComposeKit/Sources/FlashComposeUI/RootView.swift`, the one navigation stack
  and the one failure alert — and `App/FlashComposeApp.swift`, which picks each port's
  adapter
- **Navigation:** `NavigationModel` and `DeepLink` in
  `Packages/FlashComposeKit/Sources/FlashComposeCore/Navigation/`
- **`DesignTokens`:** `Packages/FlashComposeKit/Sources/FlashComposeUI/DesignSystem/DesignTokens.swift`
- **`AppLog`:** `Packages/FlashComposeKit/Sources/FlashComposeCore/AppLog.swift` — one
  `Logger` per concern
- **The launch test:** `LaunchUITests/LaunchTests.swift`, which reveals and grades a card

When new code replaces old, add it and its tests beside the old code first, so the
coverage floor always has something to measure, and keep `just check` green at each
step. A stored preference key's removal is a migration for any app already installed.

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
