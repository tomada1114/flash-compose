---
name: building-swiftui-screens
description: >
  Covers writing an iOS SwiftUI view in FlashComposeUI as a thin renderer over a FlashComposeCore
  @Observable view model - how the view receives and holds its model (@State, a plain
  property, @Bindable, a Binding built from an action), what may sit in body,
  NavigationStack and navigationDestination, sheets and alerts driven by view-model
  state, horizontalSizeClass layouts for iPhone and iPad, Dynamic Type with text styles,
  ScaledMetric and ViewThatFits, safe areas and safeAreaInset, the keyboard with
  FocusState, submitLabel and onSubmit, 44-point touch targets, iOS-only modifiers
  behind #if os(iOS), #Preview per state, accessibility identifiers for LaunchUITests,
  accessibility labels, Reduce Motion, and how a screen is verified. Use when adding or
  changing a view, a subview, or a preview under the local package's Sources/FlashComposeUI,
  wiring a view to a view model in App/, adding an accessibilityIdentifier, or fixing an
  accessibility_label_for_image or no_magic_numbers violation in a view.
---

# Building SwiftUI Screens

**Owns:** how a view in `FlashComposeUI` is written — how it gets its view model, what it may
contain, how it navigates and presents, how it adapts to size class, text size, and the
keyboard, its previews, and its accessibility wiring. **Does not own:** the view model's
shape, state, and actions (`designing-core-logic`); what the screen looks like — color,
type, spacing, the design lock (`designing-ui`); a system API behind a port
(`integrating-system-apis`); which device families the app ships (`starting-an-app`);
launching the app and the evidence a pull request carries (`running-the-app`).

## The rule, and why

A view renders Core state and forwards user intent to a Core action; it decides nothing.
`FlashComposeUI` is outside the coverage floor — `scripts/coverage.sh` measures `FlashComposeCore`
only — so any branch that lives in a view is a branch no gate tests. `DrillView` over
`DrillViewModel` is the worked example; copy its shape.

- A view is a `struct` in `FlashComposeUI` importing `SwiftUI` and `FlashComposeCore`, never
  `FlashComposePlatform`. Enforced by: `ArchitectureBoundaryTests`' sibling-import tests.
- It is `public` only when `App/` constructs it (`RootView`); a screen and its subviews
  stay internal (`DrillView`, `GradeBar`) or `private` (`GradeBar`'s `GradeButton`).

## Getting the view model

- **A model with a port is built by Core's `AppModel`**, never in a view: the adapter
  lives in `FlashComposePlatform`, which this module must not import, so `App/` hands the
  adapters to `AppModel` as ports and `AppModel` builds the models over them
  (`docs/architecture.md` › Composition root). `FlashComposeApp` keeps the `AppModel` in
  `@State` for the whole app; its private `SceneRoot` keeps a `NavigationModel` in
  `@State` per scene, so each window navigates on its own, and passes both to
  `RootView(app:navigation:)`.
- **A model every scene shares** is a stored property of `AppModel`, which `RootView`
  hands to its screen: `DrillView(model: app.drill, startup: app.startupIndicator)`.
- **A pushed screen's own model** comes from a named `AppModel` factory for its route
  (`make…ViewModel(…)`), called in `RootView`'s destination switch; none exists while
  `AppRoute` has no case. The screen keeps it in `@State private var model`, set with
  `_model = State(initialValue: model)`, so it holds the first model for as long as it
  is pushed and ignores the fresh one a parent re-render builds.
- **A view handed its model** holds it as a plain `let`, as `DrillView` does;
  `@Observable` re-renders the view when a property its `body` read changes. `@Bindable`
  only where a control binds to a settable property: `RootView` takes it for
  `NavigationModel`, so the stack can bind `path`.
- **A view that owns a portless model** holds it in `@State private var model`, set with
  `_model = State(initialValue: model)` from an initializer parameter, so a preview can
  inject a state.
- **A binding to state the view may not set** is built from an action: the shared
  `failureAlert(_:dismiss:)` modifier (`FailureAlert.swift`) reads `failure != nil` and
  calls the `dismiss` action it is handed. Never widen a `private(set)` to let
  `@Bindable` reach it.
- Not used here: `ObservableObject`, `@StateObject`, `@ObservedObject`,
  `@EnvironmentObject`. Initializer parameters carry a model (`designing-core-logic`).

## What `body` may contain

| Belongs in the view | Belongs in the Core view model |
|---|---|
| Layout, modifiers, the order things appear in | Whether an action is allowed now (`grade(_:)` ignores a grade while `isGrading`) |
| Choosing a layout from the size class or text size | Any rule, threshold, or comparison on domain values |
| Calling an action from a `Button`, `.onSubmit`, `.refreshable`, `.onDelete` | What the action does and the state it leaves |
| *When* to ask — `.task`, as `DrillView` starts the drill on first appearance | *What* asking means (`start()`), and which face shows (`phase`) |
| `Text(verbatim:)` for card content, which is data (`card.card.japanese`) | Every word a person reads, as a `LocalizedStringResource` (`DrillStrings`) |

- An action that waits is `async`; call it from `.task` (cancelled with the view) or a
  `Task { }` in a button's closure.
- Spacing, radius, and hit-target numbers come from `DesignTokens` in `FlashComposeUI`
  (`DesignTokens.Spacing.medium`), whose values the design lock sets (`designing-ui`); a
  number only one view needs goes in a `private enum Layout` in that view's file.
  Enforced by: `opt_in_rules: all`, which turns on `no_magic_numbers`.
- When `body` nears `function_body_length`, extract a subview `struct` taking exactly the
  slice it renders, as `DrillHeaderView` (handed `model.header`) and `GradeBar` (handed
  the card's grade options) do.

## Navigation

- One `NavigationStack(path:)` per navigation root, bound to Core's `NavigationModel`
  (`docs/architecture.md` › Navigation). It lives in `RootView`, never in a screen:
  `DrillView` is a plain screen at the stack's root. `AppRoute` has no case yet, so the
  stack declares no `navigationDestination`. The first pushed screen adds an `AppRoute`
  case, one value-based `navigationDestination(for: AppRoute.self)` in `RootView` with
  a branch per route — building its model through an `AppModel` factory when it needs
  one — and a `NavigationLink(value:)` that pushes the route; never navigation state in
  a view's `@State`.
- A screen's previews give it the stack `RootView` would: wrap it in a plain
  `NavigationStack { … }`, as `DrillPreview` does.
- A button inside a `NavigationLink` row takes a non-default style
  (`.buttonStyle(.borderless)`), or a tap on it follows the link.
- `NavigationSplitView` only for a regular-width iPad layout the design lock asks for;
  on iPhone it collapses to a stack anyway.

## Sheets and alerts

- Whether something is presented is view-model state: a `Bool`, or an optional value
  (`DrillViewModel.failure`) whose presence presents it.
  Bind through an action-built `Binding`, so every dismissal route — a button, a swipe,
  the system — goes through the action. `FailureAlert.swift` is the example.
- **A failure is presented once, from `RootView`, outside the `NavigationStack`**, with
  `.failureAlert(_:dismiss:)`, never by an `.alert` on a screen: an alert attached to a
  screen inside the stack does not present while another screen is pushed over it, so a
  failure on a pushed screen would show nothing until the user went back (#78). A
  feature's failure type adopts Core's `PresentableFailure` (a `title` and a `message`
  as `LocalizedStringResource`), as `DrillFailure` does; a second feature's failure
  is one more `.failureAlert` beside the first in `RootView`.
- `.presentationDetents` and other sheet sizing only as the design lock says.

## Size classes, Dynamic Type, safe areas

- **Size class** chooses a layout, never a behavior: read
  `@Environment(\.horizontalSizeClass)` in the view, and keep every decision in Core
  identical for both. Preview both: `.environment(\.horizontalSizeClass, .regular)`.
  Whether iPad ships at all is `starting-an-app`'s decision.
- **Dynamic Type:** text styles only (`.font(.body)`), never a fixed point size.
  `@ScaledMetric` for a dimension that must grow with text (an icon beside a label). A
  layout that cannot fit at accessibility sizes switches with `ViewThatFits`, or on
  `dynamicTypeSize.isAccessibilitySize` (for example, an `HStack` becoming a `VStack`).
  Preview at `.dynamicTypeSize(.accessibility3)`.
- **Safe areas:** never hard-code an inset or a device height. A bar pinned to an edge
  is `.safeAreaInset(edge:)`, as `DrillView`'s bottom bar is, so the card is inset by
  the bar's height and never hidden behind it.

## The keyboard

The app has no text field today; these hold for the first one.

- `@FocusState` for which field has focus; set it from an action's result, not a timer.
- `.submitLabel` names the return key and `.onSubmit` calls the Core action.
- `.scrollDismissesKeyboard(.interactively)` on a scrolling form.

## Touch targets and iOS-only modifiers

- Every tappable element is at least 44×44 pt (HIG). An icon-only button reaches it with
  `.contentShape(Rectangle())` over a frame of `DesignTokens.Size.minimumHitTarget`. A
  custom button takes a `.plain` style, a minimum height, and a `.contentShape` of its
  own shape, as `PrimaryActionButton` (50 pt) and `GradeBar`'s buttons (64 pt) do.
- A large hit region over content is a `.plain` `Button` in `.background { … }`, marked
  `.accessibilityHidden(true)`, never `.onTapGesture`, which fails SwiftLint's
  `accessibility_trait_for_button` (an `.isButton` trait would mislead VoiceOver).
  `QuestionFace` makes the whole card reveal the answer this way: the content in front
  takes `.allowsHitTesting(false)`, so a tap on the prompt falls through to the button,
  and VoiceOver reaches the reveal through the Show answer button instead.
- A text field padded out to the target is a trap: a plain `TextField` takes focus only
  from a tap on its own text line, so the padding is dead. Draw the fill with the same
  background `Button`, setting a `@FocusState`, so VoiceOver still reaches the field.
- `FlashComposeUI` also compiles for macOS under `swift build`, so an iOS-only modifier —
  `.navigationBarTitleDisplayMode`, `.keyboardType`, `.textInputAutocapitalization` —
  sits inside `#if os(iOS)`, as `DrillView`'s `.navigationBarTitleDisplayMode(.inline)`
  does. `swift build` fails when one is missed, so `just test` catches it.

## Previews

- One `#Preview("Name")` per state worth seeing, over a view model Core brought to that
  state, never values written for the preview. `DrillPreview` drives a real
  `DrillViewModel` over a one-card catalog through its actions (`reveal()`,
  `grade(_:)`) — "D1 new", "D2 dark", "D2 longest card, AX5", "D3" — over the Debug-only
  `PreviewProgressStore`, `PreviewProgressStore(failsRecords: true)` for "D2 save failed
  (E2)", or Core's `UnavailableProgressStore` for "E1". Previews sit under `#if DEBUG`
  and never construct a `FlashComposePlatform` adapter.
- Add a dark preview (`.preferredColorScheme(.dark)`), a regular-width one for an iPad
  layout, and an accessibility-size one for a screen that shows text.
- No `try!` or force unwrap in a preview (`.claude/rules/swift.md`).
- Previews compile with the module but nothing checks what they render. Look.

## Accessibility

- **Identifiers are a test contract.** Every element a UI test touches carries a stable,
  unlocalized `.accessibilityIdentifier` — `showAnswerButton`, `grade-again`,
  `grade-hard`, `grade-good`, `drillPrompt`, `modelAnswer`, `drillHeader`, `drillDone`,
  `retryButton`, `drillStartFailure`. `LaunchTests` taps `showAnswerButton` and
  `grade-good` and reads `drillHeader`'s label, so a rename changes the test in the same
  commit.
- **Labels are what VoiceOver says.** A control whose visible text is not what VoiceOver
  should say gets `.accessibilityLabel` from a Core `LocalizedStringResource`, as
  `GradeBar`'s buttons do with `GradeOption.accessibilityLabel` (the grade and its
  interval in one phrase). A decorative image is `Image(decorative:)` or
  `.accessibilityHidden(true)`. Enforced by: `accessibility_label_for_image` and
  `accessibility_trait_for_button`; neither sees a glyph-only text button — review does.
- **Group** a value and its caption with `.accessibilityElement(children: .combine)`.
- **Motion:** an animation checks `@Environment(\.accessibilityReduceMotion)` and falls
  back to none or a cross-fade.
- **Check by hand**: Accessibility Inspector against the Simulator, and a VoiceOver
  pass. Say in the pull request what was checked.

## Verifying a screen

1. `just test` — the view model's behavior, and `swift build` of the view for macOS.
2. `just build` — the view and its previews compile for iOS; `just lint` for the view rules.
3. `just uitest` — when an identifier the launch test reads, or the first screen, changed.
4. `just run`, then screenshots per `running-the-app` in light, dark, and the largest
   Dynamic Type size, on the smallest iPhone the simulator list offers
   (`SIMULATOR_DEVICE="<name>" just run`) — and a regular-width iPad while iPad ships.

## Sources

All checked 2026-09-30.

- [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack), [navigationDestination(for:destination:)](https://developer.apple.com/documentation/swiftui/view/navigationdestination(for:destination:)), [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [presentationDetents(_:)](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:)), [horizontalSizeClass](https://developer.apple.com/documentation/swiftui/environmentvalues/horizontalsizeclass)
- [ScaledMetric](https://developer.apple.com/documentation/swiftui/scaledmetric), [ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits), [isAccessibilitySize](https://developer.apple.com/documentation/swiftui/dynamictypesize/isaccessibilitysize), [dynamicTypeSize(_:)](https://developer.apple.com/documentation/swiftui/view/dynamictypesize(_:))
- [safeAreaInset(edge:alignment:spacing:content:)](https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)), [FocusState](https://developer.apple.com/documentation/swiftui/focusstate), [submitLabel(_:)](https://developer.apple.com/documentation/swiftui/view/submitlabel(_:)), [scrollDismissesKeyboard(_:)](https://developer.apple.com/documentation/swiftui/view/scrolldismisseskeyboard(_:))
- [HIG › Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) — "a hit region of at least 44x44 pt"; [HIG › Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [navigationBarTitleDisplayMode(_:)](https://developer.apple.com/documentation/swiftui/view/navigationbartitledisplaymode(_:)), [keyboardType(_:)](https://developer.apple.com/documentation/swiftui/view/keyboardtype(_:)), [textInputAutocapitalization(_:)](https://developer.apple.com/documentation/swiftui/view/textinputautocapitalization(_:))
- [Migrating to the Observable macro](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro), [accessibilityIdentifier(_:)](https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)), [accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion), [Previews in Xcode](https://developer.apple.com/documentation/swiftui/previews-in-xcode)
