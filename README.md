# MoonPostal

MoonPostal is an offline MoonBit library for validating structured postal addresses against country rules and formatting their fields in a configured order.

The current release provides built-in rules for the United States, Canada, the United Kingdom, Japan, China, Australia, and the United Arab Emirates. Other regions can be added as `AddressRule` values. The initial built-in set is not a global postal directory.

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

The rule model is intended to grow through reviewed, attributed regional data. Until then, callers can construct and pass their own rules. This release does not claim complete worldwide coverage.

## Run

Install as `niuniu513-ask/moon-postal`.

```sh
moon check --target all
moon test --target all
moon run examples/quickstart --target native
moon run examples/decision --target native
```

## Relationship to related projects

- `niuniu513-ask/moon-vcard` parses and writes contact-card text. MoonPostal accepts structured address fields and applies postal rules; it does not parse vCard.
- `bobzhang/contacts` is an address-book application. It stores and searches contacts rather than providing a reusable regional postal-rule engine.
- `zxwrrg/moonbit-tradedocs` normalizes party address fields as part of trade-document processing. MoonPostal focuses on configurable postal validation and address-line ordering.
- Google's `libaddressinput` is the mature reference for the address-rule domain. MoonPostal is an independent MoonBit implementation; it does not claim upstream compatibility or endorsement.

These boundaries describe the inspected project summaries and APIs, not a guarantee that no overlapping implementation exists. See `SOURCES.md` for checked sources and licensing notes.
