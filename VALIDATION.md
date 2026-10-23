# Validation (2026-10-23)

Toolchain: moon `0.1.20261016`; moonc `v0.10.16+b1a0e846e`.
This records technical behavior, not contest approval or postal deliverability.

Local format/interface/check/build checks passed. MoonBit: **43/43 on each of wasm, wasm-gc, js, native**. Python: **9/9** offline adapter tests. GitHub CI must be checked separately against the pushed SHA; it runs the same four-target checks, examples, Python tests, and generated-interface drift check.

```sh
moon update
moon fmt --check
moon info
moon check --deny-warn --target all
moon build --target all
moon test --deny-warn --target all
moon run examples/quickstart --target native
moon run examples/decision --target native
moon run examples/directory --target native
moon run examples/workflow --target native
python -m unittest discover -s scripts
python scripts/import_japan_post.py --verify
moon run examples/national --target native -- _build/data/jp.tsv --all
```

The last two commands use the saved local snapshot. To acquire a new snapshot, first run `python scripts/import_japan_post.py`, or reconstruct offline with `--archive path/to/saved.zip`. Data acquisition is separate from ordinary CI and requires upstream access only when downloading.

## Behavior covered

Directory tests cover unique completion, exact labels, one-code/multiple-town and one-town/multiple-code relationships, cross-region city collisions, hierarchy conflicts, reverse lookup, unknown keys, insufficient input, wrong country, malformed codes/controls, fallback/conditional towns, missing street detail, deduplication, index isolation, strict TSV, and label rules omitting town.

Snapshot/batch tests cover both lookup directions after replacement, old-snapshot preservation, stale/same/invalid revisions, patch limits, duplicate/missing/existing operations, invalid/empty replacements, coverage transitions, audit narrowing/completed fields, every decision-status counter, stable batch IDs/order, whole-batch export withholding, ID/capacity failures, empty batches, TSV roundtrip, and US ZIP+4 canonical display.

Adapter tests cover BOM/quoted CSV/leading zeros, duplicate rows, uncertainty flags, malformed columns/codes/flags, retired rows, control characters, empty input, installation/verification, tamper detection, invalid-input preservation, replacement failure cleanup, and mixed-bundle detection after partial publication. The three output files are not a multi-file transaction.

## Observed workflow output

```text
v1 batch: 1 resolved, 1 conflict; export withheld
Candidate step: 1 -> 1
Candidate step: 1 -> 0
v2 update: 1 addition, 1 removal
Stale update rejected
Old code: resolved in v1, unknown in v2
Reverse lookup after update: 2234567
```

## National-data integration

The 2026-10-21 acquired snapshot was reverified offline on 2026-10-23 against the ZIP/TSV SHA-256 values in `SOURCES.md`. It has 124,525 unique records, 120,720 postal codes, and 47 prefectures. Exhaustive mode reported:

```text
Directory records: 124525
Conflicting city rejected
Reverse lookup: 1000001
National forward/reverse probes passed: 124525
```

The example also prints its accepted Chiyoda label. With `--all`, each unique row is checked for inclusion in both forward and reverse query results; default mode samples every 251st row (497 probes on this snapshot). Inclusion checks establish relation preservation, not independent data correctness or deliverability. The archived source is not claimed to be the latest upstream release. Dataset files are ignored and not shipped with the library.
