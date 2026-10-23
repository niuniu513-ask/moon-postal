# Declared scope and mechanisms (2026-10-23)

The 0.4.0 source scope is an offline structured postal-routing directory engine with versioned batch processing. Country syntax, field formatting, prefix tables, and label checks remain compatibility facilities; they are not the main engineering claim. This document describes implemented behavior, not contest acceptance.

## Input, processing, and output

1. **Checkout resolution:** structured country/postal/street fields + a rule + a snapshot -> country-scoped postal bucket -> region/city/town intersections -> exactness and final-validation gates -> canonical fields and label, or an explicit conflict/unknown/ambiguous/uncertain decision. Supplied conflicting fields are never silently overwritten.
2. **Batch cleanup:** jobs with stable unique IDs + one snapshot/rule/export policy -> up-front capacity/ID validation -> per-row decisions and candidate-count traces -> ordered rows, status totals, and policy-controlled labels. A conflicting row can prevent the entire batch's export without hiding diagnostic decisions.
3. **Directory maintenance:** old snapshot + expected revision + additions/removals -> operation validation -> new relation set and both rebuilt indexes -> a new snapshot. Consumers can compare versions and keep using the old snapshot. A stale revision or invalid patch returns an error without changing old data.

Run `moon run examples/workflow --target native` for a complete batch and update chain. `snapshot_test.mbt` tests its failures and invariants; `directory_test.mbt` covers relation resolution itself.

## Mechanisms and costs

| Mechanism | Implementation | Cost and invariant |
| --- | --- | --- |
| Two relation indexes | `directory.mbt`: country+postal and country+city buckets | Expected O(n) construction/storage; lookup/filter visits its bucket of b rows, O(b) plus returned output. Keeps multiple towns/codes rather than taking the first match. String/key lengths also contribute to cost. |
| Coverage-aware decisions | exact, unspecified, conditional entries | A remaining uncertain row prevents automatic town completion, even if another candidate is exact. Unknown keys describe this snapshot only. |
| Canonical completion | unique exact candidate plus configured rule validation | Fill only missing fields, reject conflicts and omitted town in label order; US ZIP+4 keys regain the display hyphen before validation/output. |
| Audit | `audit.mbt`: snapshot revision/source, seed/filter counts, completed fields | Replays bucket filtering after resolution, O(b), without recipient/street text in counts. The decision still contains normal address data; this is not an anonymized log or cryptographic proof. |
| Batch policy | ID map, ordered decisions and status counts | O(j) ID validation plus j resolutions; default maximum 10,000 jobs. `RequireAllResolved` withholds the label accessor if any row fails. Raw row decisions remain inspectable. |
| Stable version difference | `snapshot.mbt`: identity set comparison | Expected O(n+m), ignoring string lengths; relation identity includes coverage, so exact-to-conditional appears as remove+add. Results follow source order. |
| Validated snapshot replacement | revision/operation checks then full index rebuild | Expected O(n+k), ignoring string lengths; patch limit defaults to 100,000 operations. All data and replacement indexes must fit memory. No in-place database transaction or concurrent-writer locking. |
| Reproducible acquisition | standard-library Python CSV/ZIP conversion, staged files, SHA-256 manifest | Reject malformed/empty input before writing; each file replace is atomic, the bundle is not. Offline verification detects mixed/tampered bundles; signatures/authenticated update feeds are absent. |

Snapshot revisions are nonempty caller labels, not ordered timestamps or authority claims. Same-revision updates are rejected. The expected revision must equal the current snapshot's label. A patch cannot add an already-present identity even if it also removes it; use only actual relation changes. Empty final directories are rejected. Entries and change arrays exposed by accessors cannot mutate snapshot indexes.

The native national example accepts a TSV file; it does not automatically verify its sibling manifest. Run `python scripts/import_japan_post.py --verify` first when using an acquired bundle. Hash verification is a separate acquisition check, not a security gate inside the MoonBit library.

## Evidence and differences from the earlier scope

The earlier rule-only scope checked field presence, postal shapes, optional prefix relations, and label ordering. The current engine additionally owns many-to-many routing data, ambiguity and conditional coverage, forward/reverse indexes, deterministic completion, whole-batch export decisions, provenance-bearing traces, version comparison, and validated replacement. These responsibilities are exercised by executable examples and error-path tests, not inferred from the number of countries or functions.

The saved Japan Post national snapshot contains 124,525 unique relations, 120,720 codes, and 47 prefectures. Every row passed forward and reverse inclusion probes on 2026-10-23. This validates preservation of supplied relations; it does not independently verify Japan Post's data or real-world addresses. See `VALIDATION.md` and `SOURCES.md` for reproducible evidence and hashes.

## Related work and limits

The 2026-10-23 review identified `vicoproplus/moon_cpca` in registry metadata (repository `vicoplus/moon_cpca`), which extracts Chinese administrative divisions, and `JIA2JIA2/moonbitgeodb` (repository `JIA2JIA2/moonbitGEODB`), whose README describes parsing, matching, GIS indexes, and storage. General address handling, indexing, and integrity mechanisms overlap. MoonPostal does not claim to invent these techniques or to be the only MoonBit address project. Its narrower postal-routing and directory-lifecycle contract is documented above. Neither project is imported or copied; this review inspected public descriptions, not every source path.

Only Japan has an included national-data acquisition adapter; seven built-in syntax rules do not mean seven national directories. No free-text parsing, fuzzy correction, full Unicode equivalence, geocoding, building existence, delivery guarantee, persistent database, signed updates, or official acceptance is implemented. Code is MIT; upstream data retains its separate terms. The full dataset and private contest materials are excluded from Git.
