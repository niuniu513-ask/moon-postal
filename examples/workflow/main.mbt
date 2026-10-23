/// Synthetic update scenario: postal reassignment invalidates an old code.

///|
fn main raise {
  let entry = @moon-postal.PostalEntry::new(
    "JP", "1234567", "試験県", "試験市", "東町",
  )
  let directory = @moon-postal.PostalDirectory::new(
    [entry],
    source="synthetic routing v1",
  ).unwrap()
  let v1 = @moon-postal.DirectorySnapshot::new(directory, revision="v1").unwrap()
  let rule = @moon-postal.builtin_rule("JP").unwrap()
  let jobs = [
    @moon-postal.AddressJob::new(
      "order-1",
      @moon-postal.Address::new(country_code="JP", postal_code="1234567", address_lines=[
        "1-2",
      ]),
    ),
    @moon-postal.AddressJob::new(
      "order-2",
      @moon-postal.Address::new(
        country_code="JP",
        postal_code="1234567",
        locality="別の市",
        address_lines=["3-4"],
      ),
    ),
  ]
  let batch = v1
    .resolve_batch(rule, jobs, policy=@moon-postal.RequireAllResolved)
    .unwrap()
  assert_eq(batch.resolved, 1)
  assert_eq(batch.conflicted, 1)
  assert_true(!batch.export_allowed)
  assert_true(batch.labels_for("order-1").is_empty())
  println("v1 batch: 1 resolved, 1 conflict; export withheld")
  for step in batch.rows[1].audit.steps {
    println(
      "Candidate step: " +
      step.before.to_string() +
      " -> " +
      step.after.to_string(),
    )
  }
  let v2 = v1
    .apply(
      expected_revision="v1",
      revision="v2",
      additions=[
        @moon-postal.PostalEntry::new(
          "JP", "2234567", "試験県", "試験市", "東町",
        ),
      ],
      removals=[entry],
      source="synthetic routing v2",
    )
    .unwrap()
  let diff = v1.compare(v2)
  assert_eq(diff.added().length(), 1)
  assert_eq(diff.removed().length(), 1)
  println("v2 update: 1 addition, 1 removal")
  let stale = v2.apply(
    expected_revision="v1",
    revision="v3",
    additions=[],
    removals=[],
    source="stale update",
  )
  assert_true(stale is Err(@moon-postal.StaleRevision))
  println("Stale update rejected")
  let old_result = v1.resolve(rule, jobs[0].address)
  let new_result = v2.resolve(rule, jobs[0].address)
  assert_true(old_result.decision.status() == @moon-postal.Resolved)
  assert_true(new_result.decision.status() == @moon-postal.UnknownPostal)
  println("Old code: resolved in v1, unknown in v2")
  let reverse = v2.directory().lookup_locality("JP", "試験市", town="東町")
  assert_eq(reverse[0].postal, "2234567")
  println("Reverse lookup after update: " + reverse[0].postal)
}
