/// Load the complete snapshot at runtime; no giant generated source file.

///|
fn main raise {
  let args = @env.args()
  let path = if args.length() > 1 { args[1] } else { "_build/data/jp.tsv" }
  let text = @fs.read_file_to_string(path) catch {
    _ => {
      println("Cannot load directory: " + path)
      abort("Run python scripts/import_japan_post.py first")
    }
  }
  let directory = @moon-postal.PostalDirectory::from_tsv(text, source=path).unwrap()
  println("Directory records: " + directory.size().to_string())
  let rule = @moon-postal.builtin_rule("JP").unwrap()
  let address = @moon-postal.Address::new(
    country_code="JP",
    postal_code="100-0001",
    address_lines=["1-1"],
  )
  let result = directory.resolve(rule, address)
  assert_true(result.status() == @moon-postal.Resolved)
  for line in result.label_lines() {
    println(line)
  }
  let conflict = directory.resolve(
    rule,
    @moon-postal.Address::new(
      country_code="JP",
      postal_code="1000001",
      locality="大阪市北区",
      address_lines=["1-1"],
    ),
  )
  assert_true(conflict.status() == @moon-postal.Conflict)
  assert_true(conflict.label_lines().is_empty())
  println("Conflicting city rejected")
  let reverse = directory.lookup_locality(
    "JP",
    "千代田区",
    town="千代田",
  )
  assert_true(reverse.length() == 1)
  assert_true(reverse[0].postal == "1000001")
  println("Reverse lookup: " + reverse[0].postal)
  // Sample the entire ordered national file, not only the Tokyo example.
  let mut probes = 0
  for i, line in text.split("\n").to_array() {
    if i == 0 || i % 251 != 1 || line.is_empty() {
      continue
    }
    let fields = line.split("\t").map(s => s.to_owned()).to_array()
    assert_true(fields.length() == 6)
    let forward = directory.lookup_postal(fields[0], fields[1])
    assert_true(
      forward
      .iter()
      .any(e => {
        e.area == fields[2] && e.city == fields[3] && e.town == fields[4]
      }),
    )
    let backward = directory.lookup_locality(
      fields[0],
      fields[3],
      area=fields[2],
      town=fields[4],
    )
    assert_true(backward.iter().any(e => e.postal == fields[1]))
    probes += 1
  }
  println("National forward/reverse probes passed: " + probes.to_string())
}
