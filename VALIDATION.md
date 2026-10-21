# Directory validation (2026-10-21)

Toolchain: moon `0.1.20261016`; moonc `v0.10.16+b1a0e846e`.
This records technical behavior, not contest approval or postal deliverability.

Local result: format/interface checks, check/build, all examples, and all tests
passed. MoonBit: 31 tests on each of wasm, wasm-gc, js, and native. Python: 4
adapter tests. GitHub CI must be checked separately against the pushed commit.

```sh
moon fmt --check
moon info
moon check --deny-warn --target all
moon build --target all
moon test --deny-warn --target all
moon run examples/quickstart --target native
moon run examples/decision --target native
moon run examples/directory --target native
python -m unittest discover -s scripts
python scripts/import_japan_post.py
moon run examples/national --target native
```

The directory regression tests cover unique completion, exact label output,
same-code multiple towns, same-town multiple codes, same city across regions,
region/city/town conflicts, reverse lookup, unknown keys, insufficient fields,
wrong country, malformed postal codes, control characters, fallback/conditional
towns, missing street detail, duplicate records, index isolation, malformed TSV,
and refusing label rules that omit the resolved town.

The data adapter tests cover UTF-8 BOM, quoted CSV, leading zeros, duplicate rows,
uncertainty flags, multiple towns sharing a code, invalid columns/codes/flags,
retired records, and embedded control characters. They run without network access
in CI. National-data acquisition is an explicit integration check and is not a
network dependency for the ordinary unit-test workflow.

Observed national-data integration output:

```text
Directory records: 124525
1000001
東京都
千代田区
千代田
1-1
JP
Conflicting city rejected
Reverse lookup: 1000001
National forward/reverse probes passed: 497
```

The 497 probes sample every 251st data row across the complete ordered snapshot.
Each checks that forward and reverse queries preserve that row's routing relation.
They supplement behavioral tests; they do not certify every postal address.
Snapshot counts, source URLs, hashes, and scope are recorded in `SOURCES.md`.
