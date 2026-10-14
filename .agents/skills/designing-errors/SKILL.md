---
name: designing-errors
description: >
  Covers how errors are designed in this Swift 6 repository: error enums declared in
  FlashComposeCore, typed throws(SomeError) versus plain throws, what an error payload and an
  AppLog (os.Logger) message may carry, propagating CancellationError instead of
  swallowing it, and how a FlashComposePlatform adapter maps a SwiftData or Foundation error
  (NSError, CocoaError) into a Core error. Use when adding or changing an Error type, a
  throwing function or port, a do/catch, a Task that can be cancelled, or an adapter
  that calls a failing framework API.
---

# Designing Errors

**Owns:** the shape of an error type, the choice between typed and untyped `throws`,
what an error and its log line may contain, cancellation, and the framework-to-Core
error mapping at the adapter boundary. **Does not own:** writing the failing test first
(`tdd`); how Core logic is shaped around time and state (`designing-core-logic`); the
`os.Logger` basics (`.claude/rules/swift.md` › Logging); the error-path test rule
(`.claude/rules/testing.md` › What to Test).

## Where an error type lives

- Declare every error a caller can observe in `FlashComposeCore`, next to the port or model
  that throws it — `ProgressStore.swift` holds `ProgressStoreError`. A Core view model
  catches it, and the fake in `Tests/FlashComposeTestSupport` throws it, so it cannot live
  in `FlashComposePlatform` (Core never imports Platform).
- One `enum` per failure domain, `Error, Equatable, Sendable`. Cases name what went
  wrong for the caller (`.unavailable`, `.storageFailure`), not which API failed.
- A case carries a payload only when a caller needs it to decide, and the payload is a
  `Sendable` value: an identifier, a small enum, a count, a duration —
  `FSRSWeightsError.wrongCount(Int)` carries how many weights were given. Never an
  `NSError` or an underlying `any Error` — those are not `Equatable`, often not
  `Sendable`, and leak the adapter's mechanism into Core.

The worked example, as `ProgressStore.swift` declares it (doc comments trimmed). No case
carries a payload: the drill does the same thing whichever card a failure touched, so
the detail stays in the adapter's log.

```swift
public enum ProgressStoreError: Error, Equatable, Sendable {
    case corruptedRecord
    case storageFailure
    case unavailable
}
```

## Typed throws or plain throws

Typed throws (`throws(ProgressStoreError)`, SE-0413) needs Swift 6.0
(<https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md>,
"Implemented (Swift 6.0)", checked 2026-09-30); this package is
`swift-tools-version: 6.4` in Swift 6 language mode, so it is available everywhere.

- **Use `throws(E)`** when the caller decides by `E`'s cases: a port method, a
  view-model action whose UI shows per-case recovery. The `catch` then binds `error` as
  `E`, a `switch` over it is exhaustive, and adding a case breaks every caller that must
  handle it — which is the point.
- **Use plain `throws`** when the caller only propagates or reports failure, or when
  the body calls several throwing APIs of unrelated types. Forcing a typed throw there
  means wrapping every inner error for no decision anyone makes.
- Never `throws(any Error)` (it is plain `throws`) and never a catch-all case such as
  `.unknown(any Error)` to make a typed throw compile — map to a real case instead.

`ProgressStore` throws `ProgressStoreError` from both methods, so a caller handles a
closed set of cases and never learns which store failed. `DrillStartup` keeps the type
without a cast — the `catch` binds `error` as `ProgressStoreError`:

```swift
do {
    return try await .success(store.loadProgress())
} catch {
    return .failure(error)  // error is a ProgressStoreError here
}
```

`PersistenceStore.makeContainer(storage:)` stays on plain `throws`: its one caller,
`App/`, only falls back to `UnavailableProgressStore` whatever SwiftData threw.

An empty result is not a failure: `loadProgress()` on a first launch returns `[]`, and an
error is for "could not find out". A part that cannot be read is not a failure of the
whole either, where the port says so: `loadProgress()` leaves out a stored row it cannot
read back and throws only when the store as a whole cannot be read, so one damaged row
never costs the learner every other card.

## No user data in errors or logs

- An error payload never holds user content: no card text, typed text, file paths,
  URLs, or identifiers of the user's documents outside the app. Errors travel — into
  logs, crash reports, test output, and `String(describing:)`. `CardIDError` names the
  rule that failed and carries nothing of the rejected string; `CatalogError` carries no
  path, key, or decoder message, which can quote card text.
- Log lines follow `.claude/rules/swift.md` › Logging: `AppLog`'s `os.Logger` only.
  Interpolate an error code or an enum case with `privacy: .public`; anything that came
  from the user with `privacy: .private` — or leave it out. `os.Logger` redacts dynamic
  strings by default; do not mark one `.public` to make a log easier to read.
- Log once, where the error is handled, not at every layer it passes through.

## Cancellation propagates

`CancellationError` means the caller no longer wants the result. It is not a failure
to report.

- Do not catch it into a Core error case, a log line, or an error state. A plain
  `catch` in an `async throws` function must rethrow it:

```swift
do {
    try await clock.sleep(for: .seconds(1))
    try await refresh()
} catch let error as CancellationError {
    throw error  // cancellation is not a failure: never log or map it
} catch {
    AppLog.drill.error("refresh failed")
}
```

- A long loop calls `try Task.checkCancellation()` rather than polling
  `Task.isCancelled` and returning a half result silently.
- Typed throws and cancellation: a function that awaits cancellable work and declares
  `throws(E)` cannot throw `CancellationError`. Keep such functions on plain `throws`,
  or give `E` an explicit `.cancelled` case the caller treats as a no-op — never drop
  the cancellation on the floor.
- A port that cannot observe cancellation gets no `.cancelled` case. A local store does
  its work on its own actor without checking for cancellation, so
  `ProgressStoreError` has none. A `@MainActor` view-model action that awaits such a
  port reads `Task.isCancelled` after the `await`, whatever the call returned or threw,
  and treats it as a no-op — no failure reported, no error state, nothing logged — since
  a store that saw its caller cancel can only answer with a failure case.
  `DrillViewModel.start()` is the worked example: it reads `Task.isCancelled` after both
  loads and puts `phase` back to what it was before the start-up. A port that can
  observe it declares a `.cancelled` case instead, and its caller switches on it.
- A test asserts cancellation with `#expect(throws: CancellationError.self)`.

## Mapping framework errors in an adapter

The adapter translates, never decides (`AGENTS.md` › Architecture). Mapping a framework
error to a Core case is translation; choosing what the app does about it is Core's.

- Convert at the call site, inside `FlashComposePlatform`, into the Core enum the port
  declares. Nothing framework-typed crosses the port.
- **SwiftData.** `ModelContext.save()` and `fetch(_:)` throw. `SwiftDataProgressStore`
  catches at the call site and maps to `ProgressStoreError.storageFailure`, or to
  `.corruptedRecord` where the adapter itself decides the case (a stored row whose card
  id, practice day, or answer kind no longer makes a Core value: `CardProgressRecord`'s
  `progress()`, `StoredDay`, `StoredKind`). Its `record(answer:progress:)`, with the
  test-only fault seam trimmed:

```swift
do {
    if let existing = try progressRecord(cardID: progress.cardID.rawValue) {
        existing.update(from: progress)
    } else {
        modelContext.insert(CardProgressRecord(progress))
    }
    modelContext.insert(AnswerRecord(answer))
    try modelContext.save()
} catch {
    modelContext.rollback()
    throw Self.storageFailure(error, during: "record")
}
```

  A failed save leaves the change pending in the context, so the `catch` rolls it back;
  otherwise the next successful save would write it after all.
  `storageFailure(_:during:)` logs the framework error `.private` (SwiftData's messages
  can quote stored values) under `AppLog.persistence` and returns `.storageFailure`.
- **Foundation.** An `NSError` or `CocoaError` is mapped by its `code` to a Core case
  for the codes the adapter knows; every other code goes to the domain's general
  failure case. The `domain` and `code` go to the log with `privacy: .public`; the
  `localizedDescription` and `userInfo` never go into an error payload, since they can
  carry paths and user content.

```swift
let nsError = error as NSError
AppLog.persistence.error(
    "read failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)",
)
```

A Platform test checks the mapping under plain `swift test` (`just test`) when the
framework runs on the host — SwiftData with an in-memory store does
(`SwiftDataProgressStoreReadBackTests` asserts `.corruptedRecord` for a stored day that
names no date and for a damaged answer row). A Core test checks the decision with the
fake, which throws each Core case on demand (`InMemoryProgressStore.fail(_:with:)`).

## Checklist

- The error enum is in `FlashComposeCore`, `Error, Equatable, Sendable`, and any payload
  is a `Sendable` value.
- `throws(E)` only where a caller decides on `E`; plain `throws` otherwise.
- No user content in a payload; logs use `AppLog` with explicit privacy.
- `CancellationError` is rethrown, never logged or mapped to a failure.
- The adapter maps every framework error to a Core case; nothing framework-typed
  crosses the port.
- Each case has an error-path test asserting the case and any payload.
