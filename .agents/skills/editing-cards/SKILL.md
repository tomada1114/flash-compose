---
name: editing-cards
description: >
  Covers editing the bundled card catalog under
  Packages/FlashComposeKit/Sources/FlashComposeCore/Resources/Catalog/ - fixing,
  rewording, retagging, adding, retiring, or deleting a card in
  cards/<topic>/<subtopic>.json or retired-ids.json. Use when deciding whether a card
  edit keeps its id or needs a new one, minting a card id (c_ plus four digit-letter
  pairs), retiring an id with replacedBy, or when the catalog integrity suites or a
  CatalogError readFailed or decodeFailed fail after a card file changed.
---

# Editing Cards

**Owns:** how a card in the bundled catalog is changed without breaking the progress
stored under its id - the keep-versus-mint decision, minting an id, retiring and
deleting, adding a card, and the checks that finish the edit. **Does not own:** the
catalog's design and file layout (`docs/architecture.md`'s "Card catalog" and "Card
identity"); the decoder and the integrity rules themselves (code under
`Sources/FlashComposeCore/Catalog/` and `Tests/FlashComposeCoreTests/Catalog/`, changed
with `tdd`); the error design that keeps `CatalogError` payload-free (`designing-errors`).

Paths below are relative to `Packages/FlashComposeKit/`; the catalog is
`Sources/FlashComposeCore/Resources/Catalog/`, called `Catalog/` here.

## The files

- `Catalog/cards/<topic>/<subtopic>.json` - a top-level JSON array of cards, one file
  per subtopic `Catalog/taxonomy.json` names, kept sorted by `id`. A card's keys are
  `id`, `ja`, `en`, `alternatives` (at least one), `point`, `topic`, `subtopic`,
  `level` (one `Catalog/levels.json` defines), and `grammar` (ids from
  `Catalog/grammar.json`). `CardRecord` (`Sources/FlashComposeCore/Catalog/CardRecord.swift`)
  decodes `ja` / `en` into `Card.japanese` / `Card.english`.
- `Catalog/retired-ids.json` - a top-level JSON array, one `{"id": ..., "replacedBy": ...}`
  object per line (`replacedBy` optional). New retirements are appended at the end.
- The gate: `CatalogIntegrity` (`Tests/FlashComposeCoreTests/Catalog/CatalogIntegrity.swift`)
  and `CatalogIntegrityTests` - duplicate ids, a retired id still on a card, empty text,
  no alternative, an unknown topic, subtopic, level, or grammar tag, each reported by
  card id only. `CatalogLoader` rejects an id outside the format at decode time.

## The identity question

A card id is contract: the learner's progress and answers are stored under it. Ask:
could the answers recorded before the change still be compared, as answers to the same
question, with those recorded after it?

- **Yes - edit in place, keep the id:** a typo or outright error; a more natural `ja`
  with the same meaning; a word swap in `en` that keeps its skeleton; adding, removing,
  or replacing alternatives; rewriting `point`; retagging `topic`, `subtopic`, `level`,
  or `grammar`.
- **No - mint a new id and retire the old one with `replacedBy`:** the meaning of `ja`
  changes; the skeleton of `en` changes (tense, pattern, main clause); the main grammar
  item changes; or `en` grows to about 1.5 times its words or shrinks to about two
  thirds.

Near a threshold (an `en` that grows 1.4 times, a skeleton that half changes), ask the
identity question again; when still unsure, mint a new id - a needless new id only
restarts one card, a wrongly kept one mixes incomparable answers. Where the rule does
not decide at all (a change the lists above do not describe), ask the owner rather than
choosing.

Retagging only keeps the id. When `topic` or `subtopic` changes, move the card object
into the file for its new subtopic, keeping that file sorted by `id`.

## Minting an id

Format: `c_` and four digit-letter pairs, `^c_(?:[2-9][a-hjkmnp-z]){4}$` - digits from
`23456789`, letters from `abcdefghjkmnpqrstuvwxyz`. A new id must not be on any card and
must not be in `retired-ids.json`; an id is never reused. There is no minting script;
run this from `Packages/FlashComposeKit/` and it prints an unused, unretired id:

```bash
python3 -c '
import glob, json, random
root = "Sources/FlashComposeCore/Resources/Catalog/"
used = {c["id"] for f in glob.glob(root + "cards/*/*.json") for c in json.load(open(f))}
used |= {r["id"] for r in json.load(open(root + "retired-ids.json"))}
while True:
    new = "c_" + "".join(random.choice("23456789") + random.choice("abcdefghjkmnpqrstuvwxyz") for _ in range(4))
    if new not in used:
        print(new); break
'
```

If an id you minted some other way turns out to exist or be retired, mint another;
`just test` reports a collision as `duplicateID` or `retiredID` on that id.

## Worked examples

The ids below are format examples; mint real ones with the snippet above.

**Fix a typo - keep the id.** Card `c_7k2m9x4q`'s `en` misspells "receive" (the issue's
example swaps its `e` and `i`); correct it in place. Nothing else moves.

**Change the meaning - new id, retire the old.** Card `c_3b6d8g2h`'s `ja` changes from
「昨日は雨だった」 to 「明日は雨が降るだろう」 (past to future: meaning and skeleton both
change). Mint `c_5f9h3k7m`, give the rewritten card that id in the same subtopic file
(re-sorted by `id`), and append to `retired-ids.json`:

```json
  {"id": "c_3b6d8g2h", "replacedBy": "c_5f9h3k7m"}
```

The old id's progress is kept on the device but no longer read; the new card starts as
new.

**Delete a card - retire without `replacedBy`.** Remove card `c_4m7n2p5q` from its file
under `cards/travel/`, and append `{"id": "c_4m7n2p5q"}` to `retired-ids.json`. The id
is never reused.

**Add a card.** Mint an id, add the full card object to
`cards/<topic>/<subtopic>.json` for a subtopic `taxonomy.json` already lists, with
`topic` and `subtopic` matching that path, and keep the file sorted by `id`. A new
subtopic or topic is a `taxonomy.json` change plus a new file, not a card edit.

When appending to `retired-ids.json`, keep the comma rules of a JSON array: the
previous last line gains a trailing comma, the new last line has none.

## The counts test moves with the catalog

`CatalogIntegrityTests`' "the catalog holds the counts copied from instant-composition"
pins the number of cards, retired ids, and retired ids with `replacedBy`. An edit that
adds, deletes, or replaces a card changes those numbers on purpose, so update the
expected counts in the same commit and say why in the commit message. Changing a count
is not loosening the gate; deleting the expectation would be.

## Finishing the edit

```bash
just test   # the catalog integrity suites, among the rest of Core's tests
just lint   # typos spell-checks the card files' English
```

Both must pass.

## When a card file will not load

`CatalogError` is `.readFailed` or `.decodeFailed` with no payload, on purpose
(`designing-errors`), so a malformed file fails the catalog suites without naming
itself. Find it:

1. Check that every file is valid JSON - the first one printed is the broken one:

   ```bash
   cd Sources/FlashComposeCore/Resources/Catalog
   for f in *.json cards/*/*.json; do python3 -m json.tool "$f" >/dev/null || echo "$f"; done
   ```

2. Valid JSON that still fails to decode has a missing key, a wrong type, a level
   outside 1-10, or an id outside the format. Check ids in the files you touched:

   ```bash
   grep -rhoE '"id": *"[^"]*"' cards | grep -vE '"c_([2-9][a-hjkmnp-z]){4}"'
   ```

3. A file that decodes but breaks a rule is reported by the integrity suite as
   `<card id>: <rule>` - search for that id in `cards/`.
