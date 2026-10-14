# FlashCompose — Design Direction

- **Status:** Settled with the owner 2026-10-13 (kickoff). The research record; the
  binding lock is the present-state "Design lock" section of `docs/design-system.md`,
  where `designing-ui` keeps it.
- **Platform:** iPhone only, portrait, iOS 27 (`tomada1114/ios-template`: system-first —
  semantic colors, text styles, Dynamic Type, standard components with Liquid Glass).
- **Inputs:** [requirements.md](../product/requirements.md), [ux-flows.md](../product/ux-flows.md) (D1–D3,
  S1, E1, E2), [ux-guidelines.md](ux-guidelines.md). Already settled there and not
  re-decided here: one `NavigationStack` and a sheet, portrait, one `.selection` haptic
  per grade, restrained motion through `DesignTokens.Motion`, terse Japanese copy.

## Brief

```text
Designing a 瞬間英作文 drill for one Japanese learner of spoken English on iOS (iPhone).
Goal: see the Japanese → say the English → reveal → grade ×/△/○ with one tap → next card.
Tone: quiet, focused, a little playful — figures lead, nothing celebrates.
Main objection/risk: a self-graded miss feeling like a penalty; a drill that looks generic.
Must remember: the owner's own "Lemon Arcade" role rules — each colour has one job, a
  miss is never red.
Constraints: system-first iOS (semantic colors, text styles, Dynamic Type, Liquid Glass
  from standard components); light, dark, Increase Contrast; 44 pt targets.
Research needed: screens and flows (iOS); the owner's existing lock as the style source.
Path: direct build from a reference-locked direction (three options shown, one chosen).
```

## Research

Refero styles cover web pages, not iOS app screens; the template's
`designing-ui/references/refero-workflow.md` makes them a secondary check at most. The
style source is the owner's own settled lock — "Lemon Arcade" in
`instant-composition/.agents/skills/designing-ui/SKILL.md`, itself built on Refero
styles (Duolingo `9457a848`, `fad6cd55`; Playdate `c91209ef`) — translated onto iOS
system components. iOS screens and flows supplied the product patterns. All Refero IDs
below came from tool calls on 2026-10-13.

| Reference | ID | Taken | Left |
|---|---|---|---|
| Oppie — flashcard study | screen `6a8574b6-be7c-4cc1-ab6a-e6dcb9798368` | One large rounded card as the whole screen; a single row of controls under it; colour held back | The black slab card (option B), freemium notices |
| LookUp — liked-words drill | screen `4cc37316-1091-42c9-a020-f3a6f0f61f80` | Three grade-like actions side by side directly under the card | A colour per action (pink, beige, green), progress bar |
| CapWords — card back | screen `632a033f-305e-46b1-bb44-319e20e5d65f` | Front and back as one card split by a hairline; the answer in large bold text; generous whitespace | Speckled texture, hold-to-speak |
| CapWords — "Got it!" prompt | screen `305b5703-9cdf-4836-b14a-9621a3c2db8d` | Grading as the one thing to do after the reveal | Stacked tilted cards, swipe gestures |
| CapWords — memory card practice | flow `6109` | Reveal → grade → next, one card at a time | Its score summary and celebration (quiet by default) |
| Vocabulary — "Make your own mix" | screen `aa450fd0-8959-4482-902f-643eee046bfd` | Grouped multi-select with a "By level" section, the check at the trailing edge, disabled rows greyed | Serif headings on a beige canvas, search |
| Kitchen Stories — dish type | screen `3a02e7ef-0684-4889-b0d1-8be32f31c18a` | A plain checklist sheet with checks | Orange checkbox chrome (iOS checkmarks instead) |
| Imprint — quiz complete | screen `c5918ce6-9ce4-4558-8380-2bd886a912b4` | The end state names when the next round comes ("NEXT QUIZ IN") | Streak card, notification toggle, Retry |

Options shown to the owner as phone mock-ups: **A** Lemon Arcade's role rules on iOS,
**B** ink-and-paper monochrome (Oppie's slab card), **C** stock iOS blue. **A** chosen.

## Reference lock

```text
Primary reference:  the owner's Lemon Arcade lock — its colour roles and values — set on
                    iOS system components instead of its web shapes.
Preserve:           each colour has one job; violet = the one primary action's fill;
                    teal = ○ only; ×, △ and anything "missed" are neutral grey, never red;
                    selection and focus are ink; figures lead, words label them.
Borrow only:        Oppie's single large rounded card with one control row under it;
                    CapWords' hairline split between the prompt and the answer.
Role rules:         Action (violet) fills 答えを見る, 範囲を変える…, 再試行 — one per screen,
                    never text, never a tint. Good (teal) fills the ○ button only.
                    AccentColor is ink: checkmarks, toolbar items, the count underline.
                    InkSecondary carries all secondary text. Energy (yellow) stays reserved
                    for a later streak or points and appears nowhere in this version.
Media strategy:     no illustration, no mascot, no photography. SF Symbols only; the app
                    icon is a code-generated "FC" monogram on the Action colour.
Reject:             Duolingo green; red or pink for ×; a colour per topic or level; a cream
                    canvas (system backgrounds instead); serif display type; the web lock's
                    lipped 3D buttons and confetti; glass on the bottom action bar;
                    celebration, score, or accuracy anywhere.
Token commitments:  system backgrounds; card = secondarySystemBackground, radius 20;
                    Action, Good, GoodEdge, OnGood, InkSecondary and an ink AccentColor
                    (values below); system font with SF Rounded for figures.
Memorable move:     the header's heavy rounded figures — 新規 1820 › 復習 12 › もう一度 0 —
                    with an ink underline under the pile the card came from; teal ○ is the
                    only hue inside the card loop.
```

## Lock fields

The template's `design-lock.md` fields, each a value or "system default".

- **Accent color:** ink, not a hue — `AccentColor.colorset` Any `#2B2924`, Dark
  `#F6F3EA`, increased contrast `#000000` / `#FFFFFF`. It tints checkmarks, toolbar
  items, links, and the count underline. Why: Lemon Arcade's "selection is ink"; a violet
  tint would put the primary-action colour on every checkmark.
- **Custom colors** (Color Sets in `App/Assets.xcassets`, each one role):

  | Name | Role | Any | Dark | Any, increased contrast | Dark, increased contrast |
  |---|---|---|---|---|---|
  | `Action` | Fill of the one primary action per screen (答えを見る, 範囲を変える…, 再試行); its text is white | `#6E00F5` | `#7B2BFF` | `#5A00C8` | `#6A1AF0` |
  | `Good` | Fill of the ○ button only | `#21C6A9` | `#2ED3B4` | `#21C6A9` | `#2ED3B4` |
  | `OnGood` | Text and glyph on `Good` | `#2B2924` | `#2B2924` | `#000000` | `#000000` |
  | `GoodEdge` | 1 pt stroke around the ○ button, so its edge holds 3:1 on white | `#12917B` | none (clear) | `#0E7A66` | none (clear) |
  | `InkSecondary` | All secondary text: the kind line, the small prompt on D2, alternatives, interval labels, notes | `#6B665A` | `#A9A6AF` | `#4A463D` | `#C9C6CF` |

  Everything else is semantic: `label` for primary text, `systemBackground` for the
  drill, `secondarySystemBackground` for the card, `tertiarySystemBackground` for the
  point box, `systemGray5` for the × and △ buttons, the grouped backgrounds in S1.
  System `secondaryLabel` is not used: it measures 3.44:1 on white (below the template's
  4.5:1), which is why `InkSecondary` exists.
- **Type:** system font (Japanese falls back to Hiragino Sans). Roles:

  | Element | Style |
  |---|---|
  | Header counts | `.subheadline`, figures `.semibold` with `.fontDesign(.rounded)` and `.monospacedDigit()` in `label`; the words 新規/復習/もう一度 regular in `InkSecondary` |
  | Kind line (復習 · 仕事 · L5) | `.footnote`, `InkSecondary` |
  | Prompt on D1 | `.title2` `.semibold`, centred |
  | Prompt on D2 | `.body`, `InkSecondary` |
  | Model answer | `.title3` `.semibold` |
  | 別解 label, alternatives | `.footnote` / `.body`, `InkSecondary` |
  | Point | `.callout` in `label`, with `lightbulb` |
  | Grade buttons | glyph `.title3`; label `.subheadline` `.semibold`; interval `.caption` rounded, monospaced digits, `InkSecondary` (`OnGood` on ○) |
  | Primary buttons | `.headline`, white on `Action` |
  | D3 / E1 title | `.title3` `.semibold` |

- **Spacing:** template scale, unchanged.
- **Corner radius:** template scale — the card `Radius.large` (20), the reveal, primary,
  and grade buttons and the point box `Radius.medium` (12); all `.continuous`.
- **Density:** regular. S1 is an `.insetGrouped` list. Bottom buttons are at least 50 pt
  tall (reveal) and 64 pt (grades) at the default text size, growing with it.
- **Symbols:** SF Symbols only. Monochrome in buttons and toolbars; hierarchical for the
  large D3 and E1 symbols. Glyphs: × `xmark`, △ `triangle`, ○ `circle`, re-ask
  `arrow.uturn.backward`, scope `line.3.horizontal.decrease.circle`, point `lightbulb`,
  D3 `checkmark.circle`, E1 `exclamationmark.triangle`.
- **Materials and Liquid Glass:** standard components only — the navigation bar, its
  toolbar item, and the sheet take glass on their own. The bottom action bar is solid
  fills (`Action`, `Good`, `systemGray5`) on the plain background, because its colours
  carry the roles. No custom glass.
- **Navigation structure:** one `NavigationStack` with no visible title; the scope as a
  sheet at the large detent; the per-card actions in a bottom `safeAreaInset`.
- **iPad layout:** iPhone only (`TARGETED_DEVICE_FAMILY: "1"`), portrait only.
- **Haptics:** `.sensoryFeedback(.selection, trigger:)` on every grade; nothing else
  (ux-guidelines).
- **Motion:** system transitions only through `DesignTokens.Motion` — a cross-fade
  between cards, the answer area fading in on reveal, the numeric-text transition on
  changed counts; none under Reduce Motion (ux-guidelines).
- **Copy style:** Japanese terse — noun endings (体言止め) or fragments, verbs on buttons,
  self-talk grade labels; the English source in sentence case; no exclamation marks
  (ux-guidelines).
- **App icon:** a placeholder generated in code, matching the display name FlashCompose
  — an "FC" monogram in SF Pro Rounded Black, white on `Action` `#6E00F5` (Any); the
  monogram in `#7B2BFF` on black (Dark); white on transparent (Tinted) — 1024 × 1024 in
  `AppIcon.appiconset`. Replaced when distribution is decided.

## Decision ledger

| Decision | Source | Rule / role | Why |
|---|---|---|---|
| Direction A over B and C | Owner's choice from three mock-ups | Lemon Arcade roles | Continuity with the owner's settled taste at the cost of two hues |
| Ink accent, violet only as a fill | Lemon Arcade: "violet = the one primary action, as a fill, never as text"; "selection is ink" | `AccentColor` ink, `Action` violet | A violet tint would leak the action colour onto every checkmark |
| Teal ○, grey × and △ | Lemon Arcade grade trio; ux-guidelines (a grade is not a success or a failure) | `Good` on ○ only | The positive grade is marked; a miss is not punished |
| `GoodEdge` 1 pt | Contrast pass: `Good` against white 2.16:1 | ○ boundary | Smallest change that keeps the bright teal and holds 3:1 (3.92) |
| `InkSecondary` instead of `secondaryLabel` | Contrast pass: `secondaryLabel` 3.44:1 on white; Lemon Arcade `ink-2` | All secondary text | The template's 4.5:1 text rule |
| One rounded card, controls under it | Oppie `6a8574b6`; CapWords `632a033f` | Card = `secondarySystemBackground`, radius 20 | The card is the drill; nothing competes with it |
| Three grades side by side under the card | LookUp `4cc37316`; ux-flows D2 | Grade row in the bottom inset | One thumb position for reveal and grade |
| Rounded heavy figures in the header | Lemon Arcade ("figures lead, words label them") | Counts `.semibold` rounded, words `InkSecondary` | The flow of the three piles reads at a glance |
| Grouped checklist for the scope | Vocabulary `aa450fd0`; Kitchen Stories `3a02e7ef` | S1 `.insetGrouped`, ink checkmarks | Multi-select with the last row disabled, as ux-flows S1 says |
| D3 names the next review day | Imprint `c5918ce6` | D3 copy | The end state says when the drill resumes, without a score |
| No glass on the bottom bar | designing-ui (glass for floating chrome); the roles above | Solid fills | Glass would wash out the colour roles |
| System backgrounds, no cream canvas | Template system-first rule; refero craft rule (cream canvas as an AI default) | `systemBackground` | iOS appearance and Increase Contrast come for free |

## Measured contrast

Pairs file: [contrast-pairs.json](contrast-pairs.json). Command: `python3
~/.claude/skills/ui-ux-designing/scripts/check_contrast.py contrast-pairs.json` — exit 0
on 2026-10-13. The first pass failed two pairs (system `secondaryLabel` 3.44:1 on white;
`Good` against white 2.16:1); the direction changed (`InkSecondary`, `GoodEdge`) rather
than the measurement. System backgrounds are measured at their standard values;
increased-contrast rows check this app's own colours.

```text
name                                                                           fg       bg       kind   ratio  required  result
-----------------------------------------------------------------------------  -------  -------  -----  -----  --------  ------
light text: label on background                                                #000000  #FFFFFF  text   21.00  4.50      PASS  
light text: label on card                                                      #000000  #F2F2F7  text   18.82  4.50      PASS  
light text: InkSecondary on background / point box                             #6B665A  #FFFFFF  text   5.72   4.50      PASS  
light text: InkSecondary on card                                               #6B665A  #F2F2F7  text   5.12   4.50      PASS  
light text: InkSecondary interval on grade gray                                #6B665A  #E5E5EA  text   4.55   4.50      PASS  
light text: label on grade gray                                                #000000  #E5E5EA  text   16.73  4.50      PASS  
light text: white on Action                                                    #FFFFFF  #6E00F5  text   7.04   4.50      PASS  
light text: OnGood on Good                                                     #2B2924  #21C6A9  text   6.72   4.50      PASS  
light ui: AccentColor ink (checkmark, toolbar, count underline) on background  #2B2924  #FFFFFF  ui     14.53  3.00      PASS  
light ui: AccentColor ink on grouped background                                #2B2924  #F2F2F7  ui     13.02  3.00      PASS  
light ui: Action fill against background                                       #6E00F5  #FFFFFF  ui     7.04   3.00      PASS  
light ui: GoodEdge (1 pt) against background                                   #12917B  #FFFFFF  ui     3.92   3.00      PASS  
dark text: label on background                                                 #FFFFFF  #000000  text   21.00  4.50      PASS  
dark text: label on card                                                       #FFFFFF  #1C1C1E  text   17.01  4.50      PASS  
dark text: InkSecondary on background                                          #A9A6AF  #000000  text   8.76   4.50      PASS  
dark text: InkSecondary on card                                                #A9A6AF  #1C1C1E  text   7.10   4.50      PASS  
dark text: InkSecondary on point box                                           #A9A6AF  #2C2C2E  text   5.81   4.50      PASS  
dark text: InkSecondary interval on grade gray                                 #A9A6AF  #2C2C2E  text   5.81   4.50      PASS  
dark text: label on grade gray                                                 #FFFFFF  #2C2C2E  text   13.94  4.50      PASS  
dark text: white on Action                                                     #FFFFFF  #7B2BFF  text   5.78   4.50      PASS  
dark text: OnGood on Good                                                      #2B2924  #2ED3B4  text   7.67   4.50      PASS  
dark ui: AccentColor ink on background                                         #F6F3EA  #000000  ui     18.93  3.00      PASS  
dark ui: AccentColor ink on sheet row                                          #F6F3EA  #1C1C1E  ui     15.34  3.00      PASS  
dark ui: Action fill against background                                        #7B2BFF  #000000  ui     3.63   3.00      PASS  
dark ui: Good fill against background                                          #2ED3B4  #000000  ui     11.09  3.00      PASS  
IC light text: InkSecondary on background                                      #4A463D  #FFFFFF  text   9.40   4.50      PASS  
IC light text: InkSecondary on card                                            #4A463D  #F2F2F7  text   8.42   4.50      PASS  
IC light text: InkSecondary interval on grade gray                             #4A463D  #E5E5EA  text   7.49   4.50      PASS  
IC light text: white on Action                                                 #FFFFFF  #5A00C8  text   9.26   4.50      PASS  
IC light text: OnGood on Good                                                  #000000  #21C6A9  text   9.72   4.50      PASS  
IC light ui: AccentColor ink on background                                     #000000  #FFFFFF  ui     21.00  3.00      PASS  
IC light ui: GoodEdge against background                                       #0E7A66  #FFFFFF  ui     5.26   3.00      PASS  
IC dark text: InkSecondary on background                                       #C9C6CF  #000000  text   12.46  4.50      PASS  
IC dark text: InkSecondary on card                                             #C9C6CF  #1C1C1E  text   10.10  4.50      PASS  
IC dark text: InkSecondary interval on grade gray                              #C9C6CF  #2C2C2E  text   8.27   4.50      PASS  
IC dark large text: white on Action (17 pt semibold)                           #FFFFFF  #6A1AF0  large  6.96   3.00      PASS  
IC dark text: OnGood on Good                                                   #000000  #2ED3B4  text   11.09  4.50      PASS  
IC dark ui: AccentColor ink on background                                      #FFFFFF  #000000  ui     21.00  3.00      PASS  
IC dark ui: Action fill against background                                     #6A1AF0  #000000  ui     3.02   3.00      PASS  
```

## Open

- Open: the screenshots `designing-ui`'s review pass asks for (light, dark, the largest
  text size, Increase Contrast) — they exist only once the screens are built (the issues
  that build them); the system backgrounds' own increased-contrast values are checked there.
