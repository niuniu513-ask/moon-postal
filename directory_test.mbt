/// Synthetic many-to-many records exercise relationships, not real coverage.

///|
fn directory() -> @moon-postal.PostalDirectory {
  @moon-postal.PostalDirectory::new(
    [
      @moon-postal.PostalEntry::new(
        "JP", "1000001", "東京都", "千代田区", "千代田",
      ),
      @moon-postal.PostalEntry::new(
        "JP", "1234567", "A県", "中央市", "東町",
      ),
      @moon-postal.PostalEntry::new(
        "JP", "1234567", "A県", "中央市", "西町",
      ),
      @moon-postal.PostalEntry::new(
        "JP", "1234568", "A県", "中央市", "東町",
      ),
      @moon-postal.PostalEntry::new(
        "JP", "2234567", "B県", "中央市", "東町",
      ),
      @moon-postal.PostalEntry::new(
        "JP",
        "1000000",
        "東京都",
        "千代田区",
        "以下に掲載がない場合",
        coverage=@moon-postal.UnspecifiedTown,
      ),
      @moon-postal.PostalEntry::new(
        "JP",
        "3234567",
        "C県",
        "試験市",
        "北町（１丁目）",
        coverage=@moon-postal.ConditionalTown,
      ),
    ],
    source="One Japan Post fact plus explicitly synthetic relation fixtures",
  ).unwrap()
}

///|
fn jp() -> @moon-postal.AddressRule {
  @moon-postal.builtin_rule("JP").unwrap()
}

///|
fn request(
  country~ : String = "JP",
  postal~ : String = "1000001",
  area~ : String = "",
  city~ : String = "",
  town~ : String = "",
) -> @moon-postal.Address {
  @moon-postal.Address::new(
    country_code=country,
    postal_code=postal,
    administrative_area=area,
    locality=city,
    dependent_locality=town,
    address_lines=["1"],
  )
}

///|
test "postal lookup fills hierarchy and emits a checked label" {
  let d = directory()
  let result = d.resolve(
    jp(),
    @moon-postal.Address::new(country_code="jp", postal_code="100-0001", address_lines=[
      "1-1",
    ]),
  )
  assert_true(result.status() == @moon-postal.Resolved)
  assert_eq(result.canonical().unwrap().locality, "千代田区")
  assert_eq(result.canonical().unwrap().dependent_locality, "千代田")
  assert_eq(
    result.label_lines().join("\n"),
    "1000001\n東京都\n千代田区\n千代田\n1-1\nJP",
  )
  assert_true(result.issues().is_empty())
}

///|
test "postal ambiguity never picks the first town" {
  let r = directory().resolve(
    jp(),
    @moon-postal.Address::new(country_code="JP", postal_code="1234567", address_lines=[
      "1",
    ]),
  )
  assert_true(r.status() == @moon-postal.Ambiguous)
  assert_eq(r.candidates().length(), 2)
  assert_true(r.canonical() is None)
  assert_true(r.label_lines().is_empty())
}

///|
test "town disambiguates postal candidates and preserves detail" {
  let r = directory().resolve(
    jp(),
    @moon-postal.Address::new(
      country_code="JP",
      postal_code="1234567",
      dependent_locality="西町",
      recipient="Example",
      address_lines=["2-3", "Room 8"],
    ),
  )
  assert_true(r.status() == @moon-postal.Resolved)
  assert_eq(r.canonical().unwrap().dependent_locality, "西町")
  assert_true(r.label_lines().contains("Room 8"))
  assert_true(r.label_lines().contains("Example"))
}

///|
test "each supplied hierarchy field can conflict" {
  let d = directory()
  for
    (field, address) in [
      (@moon-postal.AdministrativeArea, request(area="大阪府")),
      (@moon-postal.Locality, request(city="大阪市")),
      (@moon-postal.DependentLocality, request(town="丸の内")),
    ] {
    let r = d.resolve(jp(), address)
    assert_true(r.status() == @moon-postal.Conflict)
    assert_true(r.conflict_field() == Some(field))
    assert_eq(r.candidates().length(), 1)
    assert_true(r.label_lines().is_empty())
  }
}

///|
test "reverse lookup respects city area and one town with many codes" {
  let d = directory()
  assert_eq(d.lookup_locality("JP", "中央市", town="東町").length(), 3)
  assert_eq(
    d.lookup_locality("JP", "中央市", area="A県", town="東町").length(),
    2,
  )
  let r = d.resolve(
    jp(),
    @moon-postal.Address::new(
      country_code="JP",
      administrative_area="A県",
      locality="中央市",
      dependent_locality="西町",
      address_lines=["1"],
    ),
  )
  assert_true(r.status() == @moon-postal.Resolved)
  assert_eq(r.canonical().unwrap().postal_code, "1234567")
  let ambiguous = d.resolve(
    jp(),
    @moon-postal.Address::new(
      country_code="JP",
      administrative_area="A県",
      locality="中央市",
      dependent_locality="東町",
      address_lines=["1"],
    ),
  )
  assert_true(ambiguous.status() == @moon-postal.Ambiguous)
}

///|
test "unknown postal locality and insufficient inputs stay distinct" {
  let d = directory()
  assert_true(
    d.resolve(jp(), request(postal="9999999")).status() ==
    @moon-postal.UnknownPostal,
  )
  assert_true(
    d.resolve(jp(), request(postal="", city="未収録市")).status() ==
    @moon-postal.UnknownLocality,
  )
  assert_true(
    d.resolve(jp(), request(postal="")).status() ==
    @moon-postal.InsufficientInput,
  )
  assert_true(
    d.resolve(jp(), request(country="")).status() ==
    @moon-postal.InsufficientInput,
  )
}

///|
test "format country and control errors block directory decisions" {
  let d = directory()
  for
    address in [
      request(postal="100X001"),
      request(country="US"),
      request(city="千代田区\n"),
      @moon-postal.Address::new(
        country_code="JP",
        postal_code="1000001",
        recipient="Example\nInjected",
        address_lines=["1"],
      ),
      @moon-postal.Address::new(country_code="JP", postal_code="1000001", address_lines=[
        "1\t2",
      ]),
    ] {
    let r = d.resolve(jp(), address)
    assert_true(r.status() == @moon-postal.InvalidInput)
    assert_true(r.label_lines().is_empty())
  }
}

///|
test "fallback and conditional towns never become address text" {
  for code in ["1000000", "3234567"] {
    let r = directory().resolve(
      jp(),
      @moon-postal.Address::new(
        country_code="JP",
        postal_code=code,
        dependent_locality="unknown town",
        address_lines=["1"],
      ),
    )
    assert_true(r.status() == @moon-postal.UnverifiedTown)
    assert_true(r.canonical() is None)
    assert_true(r.label_lines().is_empty())
  }
}

///|
test "missing street detail still blocks a unique routing result" {
  let r = directory().resolve(
    jp(),
    @moon-postal.Address::new(country_code="JP", postal_code="1000001"),
  )
  assert_true(r.status() == @moon-postal.InvalidInput)
  assert_true(!r.issues().is_empty())
  assert_true(r.label_lines().is_empty())
}

///|
test "duplicate data and returned arrays cannot change the index" {
  let entry = @moon-postal.PostalEntry::new(
    "JP", "1000001", "東京都", "千代田区", "千代田",
  )
  let entries = [entry, entry]
  let d = @moon-postal.PostalDirectory::new(entries, source="fixture").unwrap()
  entries.clear()
  let found = d.lookup_postal("jp", "100-0001")
  found.clear()
  assert_eq(d.size(), 1)
  assert_eq(d.lookup_postal("JP", "1000001").length(), 1)
  assert_eq(d.source(), "fixture")
}

///|
test "TSV imports CRLF and rejects incomplete unknown or corrupt rows" {
  let header = "country\tpostal\tarea\tcity\ttown\tcoverage\r\n"
  let row = "JP\t1000001\t東京都\t千代田区\t千代田\texact\r\n"
  let d = @moon-postal.PostalDirectory::from_tsv(header + row, source="fixture").unwrap()
  assert_eq(d.size(), 1)
  for
    text in [
      "bad header",
      header,
      header + row + "bad",
      header + "JP\t1000001\tA\tB\tC\tunknown",
      header + "JP\t1000001\t\tB\tC\texact",
      header + "JP\t100X001\tA\tB\tC\texact",
      header + "JP\t100-0001\tA\tB\tC\texact",
      header + "JP\t1000001\tA\rB\tC\tD\texact",
    ] {
    assert_true(
      @moon-postal.PostalDirectory::from_tsv(text, source="fixture") is Err(_),
    )
  }
}

///|
test "directory label cannot drop its resolved town" {
  let rule = @moon-postal.AddressRule::new(
    "JP",
    [@moon-postal.AddressLine],
    @moon-postal.PostalPattern::digits(7),
    [@moon-postal.AddressLine],
  )
  let r = directory().resolve(
    rule,
    @moon-postal.Address::new(country_code="JP", postal_code="1000001", address_lines=[
      "1",
    ]),
  )
  assert_true(r.status() == @moon-postal.InvalidInput)
  assert_true(r.label_lines().is_empty())
}
