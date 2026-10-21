/// Exact directory records describe postal routing, not individual buildings.

///|
pub(all) enum TownCoverage {
  ExactTown
  UnspecifiedTown
  ConditionalTown
} derive(Eq)

///|
pub extend TownCoverage with Eq::{equal, not_equal}

///|
pub struct PostalEntry {
  country : String
  postal : String
  area : String
  city : String
  town : String
  coverage : TownCoverage
}

///|
pub fn PostalEntry::new(
  country : String,
  postal : String,
  area : String,
  city : String,
  town : String,
  coverage~ : TownCoverage = ExactTown,
) -> PostalEntry {
  {
    country: directory_text(country),
    postal: compact_postal(postal),
    area: directory_text(area),
    city: directory_text(city),
    town: directory_text(town),
    coverage,
  }
}

///|
pub struct PostalDirectory {
  priv entries : Array[PostalEntry]
  priv postal_index : Map[String, Array[Int32]]
  priv city_index : Map[String, Array[Int32]]
  priv source : String
}

/// Import is atomic. Invalid data never becomes a partially usable directory.

///|
pub(all) enum DirectoryError {
  EmptyDirectory
  InvalidRecord(Int32)
  InvalidTsvRow(Int32)
  InvalidHeader
}

///|
pub fn PostalDirectory::new(
  entries : Array[PostalEntry],
  source~ : String,
) -> Result[PostalDirectory, DirectoryError] {
  if entries.is_empty() {
    return Err(EmptyDirectory)
  }
  let clean : Array[PostalEntry] = []
  let seen : Map[String, Bool] = Map([])
  let postal_index : Map[String, Array[Int32]] = Map([])
  let city_index : Map[String, Array[Int32]] = Map([])
  for row, input in entries {
    let entry = PostalEntry::new(
      input.country,
      input.postal,
      input.area,
      input.city,
      input.town,
      coverage=input.coverage,
    )
    if entry.country.length() != 2 ||
      !entry.country.iter().all(c => c >= 'A' && c <= 'Z') ||
      entry.postal.is_empty() ||
      !all_ascii_alphanumeric(entry.postal) ||
      entry.area.is_empty() ||
      entry.city.is_empty() ||
      entry.town.is_empty() ||
      [entry.country, entry.postal, entry.area, entry.city, entry.town]
      .iter()
      .any(has_directory_control) {
      return Err(InvalidRecord(row + 1))
    }
    if builtin_rule(entry.country) is Some(rule) &&
      !postal_matches(rule.postal_pattern, input.postal) {
      return Err(InvalidRecord(row + 1))
    }
    let kind = match entry.coverage {
      ExactTown => "exact"
      UnspecifiedTown => "unspecified"
      ConditionalTown => "conditional"
    }
    let identity = [
      entry.country,
      entry.postal,
      entry.area,
      entry.city,
      entry.town,
      kind,
    ].join("\u{001f}")
    if seen.contains(identity) {
      continue
    }
    seen[identity] = true
    let id = clean.length()
    clean.push(entry)
    directory_index_push(
      postal_index,
      directory_key(entry.country, entry.postal),
      id,
    )
    directory_index_push(
      city_index,
      directory_key(entry.country, entry.city),
      id,
    )
  }
  Ok({ entries: clean, postal_index, city_index, source, })
}

///|
fn directory_index_push(
  index : Map[String, Array[Int32]],
  key : String,
  id : Int32,
) -> Unit {
  match index.get(key) {
    Some(ids) => ids.push(id)
    None => index[key] = [id]
  }
}

///|
fn directory_key(country : String, value : String) -> String {
  country + "\u{001f}" + value
}

/// Conservatively normalizes ASCII case and surrounding whitespace only.

///|
fn directory_text(value : String) -> String {
  ascii_uppercase(value.trim().to_owned())
}

///|
fn has_directory_control(value : String) -> Bool {
  value.iter().any(c => c.to_int() < 32 || c.to_int() == 127)
}

///|
pub fn PostalDirectory::size(self : PostalDirectory) -> Int32 {
  self.entries.length()
}

///|
pub fn PostalDirectory::source(self : PostalDirectory) -> String {
  self.source
}

/// Returns a new array; callers cannot mutate the directory's indexes.

///|
pub fn PostalDirectory::lookup_postal(
  self : PostalDirectory,
  country : String,
  postal : String,
) -> Array[PostalEntry] {
  let ids = self.postal_index
    .get(directory_key(directory_text(country), compact_postal(postal)))
    .unwrap_or([])
  ids.map(id => self.entries[id])
}

/// Reverse search uses the whole city name, optionally narrowed by area/town.

///|
pub fn PostalDirectory::lookup_locality(
  self : PostalDirectory,
  country : String,
  city : String,
  area~ : String = "",
  town~ : String = "",
) -> Array[PostalEntry] {
  let ids = self.city_index
    .get(directory_key(directory_text(country), directory_text(city)))
    .unwrap_or([])
  let area = directory_text(area)
  let town = directory_text(town)
  ids.filter_map(id => {
    let entry = self.entries[id]
    if (area.is_empty() || entry.area == area) &&
      (town.is_empty() || entry.town == town) {
      Some(entry)
    } else {
      None
    }
  })
}

///|
pub(all) enum ResolutionStatus {
  Resolved
  Ambiguous
  Conflict
  UnknownPostal
  UnknownLocality
  InvalidInput
  InsufficientInput
  UnverifiedTown
} derive(Eq)

///|
pub extend ResolutionStatus with Eq::{equal, not_equal}

///|
pub struct DirectoryDecision {
  priv status : ResolutionStatus
  priv candidates : Array[PostalEntry]
  priv conflict_field : AddressField?
  priv canonical : Address?
  priv label_lines : Array[String]
  priv issues : Array[AddressIssue]
}

///|
pub fn DirectoryDecision::status(self : DirectoryDecision) -> ResolutionStatus {
  self.status
}

///|
pub fn DirectoryDecision::candidates(
  self : DirectoryDecision,
) -> Array[PostalEntry] {
  self.candidates.copy()
}

///|
pub fn DirectoryDecision::conflict_field(
  self : DirectoryDecision,
) -> AddressField? {
  self.conflict_field
}

///|
pub fn DirectoryDecision::canonical(self : DirectoryDecision) -> Address? {
  self.canonical
}

///|
pub fn DirectoryDecision::label_lines(
  self : DirectoryDecision,
) -> Array[String] {
  self.label_lines.copy()
}

///|
pub fn DirectoryDecision::issues(
  self : DirectoryDecision,
) -> Array[AddressIssue] {
  self.issues.copy()
}

///|
fn unresolved(
  status : ResolutionStatus,
  candidates : Array[PostalEntry],
  field? : AddressField,
) -> DirectoryDecision {
  {
    status,
    candidates,
    conflict_field: field,
    canonical: None,
    label_lines: [],
    issues: [],
  }
}

/// Intersect postal candidates with each supplied hierarchy level. Never guess
/// the first match or silently replace a supplied conflicting field.

///|
pub fn PostalDirectory::resolve(
  self : PostalDirectory,
  rule : AddressRule,
  address : Address,
) -> DirectoryDecision {
  let country = directory_text(address.country_code)
  if country.is_empty() {
    return unresolved(InsufficientInput, [])
  }
  if country != rule.country_code {
    return unresolved(InvalidInput, [], field=Country)
  }
  if [
      address.country_code,
      address.postal_code,
      address.administrative_area,
      address.locality,
      address.dependent_locality,
      address.recipient,
      address.organization,
    ]
    .iter()
    .any(has_directory_control) ||
    address.address_lines.iter().any(has_directory_control) {
    return unresolved(InvalidInput, [])
  }
  let postal = address.postal_code.trim().to_owned()
  let city = directory_text(address.locality)
  if !postal.is_empty() && !postal_matches(rule.postal_pattern, postal) {
    return unresolved(InvalidInput, [], field=PostalCode)
  }
  if postal.is_empty() && city.is_empty() {
    return unresolved(InsufficientInput, [])
  }
  let mut candidates = if postal.is_empty() {
    self.lookup_locality(country, city)
  } else {
    self.lookup_postal(country, postal)
  }
  if candidates.is_empty() {
    return unresolved(
      if postal.is_empty() {
        UnknownLocality
      } else {
        UnknownPostal
      },
      [],
    )
  }
  for field in [AdministrativeArea, Locality, DependentLocality] {
    let value = directory_text(field_value(field, address))
    if value.is_empty() {
      continue
    }
    let narrowed = candidates.filter(entry => {
      match field {
        AdministrativeArea => entry.area == value
        Locality => entry.city == value
        // An unspecified/conditional row cannot prove or disprove the town.
        _ => entry.town == value || entry.coverage != ExactTown
      }
    })
    if narrowed.is_empty() {
      return unresolved(Conflict, candidates, field~)
    }
    candidates = narrowed
  }
  // A fallback/conditional row remaining alongside an exact row is also unsafe.
  if candidates.iter().any(e => e.coverage != ExactTown) {
    return unresolved(UnverifiedTown, candidates)
  }
  if candidates.length() != 1 {
    return unresolved(Ambiguous, candidates)
  }
  let entry = candidates[0]
  let canonical = {
    ..address,
    country_code: entry.country,
    postal_code: entry.postal,
    administrative_area: entry.area,
    locality: entry.city,
    dependent_locality: entry.town,
  }
  if !rule.field_order.contains(DependentLocality) {
    return {
      status: InvalidInput,
      candidates,
      conflict_field: Some(DependentLocality),
      canonical: None,
      label_lines: [],
      issues: [{ code: RequiredFieldNotRendered, field: DependentLocality, }],
    }
  }
  let checked = assess(rule, canonical)
  if !checked.issues.is_empty() {
    return {
      status: InvalidInput,
      candidates,
      conflict_field: None,
      canonical: None,
      label_lines: [],
      issues: checked.issues,
    }
  }
  {
    status: Resolved,
    candidates,
    conflict_field: None,
    canonical: Some(canonical),
    label_lines: checked.label_lines,
    issues: [],
  }
}

/// Stable interchange: country, postal, area, city, town, coverage (TSV).
/// No quoting: embedded control characters are rejected, not stripped.

///|
pub fn PostalDirectory::from_tsv(
  text : String,
  source~ : String,
) -> Result[PostalDirectory, DirectoryError] {
  let lines = text.split("\n").to_array()
  if lines.is_empty() ||
    lines[0].trim_end(chars="\r").to_owned() !=
    "country\tpostal\tarea\tcity\ttown\tcoverage" {
    return Err(InvalidHeader)
  }
  let entries : Array[PostalEntry] = []
  for i in 1..<lines.length() {
    let line = lines[i].trim_end(chars="\r").to_owned()
    if i == lines.length() - 1 && line.is_empty() {
      continue
    }
    let fields = line.split("\t").map(s => s.to_owned()).to_array()
    if fields.length() != 6 {
      return Err(InvalidTsvRow(i + 1))
    }
    if fields.iter().any(has_directory_control) ||
      fields[1] != compact_postal(fields[1]) {
      return Err(InvalidTsvRow(i + 1))
    }
    let coverage = match fields[5] {
      "exact" => ExactTown
      "unspecified" => UnspecifiedTown
      "conditional" => ConditionalTown
      _ => return Err(InvalidTsvRow(i + 1))
    }
    entries.push(
      PostalEntry::new(
        fields[0],
        fields[1],
        fields[2],
        fields[3],
        fields[4],
        coverage~,
      ),
    )
  }
  PostalDirectory::new(entries, source~)
}
