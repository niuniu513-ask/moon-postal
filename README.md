# MoonPostal

MoonPostal is an offline MoonBit library for postal-directory lookup, structured address resolution, cross-field validation, and checked label output.

It retains syntax/layout rules for US, CA, GB, JP, CN, AU, and AE. The directory engine adds exact postal-to-region/city/town relationships, reverse lookup, candidate intersection, safe field completion, and explicit ambiguity/conflict decisions. A reproducible Japan Post national-data adapter exercises the engine on real town-routing data. Seven-country syntax support does **not** mean seven-country directory coverage.

## Directory resolution

The 0.3.0 source introduces `PostalDirectory`. Build it from typed `PostalEntry` records or strict TSV. Indexes use country + postal code and country + city; repeated records are deduplicated while one-to-many and many-to-many relationships remain intact. A supplied region, city, or town narrows the candidate set. Conflicting fields are reported; they are never overwritten. Only a unique exact town can fill omitted fields and proceed through the existing validation/label gates.

```moonbit
let directory = @moon-postal.PostalDirectory::new([
  @moon-postal.PostalEntry::new("JP", "1000001", "東京都", "千代田区", "千代田"),
], source="Japan Post: one illustrative town-routing record").unwrap()
let result = directory.resolve(
  @moon-postal.builtin_rule("JP").unwrap(),
  @moon-postal.Address::new(
    country_code="JP", postal_code="100-0001", address_lines=["1-1"],
  ),
)
let canonical = result.canonical() // Some(address) only after all gates pass
let label = result.label_lines()
let alternatives = directory.lookup_locality("JP", "千代田区", town="千代田")
```

| Status | Meaning | Label |
| --- | --- | --- |
| `Resolved` | Unique exact directory row and valid completed address | Yes |
| `Ambiguous` | Multiple exact rows remain | No |
| `Conflict` | A supplied hierarchy field contradicts candidates; see `conflict_field()` | No |
| `UnknownPostal` / `UnknownLocality` | Lookup key is absent in this snapshot | No |
| `UnverifiedTown` | A fallback or conditional row remains; town cannot be established safely | No |
| `InvalidInput` | Country, syntax, control character, or final validation failure | No |
| `InsufficientInput` | Missing country, or both postal code and city are absent | No |

`candidates()` returns the surviving alternatives (or alternatives before the conflicting field). `issues()` exposes final validation errors. A fallback row such as “以下に掲載がない場合” is a routing note, never an automatically filled town. Conditional ranges and building/floor notes also require manual review. `UnverifiedTown` takes priority over `Ambiguous` when any uncertain row survives. This is structured-field resolution, not free-text address parsing or fuzzy correction.

The `JP` rule renders the town field. Custom directory label rules must include `DependentLocality` in `field_order`; otherwise resolution refuses to silently omit the resolved town. Legacy `assess` keeps its original semantics and does not consult a directory automatically.

### Three complete workflows

1. **Checkout:** submit country, postal code, and street detail. A unique routing row fills region/city/town and yields a label. A mismatching city is rejected instead of silently replaced.
2. **Address entry:** submit a city with optional region/town to `lookup_locality`. Show all postal alternatives; when several codes serve the same town, require a choice rather than selecting the first code.
3. **Batch data cleanup:** load one versioned TSV snapshot, reuse its indexes across records, and separate accepted addresses, hierarchy conflicts, unknown codes, ambiguous records, and conditional/fallback towns. Only accepted records receive canonical addresses and label lines.

### National Japan Post example

From this repository checkout, with Python 3.10+ and a current MoonBit toolchain:

```sh
python scripts/import_japan_post.py
moon run examples/national --target native
```

The adapter downloads the [Japan Post UTF-8 town dataset](https://www.post.japanpost.jp/service/search/zipcode/download/utf/zip/utf_ken_all.zip), preserves seven-digit codes as text, interprets uncertainty flags, and writes `_build/data/jp.tsv`, the raw ZIP, and a JSON provenance/hash report. Subsequent use is offline. Rebuild from a saved ZIP with:

```sh
python scripts/import_japan_post.py --archive _build/data/jp.zip
moon run examples/national --target native -- _build/data/jp.tsv
```

The 2026-10-21 run loaded **124,525** unique rows and **120,720** postal codes across **47** prefectures, then passed 497 sampled forward/reverse lookup checks. Data counts change with upstream updates. The complete snapshot stays outside Git and the distributed library; applications acquire and version it separately. Python handles acquisition/conversion only; indexing, lookup, relationship decisions, canonicalization, and label gates are MoonBit code. `moonbitlang/x/fs` is used only by the native file-loading example; the library itself does not perform I/O.

The national table covers town routing, excludes dedicated large-business postal codes, and cannot establish building existence or deliverability. Unknown means “not in this snapshot”, not “does not exist”. See [SOURCES.md](SOURCES.md) for provenance and [VALIDATION.md](VALIDATION.md) for reproducible checks.

## Use

```moonbit
let rule = @moon-postal.builtin_rule("US").unwrap()
let address = @moon-postal.Address::new(
  recipient="Ada Lovelace",
  address_lines=["12 Example Street"],
  locality="Boston",
  administrative_area="MA",
  postal_code="02108",
  country_code="US",
)
let issues = @moon-postal.validate(rule, address)
let label = @moon-postal.format_if_valid(rule, address)
```

`AddressRule::new` lets callers supply required fields, a postal-code pattern, and field order. `PostalPattern` supports exact or ranged digit counts, ranged ASCII alphanumeric codes, and a no-check option. Generic patterns reject internal separators; built-ins provide country-specific checks. `validate` reports missing configured fields, a country mismatch, and a postal-code syntax mismatch. Each issue has a `message()` for display. Built-in US, CA, and AU rules combine locality, region, and postal code on one line. Custom rules preserve their specified field order and separate lines.

## Rule relationships and label decisions

Callers with trusted regional data can attach administrative-area/postal-prefix relationships to an address rule. Multiple prefixes may belong to the same area. Attaching a nonempty table makes country, administrative area, and postal code required. This table is deliberately partial: when a configured table has no entry for the input area, the result is `UnknownArea`, not a successful match. An invalid postal-code shape, missing field, or wrong country is reported before a relationship decision. A rule whose required field is absent from its label order is also rejected, so a printable label cannot silently drop it.

```moonbit
let rule = @moon-postal.builtin_rule("US").unwrap().with_area_postal_prefixes([
  @moon-postal.AreaPostalPrefix::new("MA", "021"),
  @moon-postal.AreaPostalPrefix::new("MA", "022"),
  @moon-postal.AreaPostalPrefix::new("NY", "100"),
])
let decision = @moon-postal.assess(rule, address)
let issues = decision.issues()
let printable_lines = decision.label_lines()
let relationship = decision.relationship_status()
```

`assess` returns label lines only when all configured checks pass. `relationship_status()` distinguishes `Matched`, `Mismatched`, `UnknownArea`, `Skipped`, and `NotConfigured`. The built-in seven-country rules contain no comprehensive area/postal relationship data: `NotConfigured` means a syntactically valid label can be produced without asserting a regional match. For a workflow that requires a known regional match, attach a reviewed relationship table and accept the label only when the status is `Matched`.

The runnable decision example uses three illustrative prefixes; they are examples of a deliberately incomplete table, not a national postal dataset:

```sh
moon run examples/decision --target native
```

It prints a label for a matching Boston example, an area/postal conflict for a second Boston example, and an uncovered-area issue for a Chicago example. Both rejected inputs produce no label lines. `format_address_lines` and `format_address` are raw formatting APIs; `format_if_valid` and `assess` enforce the configured validation gates.

## Scope

This is a deterministic rules library. It has no network access or dependency on an operating-system locale. Country-specific behavior is explicit in `AddressRule`; unknown countries return `None` from `builtin_rule`.

The initial postal-code checks are syntactic and intentionally bounded. They do not encode every postal exception, subdivision, language-specific label, script convention, or recent postal authority update. The UK syntax check is a conservative shape check rather than a complete Royal Mail validator. Do not treat validation as proof that an address is deliverable.

The generic directory model accepts reviewed, attributed regional data through typed entries or TSV. The included acquisition adapter is specific to Japan Post; other countries still require separate reviewed datasets. This project does not claim complete worldwide coverage.

## Run

Install as `niuniu513-ask/moon-postal`.

```sh
moon check --target all
moon test --target all
moon run examples/quickstart --target native
moon run examples/decision --target native
moon run examples/directory --target native
python -m unittest discover -s scripts
```

## Relationship to related projects

- `niuniu513-ask/moon-vcard` parses and writes contact-card text. MoonPostal accepts structured address fields and applies postal rules; it does not parse vCard.
- `bobzhang/contacts` is an address-book application. It stores and searches contacts rather than providing a reusable regional postal-rule engine.
- `zxwrrg/moonbit-tradedocs` normalizes party address fields as part of trade-document processing. MoonPostal focuses on configurable postal validation and address-line ordering.
- Google's `libaddressinput` is the mature reference for the address-rule domain. MoonPostal is an independent MoonBit implementation; it does not claim upstream compatibility or endorsement.
- Japan Post supplies the national town-routing data. The adapter converts that data for MoonPostal; no upstream search software is embedded.

These boundaries describe the inspected project summaries and APIs, not a guarantee that no overlapping implementation exists. See `SOURCES.md` for checked sources and licensing notes.
