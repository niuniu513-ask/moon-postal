///|
fn sample_address(
  country_code : String,
  postal_code : String,
) -> @moon-postal.Address {
  @moon-postal.Address::new(
    address_lines=["1 Example Road"],
    locality="Example City",
    administrative_area="EX",
    postal_code~,
    country_code~,
  )
}

///|
test "US address validation and formatting" {
  let rule = @moon-postal.builtin_rule("us").unwrap()
  let address = @moon-postal.Address::new(
    recipient="Ada Lovelace",
    address_lines=["12 Example Street"],
    locality="Boston",
    administrative_area="MA",
    postal_code="02108-1234",
    country_code="US",
  )
  assert_eq(@moon-postal.validate(rule, address).length(), 0)
  assert_eq(
    @moon-postal.format_address(rule, address),
    "Ada Lovelace\n12 Example Street\nBoston\nMA\n02108-1234\nUS",
  )
}

///|
test "required fields and invalid postal code are reported" {
  let rule = @moon-postal.builtin_rule("CA").unwrap()
  let address = @moon-postal.Address::new(
    address_lines=["1 Example Road"],
    locality="Ottawa",
    administrative_area="ON",
    postal_code="D1A2B3",
    country_code="CA",
  )
  let issues = @moon-postal.validate(rule, address)
  assert_eq(issues.length(), 1)
  assert_true(issues[0].code is @moon-postal.InvalidPostalCode)
}

///|
test "country postal patterns accept and reject representative shapes" {
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("CN").unwrap(),
      sample_address("CN", "100000"),
    ).length(),
    0,
  )
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("JP").unwrap(),
      sample_address("JP", "100-0001"),
    ).length(),
    0,
  )
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("GB").unwrap(),
      sample_address("GB", "SW1A 1AA"),
    ).length(),
    0,
  )
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("CA").unwrap(),
      sample_address("CA", "K1A 0B1"),
    ).length(),
    0,
  )
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("CA").unwrap(),
      sample_address("CA", "K-1A--0B1"),
    ).length(),
    1,
  )
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("CN").unwrap(),
      sample_address("CN", "10-0000"),
    ).length(),
    1,
  )
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("US").unwrap(),
      sample_address("US", "1234"),
    ).length(),
    1,
  )
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("US").unwrap(),
      sample_address("US", "123451234"),
    ).length(),
    1,
  )
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("AU").unwrap(),
      sample_address("AU", "2000"),
    ).length(),
    0,
  )
  assert_eq(
    @moon-postal.validate(
      @moon-postal.builtin_rule("AE").unwrap(),
      sample_address("AE", ""),
    ).length(),
    0,
  )
}

///|
test "unknown countries are not guessed" {
  assert_true(@moon-postal.builtin_rule("ZZ") is None)
}

///|
test "custom rules support caller-defined field and postal constraints" {
  let rule = @moon-postal.AddressRule::new(
    "XY",
    [
      @moon-postal.AddressField::AddressLine,
      @moon-postal.AddressField::PostalCode,
    ],
    @moon-postal.PostalPattern::alphanumeric_in_range(4, 8),
    [
      @moon-postal.AddressField::AddressLine,
      @moon-postal.AddressField::PostalCode,
    ],
  )
  let address = @moon-postal.Address::new(
    address_lines=["Somewhere"],
    postal_code="AB12",
    country_code="xy",
  )
  assert_eq(@moon-postal.validate(rule, address).length(), 0)
}

///|
test "country code mismatch is diagnostic" {
  let rule = @moon-postal.builtin_rule("US").unwrap()
  let address = @moon-postal.Address::new(country_code="CA")
  let issues = @moon-postal.validate(rule, address)
  assert_true(issues[0].code is @moon-postal.CountryMismatch)
}

///|
test "formatter skips empty fields and keeps every address line" {
  let rule = @moon-postal.builtin_rule("GB").unwrap()
  let address = @moon-postal.Address::new(
    organization="Example Ltd",
    address_lines=["2 High Street", "Flat 4"],
    locality="London",
    postal_code="SW1A 1AA",
    country_code="GB",
  )
  assert_eq(
    @moon-postal.format_address(rule, address),
    "Example Ltd\n2 High Street\nFlat 4\nLondon\nSW1A 1AA\nGB",
  )
}
