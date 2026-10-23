///|
fn entry(
  code : String,
  town : String,
  coverage~ : @moon-postal.TownCoverage = @moon-postal.ExactTown,
) -> @moon-postal.PostalEntry {
  @moon-postal.PostalEntry::new(
    "JP",
    code,
    "試験県",
    "試験市",
    town,
    coverage~,
  )
}

///|
fn snapshot(
  entries : Array[@moon-postal.PostalEntry],
) -> @moon-postal.DirectorySnapshot {
  @moon-postal.DirectorySnapshot::new(
    @moon-postal.PostalDirectory::new(entries, source="synthetic test data").unwrap(),
    revision="v1",
  ).unwrap()
}

///|
fn job(
  id : String,
  postal : String,
  city~ : String = "",
) -> @moon-postal.AddressJob {
  @moon-postal.AddressJob::new(
    id,
    @moon-postal.Address::new(
      country_code="JP",
      postal_code=postal,
      locality=city,
      address_lines=["1-2"],
    ),
  )
}

///|
test "atomic update changes both lookup directions but retains old snapshot" {
  let old = snapshot([entry("1234567", "東町"), entry("2234567", "西町")])
  let next = old
    .apply(
      expected_revision="v1",
      revision="v2",
      additions=[entry("3234567", "東町")],
      removals=[entry("1234567", "東町")],
      source="updated synthetic data",
    )
    .unwrap()
  assert_eq(old.directory().lookup_postal("JP", "1234567").length(), 1)
  assert_true(next.directory().lookup_postal("JP", "1234567").is_empty())
  assert_eq(next.directory().lookup_postal("JP", "3234567").length(), 1)
  let reverse = next
    .directory()
    .lookup_locality("JP", "試験市", town="東町")
  assert_eq(reverse.length(), 1)
  assert_eq(reverse[0].postal, "3234567")
  assert_eq(next.revision(), "v2")
  let diff = old.compare(next)
  assert_eq(diff.added()[0].postal, "3234567")
  assert_eq(diff.removed()[0].postal, "1234567")
  assert_eq(old.compare(old).added().length(), 0)
}

///|
test "stale base same version invalid version and patch limits reject" {
  let old = snapshot([entry("1234567", "東町")])
  assert_true(
    old.apply(
      expected_revision="old",
      revision="v2",
      additions=[],
      removals=[],
      source="new",
    )
    is Err(@moon-postal.StaleRevision),
  )
  assert_true(
    old.apply(
      expected_revision="v1",
      revision="v1",
      additions=[],
      removals=[],
      source="new",
    )
    is Err(@moon-postal.SameRevision),
  )
  assert_true(
    old.apply(
      expected_revision="v1",
      revision="bad\nversion",
      additions=[],
      removals=[],
      source="new",
    )
    is Err(@moon-postal.InvalidRevision),
  )
  assert_true(
    old.apply(
      expected_revision="v1",
      revision="v2",
      additions=[entry("2234567", "西町")],
      removals=[],
      source="new",
      max_changes=0,
    )
    is Err(@moon-postal.TooManyChanges),
  )
}

///|
test "duplicate missing and existing operations never partially apply" {
  let old = snapshot([entry("1234567", "東町")])
  let new = entry("2234567", "西町")
  assert_true(
    old.apply(
      expected_revision="v1",
      revision="v2",
      additions=[new, new],
      removals=[],
      source="new",
    )
    is Err(@moon-postal.DuplicateAddition(2)),
  )
  assert_true(
    old.apply(
      expected_revision="v1",
      revision="v2",
      additions=[],
      removals=[new],
      source="new",
    )
    is Err(@moon-postal.MissingRemoval(1)),
  )
  assert_true(
    old.apply(
      expected_revision="v1",
      revision="v2",
      additions=[],
      removals=[entry("1234567", "東町"), entry("1234567", "東町")],
      source="new",
    )
    is Err(@moon-postal.DuplicateRemoval(2)),
  )
  assert_true(
    old.apply(
      expected_revision="v1",
      revision="v2",
      additions=[entry("1234567", "東町")],
      removals=[],
      source="new",
    )
    is Err(@moon-postal.ExistingAddition(1)),
  )
  assert_eq(old.directory().size(), 1)
  assert_eq(old.revision(), "v1")
}

///|
test "invalid replacement or empty final directory preserves original" {
  let first = entry("1234567", "東町")
  let old = snapshot([first])
  let invalid = @moon-postal.PostalEntry::new("JP", "bad", "県", "市", "町")
  assert_true(
    old.apply(
      expected_revision="v1",
      revision="v2",
      additions=[invalid],
      removals=[first],
      source="new",
    )
    is Err(@moon-postal.InvalidDirectory(_)),
  )
  assert_true(
    old.apply(
      expected_revision="v1",
      revision="v2",
      additions=[],
      removals=[first],
      source="new",
    )
    is Err(@moon-postal.InvalidDirectory(@moon-postal.EmptyDirectory)),
  )
  assert_eq(old.directory().lookup_postal("JP", "1234567").length(), 1)
}

///|
test "coverage change is not hidden by duplicate elimination" {
  let old = snapshot([entry("1234567", "東町")])
  let next = old
    .apply(
      expected_revision="v1",
      revision="v2",
      additions=[
        entry("1234567", "東町", coverage=@moon-postal.ConditionalTown),
      ],
      removals=[entry("1234567", "東町")],
      source="new",
    )
    .unwrap()
  let diff = old.compare(next)
  assert_eq(diff.added().length(), 1)
  assert_eq(diff.removed().length(), 1)
  let rule = @moon-postal.builtin_rule("JP").unwrap()
  assert_true(
    next.resolve(rule, job("1", "1234567").address).decision.status() ==
    @moon-postal.UnverifiedTown,
  )
}

///|
test "audit traces a narrowing conflict without leaking street or recipient" {
  let snap = snapshot([
    entry("1234567", "東町"),
    entry("1234567", "西町"),
    entry("2234567", "南町"),
  ])
  let r = snap.resolve(
    @moon-postal.builtin_rule("JP").unwrap(),
    job("1", "1234567", city="別の市").address,
  )
  assert_eq(r.revision, "v1")
  assert_eq(r.steps.length(), 2)
  assert_eq(r.steps[0].before, 3)
  assert_eq(r.steps[0].after, 2)
  assert_true(r.steps[1].field == @moon-postal.Locality)
  assert_eq(r.steps[1].after, 0)
  assert_true(r.decision.status() == @moon-postal.Conflict)
  assert_true(r.completed_fields.is_empty())
}

///|
test "audit marks only missing fields actually completed" {
  let snap = snapshot([entry("1234567", "東町")])
  let r = snap.resolve(
    @moon-postal.builtin_rule("JP").unwrap(),
    job("1", "1234567").address,
  )
  assert_true(r.decision.status() == @moon-postal.Resolved)
  assert_eq(r.completed_fields.length(), 3)
  assert_true(!r.completed_fields.contains(@moon-postal.PostalCode))
  assert_true(r.completed_fields.contains(@moon-postal.DependentLocality))
}

///|
test "batch counts all routing outcomes and preserves input ids" {
  let snap = snapshot([
    entry("1234567", "東町"),
    entry("2234567", "西町"),
    entry("2234567", "南町"),
    entry("3234567", "不明", coverage=@moon-postal.UnspecifiedTown),
  ])
  let jobs = [
    job("ok", "1234567"),
    job("conflict", "1234567", city="別の市"),
    job("ambiguous", "2234567"),
    job("unknown", "9999999"),
    job("special", "3234567"),
    job("bad", "bad"),
    job("missing", ""),
  ]
  let report = snap
    .resolve_batch(@moon-postal.builtin_rule("JP").unwrap(), jobs)
    .unwrap()
  assert_eq(report.rows.length(), 7)
  assert_eq(report.rows[0].id, "ok")
  assert_eq(report.rows[6].id, "missing")
  assert_eq(report.resolved, 1)
  assert_eq(report.conflicted, 1)
  assert_eq(report.ambiguous, 1)
  assert_eq(report.unknown, 1)
  assert_eq(report.unverified, 1)
  assert_eq(report.invalid, 1)
  assert_eq(report.insufficient, 1)
  assert_true(!report.labels_for("ok").is_empty())
  assert_true(report.labels_for("unknown").is_empty())
  let labels = report.labels_for("ok")
  labels.clear()
  assert_true(!report.labels_for("ok").is_empty())
  for row in report.rows {
    assert_eq(row.audit.revision, "v1")
  }
}

///|
test "all or nothing policy withholds every export on any failed row" {
  let snap = snapshot([entry("1234567", "東町")])
  let rule = @moon-postal.builtin_rule("JP").unwrap()
  let report = snap
    .resolve_batch(
      rule,
      [job("ok", "1234567"), job("bad", "9999999")],
      policy=@moon-postal.RequireAllResolved,
    )
    .unwrap()
  assert_true(!report.export_allowed)
  assert_eq(report.resolved, 1)
  assert_true(report.labels_for("ok").is_empty())
  assert_true(report.rows[0].audit.decision.status() == @moon-postal.Resolved)
  let valid = snap
    .resolve_batch(
      rule,
      [job("ok", "1234567")],
      policy=@moon-postal.RequireAllResolved,
    )
    .unwrap()
  assert_true(valid.export_allowed)
  assert_true(!valid.labels_for("ok").is_empty())
}

///|
test "invalid batch ids duplicate ids and capacity reject before processing" {
  let snap = snapshot([entry("1234567", "東町")])
  let rule = @moon-postal.builtin_rule("JP").unwrap()
  assert_true(
    snap.resolve_batch(rule, [job("same", "1234567"), job("same", "9999999")])
    is Err(@moon-postal.DuplicateJobId(2)),
  )
  assert_true(
    snap.resolve_batch(rule, [job("bad\nid", "1234567")])
    is Err(@moon-postal.InvalidJobId(1)),
  )
  assert_true(
    snap.resolve_batch(rule, [job("", "1234567")])
    is Err(@moon-postal.InvalidJobId(1)),
  )
  assert_true(
    snap.resolve_batch(rule, [], max_jobs=0) is Err(@moon-postal.InvalidLimit),
  )
  assert_true(
    snap.resolve_batch(
      rule,
      [job("a", "1234567"), job("b", "1234567")],
      max_jobs=1,
    )
    is Err(@moon-postal.TooManyJobs),
  )
  assert_eq(snap.resolve_batch(rule, []).unwrap().rows.length(), 0)
}

///|
test "TSV export reimport preserves routing and uncertainty" {
  let old = snapshot([
    entry("1234567", "東町"),
    entry("2234567", "不明", coverage=@moon-postal.UnspecifiedTown),
  ])
  let text = old.directory().to_tsv()
  let copy = @moon-postal.PostalDirectory::from_tsv(text, source="roundtrip").unwrap()
  assert_eq(copy.to_tsv(), text)
  assert_eq(copy.lookup_locality("JP", "試験市").length(), 2)
}

///|
test "US ZIP plus four survives normalized directory keys and roundtrip" {
  let e = @moon-postal.PostalEntry::new(
    "US", "02108-1234", "MA", "BOSTON", "BEACON HILL",
  )
  let dir = @moon-postal.PostalDirectory::new(
    [e],
    source="synthetic ZIP+4 routing",
  ).unwrap()
  let copy = @moon-postal.PostalDirectory::from_tsv(
    dir.to_tsv(),
    source="roundtrip",
  ).unwrap()
  let rule = @moon-postal.AddressRule::new(
    "US",
    [@moon-postal.AddressLine, @moon-postal.PostalCode],
    @moon-postal.builtin_rule("US").unwrap().postal_pattern,
    [
      @moon-postal.AddressLine,
      @moon-postal.Locality,
      @moon-postal.AdministrativeArea,
      @moon-postal.DependentLocality,
      @moon-postal.PostalCode,
      @moon-postal.Country,
    ],
  )
  let result = copy.resolve(
    rule,
    @moon-postal.Address::new(country_code="US", postal_code="02108-1234", address_lines=[
      "12 Test St",
    ]),
  )
  assert_true(result.status() == @moon-postal.Resolved)
  assert_eq(result.canonical().unwrap().postal_code, "02108-1234")
}
