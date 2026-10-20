///|
fn show(
  name : String,
  rule : @moon-postal.AddressRule,
  address : @moon-postal.Address,
) -> Unit {
  let decision = @moon-postal.assess(rule, address)
  println(name)
  match decision.relationship_status() {
    @moon-postal.Matched => println("Relationship: matched")
    @moon-postal.Mismatched => println("Relationship: mismatched")
    @moon-postal.UnknownArea => println("Relationship: area not covered")
    @moon-postal.NotConfigured => println("Relationship: not configured")
    @moon-postal.Skipped => println("Relationship: skipped")
  }
  for issue in decision.issues() {
    println("Issue: " + issue.message())
  }
  for line in decision.label_lines() {
    println("Label: " + line)
  }
}

///|
fn main {
  let rule = @moon-postal.builtin_rule("US")
    .unwrap()
    .with_area_postal_prefixes([
      @moon-postal.AreaPostalPrefix::new("MA", "021"),
      @moon-postal.AreaPostalPrefix::new("MA", "022"),
      @moon-postal.AreaPostalPrefix::new("NY", "100"),
    ])
  let valid = @moon-postal.Address::new(
    recipient="Ada Example",
    address_lines=["12 Example Street"],
    locality="Boston",
    administrative_area="MA",
    postal_code="02108",
    country_code="US",
  )
  let conflict = @moon-postal.Address::new(
    recipient="Ada Example",
    address_lines=["12 Example Street"],
    locality="Boston",
    administrative_area="MA",
    postal_code="10001",
    country_code="US",
  )
  let uncovered = @moon-postal.Address::new(
    recipient="Ada Example",
    address_lines=["12 Example Street"],
    locality="Chicago",
    administrative_area="IL",
    postal_code="60601",
    country_code="US",
  )
  show("Valid sample", rule, valid)
  show("Conflicting sample", rule, conflict)
  show("Uncovered sample", rule, uncovered)
}
