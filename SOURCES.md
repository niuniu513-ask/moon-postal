# Sources and overlap review

Checked 2026-10-16. This is a finite review, not a claim of global uniqueness or organizer approval.

2026-10-20 implementation note: The relationship API accepts caller-provided area/postal-prefix entries. The decision example uses a small illustrative US table (MA 021/022 and NY 100) to demonstrate match, conflict, and uncovered-area handling. It is not a complete or authoritative postal dataset and is not copied from `libaddressinput`. Applications should supply and maintain their own appropriately licensed regional relationship data.

The Mooncakes module and GitHub repository both use the `niuniu513-ask` namespace. The module manifest points at that GitHub repository.

| Source | Inspected scope | Relationship |
| --- | --- | --- |
| Google `libaddressinput` ([repository](https://github.com/google/libaddressinput)) | Public project description, address validator API, C++ region metadata source tree | Mature domain reference. Code repository declares Apache-2.0; metadata/data can carry separate terms, so any copied rule data needs its own attribution and license review. No source code or region dataset is copied into this initial implementation. |
| `niuniu513-ask/moon-vcard` (local project) | README and parser API | Parses/writes a subset of vCard fields. It does not validate country-specific postal fields or format postal labels. |
| `bobzhang/contacts` ([repository](https://github.com/moonbit-community/isomorphic/tree/main/contacts)) | README and project tree | Address-book application with contact management, search, and phone display formatting. Not a reusable postal-rule package. |
| `niuniu513-ask/moon-einvoice` (local project) | Existing project name and scope | Invoice workflow; no postal address rule engine was found during the local project inventory. |
| `zxwrrg/tradedocs` ([repository](https://github.com/zxwrrg/moonbit-tradedocs)) | README and `lib/normalizer/party_normalizer.mbt` | Normalizes trade-party address text and country codes inside trade documents; no country postal-pattern validator or postal address formatter was found in inspected paths. |
| Mooncakes registry snapshot | 3,040 module metadata records; queries for postal/address/vCard/contact terms | Found `angela/vcf`, `haol-05/moon-vcard`, `bobzhang/contacts`, and `zxwrrg/tradedocs`; their listed summaries do not describe this project's complete rule-validation purpose. Metadata search cannot rule out functionality hidden in unrelated package names. |
| GitHub search | Repository searches for `libaddressinput`, `postal`, `moonaddress`, address validation, and MoonBit; code searches for postal terms | No direct repository match for a MoonBit libaddressinput port appeared in these queries. Search coverage is finite and code search results are incomplete. |

## Current project boundary

- Input: structured fields, a caller-selected regional rule, and optionally an indexed directory snapshot.
- Output: legacy rule diagnostics, or directory candidate intersection, hierarchy conflicts, ambiguity/coverage decisions, canonical fields, and checked label lines.
- Built-ins: US, CA, GB, JP, CN, AU, AE.
- Extension: callers can define additional `AddressRule` values and attach partial area/postal-prefix relationships. Uncovered areas are reported explicitly when such a table is configured.
- Not included: geocoding, free-text parsing, fuzzy correction, deliverability confirmation, global coverage, or online lookups inside the library.

## 2026-10-21 directory implementation and data provenance

- [Japan Post UTF-8 format description](https://www.post.japanpost.jp/zipcode/dl/utf-zip.html) and [data-field explanation](https://www.post.japanpost.jp/zipcode/dl/readme.html) were read for the 15-column structure, seven-digit codes, one-town/multiple-code flag, one-code/multiple-town flag, fallback labels, and dedicated-business-code exclusion. The UTF-8 variant keeps long town names in one row; the legacy Shift-JIS split-row format is not accepted by this adapter.
- The old download URL on the legacy page returned HTTP 404. The working official archive is [the new Japan Post download path](https://www.post.japanpost.jp/service/search/zipcode/download/utf/zip/utf_ken_all.zip), fetched successfully on 2026-10-21. The replacement URL was located through `memwey/utfkenall`'s `tools/gendata/fetch.go`; no Go source, algorithms, or generated database were copied.
- Snapshot ZIP SHA-256: `444881769a631d2c36c644fc041e5ce62fe65d204ff498a601641ba1e66b5955`. Converted TSV SHA-256: `926e73a4c9214570a1b85290230039d9f89fbca7971278814035aaadbf174573`. Source rows: 124,526; unique rows: 124,525; exact: 115,990; unspecified: 1,893; conditional: 6,642. These are observed snapshot counts, not guaranteed future counts.
- The full raw/converted dataset is downloaded locally under ignored `_build/data`; it is not relicensed as MIT or bundled into Git/Mooncakes. Users must review upstream data terms and their own redistribution requirements. Public examples use three attributed Chiyoda routing facts; relationship stress tests use explicitly synthetic records. No personal addresses are included.
- The Python adapter uses standard-library CSV/ZIP handling and preserves upstream region/city/town text. Parenthesized ranges, the multiple-code flag, and fallback notes are retained as uncertain data, not interpreted as exact town names or rewritten into delivery addresses. Full-width/variant-script normalization and range interpretation are not implemented.
- New core algorithms are independent MoonBit implementations: two hash indexes, exact duplicate elimination, country-scoped candidate filtering across region/city/town, explicit unknown/conflict/ambiguity decisions, and checked canonicalization. Construction is linear in input size; postal queries visit only that code's bucket, reverse queries visit the selected city bucket. Data must fit in memory.
- GitHub repository searches `postal language:MoonBit` and `address validation MoonBit` were repeated on 2026-10-21: the former returned this repository, and the latter returned no repositories. These are finite repository searches, not a full code-level audit. The Mooncakes comparison above remains the **2026-10-16** snapshot review and was not refreshed by these searches.

## Licensing

The code is an independent implementation and does not copy Google source code or regional data. Google's project identifies its C++ library as Apache-2.0 and its address metadata as CC-BY-4.0; review exact files and attribution requirements before importing either. Code license: MIT. Japan Post data provenance and the separate acquisition/distribution boundary are described above. The native example uses the separately licensed `moonbitlang/x` filesystem package; it is not vendored into the core.

## 2026-10-23 follow-up and adjacent projects

The saved 2026-10-21 Japan Post ZIP/TSV was reverified against the hashes above; no claim is made that it is the latest upstream release. Exhaustive forward/reverse inclusion probes passed for all 124,525 unique rows. Adapter installation now stages all files, replaces TSV last, and supports offline `--verify`; interruption can still leave a mixed bundle, which must be rejected on hash mismatch.

Repository searches `postal language:MoonBit` and `address validation MoonBit` were repeated: the former returned this project, the latter no repositories. A separate local Mooncakes registry metadata search found adjacent projects omitted from the older comparison:

| Project | Inspected public evidence | Overlap and declared distinction |
| --- | --- | --- |
| `vicoproplus/moon_cpca@0.1.0` | [repository README](https://github.com/vicoplus/moon_cpca), Chinese administrative extraction, adcode, 3,511 divisions, MIT/cpca port description | Extracts province/city/district from free text. Shares administrative-address concepts; MoonPostal consumes structured postal relations and reports postal uncertainty/version/batch decisions. Registry namespace and repository owner have different spellings. |
| `JIA2JIA2/moonbitgeodb@0.1.3` | [repository README](https://github.com/JIA2JIA2/moonbitGEODB), parsing, semantic matching, GIS indexes and persistence, Apache-2.0 description | Shares general address/index/integrity concepts and has broader geospatial aims. MoonPostal does not implement its free-text/geospatial/ML pipeline; its declared contract is postal routing and snapshot lifecycle. |

This is a finite README/metadata comparison, not a full implementation audit or proof of uniqueness. Neither project is a dependency, source-code donor, or integrated component. New snapshot/batch code is independently implemented in MoonBit; Python continues to handle data acquisition only. See `ENGINEERING.md` for exact responsibility and cost boundaries.
