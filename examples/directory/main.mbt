///|
fn main {
  let table = "country\tpostal\tarea\tcity\ttown\tcoverage\n" +
    "JP\t1000001\t東京都\t千代田区\t千代田\texact\n" +
    "JP\t1000002\t東京都\t千代田区\t皇居外苑\texact\n" +
    "JP\t1000000\t東京都\t千代田区\t以下に掲載がない場合\tunspecified\n"
  let directory = @moon-postal.PostalDirectory::from_tsv(
    table,
    source="Japan Post: three attributed town-routing rows",
  ).unwrap()
  let rule = @moon-postal.builtin_rule("JP").unwrap()
  let requests = [
    @moon-postal.Address::new(
      address_lines=["1-1"],
      postal_code="100-0001",
      country_code="JP",
    ),
    @moon-postal.Address::new(
      address_lines=["1-1"],
      postal_code="1000001",
      administrative_area="大阪府",
      country_code="JP",
    ),
    @moon-postal.Address::new(
      address_lines=["1-1"],
      locality="千代田区",
      country_code="JP",
    ),
    @moon-postal.Address::new(
      address_lines=["1-1"],
      postal_code="1000000",
      country_code="JP",
    ),
    @moon-postal.Address::new(
      address_lines=["1-1"],
      postal_code="0000000",
      country_code="JP",
    ),
  ]
  for address in requests {
    let result = directory.resolve(rule, address)
    let status = match result.status() {
      Resolved => "resolved"
      Conflict => "conflict"
      Ambiguous => "ambiguous"
      UnknownPostal => "unknown postal code"
      UnknownLocality => "unknown locality"
      UnverifiedTown => "unverified town"
      InvalidInput => "invalid input"
      InsufficientInput => "insufficient input"
    }
    println(
      status + ": " + result.candidates().length().to_string() + " candidates",
    )
    for line in result.label_lines() {
      println("  " + line)
    }
  }
}
