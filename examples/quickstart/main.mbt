///|
fn main {
  let rule = @moon-postal.builtin_rule("US").unwrap()
  let address = @moon-postal.Address::new(
    recipient="Ada Lovelace",
    organization="Analytical Engines",
    address_lines=["12 Example Street", "Suite 3"],
    locality="Boston",
    administrative_area="MA",
    postal_code="02108",
    country_code="US",
  )
  let issues = @moon-postal.validate(rule, address)
  println("Issues: " + issues.length().to_string())
  println(@moon-postal.format_address(rule, address))
}
