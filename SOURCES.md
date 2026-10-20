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

- Input: structured fields and a caller-selected regional rule.
- Output: field-specific diagnostics, a relationship status when caller data is configured, and ordered label lines only when configured checks pass.
- Built-ins: US, CA, GB, JP, CN, AU, AE.
- Extension: callers can define additional `AddressRule` values and attach partial area/postal-prefix relationships. Uncovered areas are reported explicitly when such a table is configured.
- Not included: geocoding, deliverability confirmation, global administrative-area databases, localized field labels, or network lookups.

## Licensing

The initial code is an independent implementation and does not copy Google source code or regional data. The upstream project identifies its C++ library as Apache-2.0 and its address metadata as CC-BY-4.0; review exact files and attribution requirements before importing either. Project license: MIT.
