/// Immutable versioned postal data. Revision is caller metadata, not authenticity.

///|
pub struct DirectorySnapshot {
  priv revision : String
  priv directory : PostalDirectory
}

///|
pub(all) enum SnapshotError {
  InvalidRevision
  StaleRevision
  SameRevision
  InvalidDirectory(DirectoryError)
  DuplicateAddition(Int32)
  DuplicateRemoval(Int32)
  MissingRemoval(Int32)
  ExistingAddition(Int32)
  TooManyChanges
}

///|
pub fn DirectorySnapshot::new(
  directory : PostalDirectory,
  revision~ : String,
) -> Result[DirectorySnapshot, SnapshotError] {
  if revision.trim().is_empty() || has_directory_control(revision) {
    return Err(InvalidRevision)
  }
  Ok({ directory, revision, })
}

///|
pub fn DirectorySnapshot::revision(self : DirectorySnapshot) -> String {
  self.revision
}

///|
pub fn DirectorySnapshot::directory(
  self : DirectorySnapshot,
) -> PostalDirectory {
  self.directory
}

/// Key includes routing relation and coverage, so changing coverage is a real change.

///|
fn entry_identity(e : PostalEntry) -> String {
  let kind = match e.coverage {
    ExactTown => "exact"
    UnspecifiedTown => "unspecified"
    ConditionalTown => "conditional"
  }
  [e.country, e.postal, e.area, e.city, e.town, kind].join("\u{001f}")
}

///|
pub struct DirectoryChanges {
  priv added : Array[PostalEntry]
  priv removed : Array[PostalEntry]
}

///|
pub fn DirectoryChanges::added(self : DirectoryChanges) -> Array[PostalEntry] {
  self.added.copy()
}

///|
pub fn DirectoryChanges::removed(self : DirectoryChanges) -> Array[PostalEntry] {
  self.removed.copy()
}

/// Exact set difference in stable source order, including uncertainty transitions.

///|
pub fn DirectorySnapshot::compare(
  self : DirectorySnapshot,
  next : DirectorySnapshot,
) -> DirectoryChanges {
  let before : Map[String, Bool] = Map([])
  let after : Map[String, Bool] = Map([])
  for e in self.directory.entries {
    before[entry_identity(e)] = true
  }
  for e in next.directory.entries {
    after[entry_identity(e)] = true
  }
  {
    added: next.directory.entries.filter(e => {
      !before.contains(entry_identity(e))
    }),
    removed: self.directory.entries.filter(e => {
      !after.contains(entry_identity(e))
    }),
  }
}

/// Transactional deletion+addition. Base revision and all operations are checked
/// before rebuilding both indexes; failure leaves the old snapshot usable.
/// max_changes limits patch size, not database authenticity or total memory.

///|
pub fn DirectorySnapshot::apply(
  self : DirectorySnapshot,
  expected_revision~ : String,
  revision~ : String,
  additions~ : Array[PostalEntry],
  removals~ : Array[PostalEntry],
  source~ : String,
  max_changes~ : Int32 = 100000,
) -> Result[DirectorySnapshot, SnapshotError] {
  if expected_revision != self.revision {
    return Err(StaleRevision)
  }
  if revision == self.revision {
    return Err(SameRevision)
  }
  if revision.trim().is_empty() || has_directory_control(revision) {
    return Err(InvalidRevision)
  }
  if max_changes < 0 ||
    additions.length() > max_changes ||
    removals.length() > max_changes - additions.length() {
    return Err(TooManyChanges)
  }
  let current : Map[String, Bool] = Map([])
  let deleting : Map[String, Bool] = Map([])
  let inserting : Map[String, Bool] = Map([])
  for e in self.directory.entries {
    current[entry_identity(e)] = true
  }
  for i, e in removals {
    let key = entry_identity(e)
    if deleting.contains(key) {
      return Err(DuplicateRemoval(i + 1))
    }
    if !current.contains(key) {
      return Err(MissingRemoval(i + 1))
    }
    deleting[key] = true
  }
  for i, e in additions {
    let key = entry_identity(e)
    if inserting.contains(key) {
      return Err(DuplicateAddition(i + 1))
    }
    if current.contains(key) {
      return Err(ExistingAddition(i + 1))
    }
    inserting[key] = true
  }
  let entries = self.directory.entries.filter(e => {
    !deleting.contains(entry_identity(e))
  })
  for e in additions {
    entries.push(e)
  }
  match PostalDirectory::new(entries, source~) {
    Err(error) => Err(InvalidDirectory(error))
    Ok(directory) => DirectorySnapshot::new(directory, revision~)
  }
}

/// Stable interchange export. Constructor invariants prohibit TSV controls.

///|
pub fn PostalDirectory::to_tsv(self : PostalDirectory) -> String {
  let lines = ["country\tpostal\tarea\tcity\ttown\tcoverage"]
  for e in self.entries {
    let kind = match e.coverage {
      ExactTown => "exact"
      UnspecifiedTown => "unspecified"
      ConditionalTown => "conditional"
    }
    lines.push([e.country, e.postal, e.area, e.city, e.town, kind].join("\t"))
  }
  lines.join("\n") + "\n"
}
