/// Diagnostic counts contain no recipient or street text.

///|
pub struct ResolutionStep {
  field : AddressField
  before : Int32
  after : Int32
}

///|
pub struct ResolutionAudit {
  revision : String
  source : String
  decision : DirectoryDecision
  steps : Array[ResolutionStep]
  completed_fields : Array[AddressField]
}

/// Decision and evidence use one immutable snapshot. The trace reports index
/// seed and each supplied hierarchy intersection, including the rejecting step.

///|
pub fn DirectorySnapshot::resolve(
  self : DirectorySnapshot,
  rule : AddressRule,
  address : Address,
) -> ResolutionAudit {
  let decision = self.directory.resolve(rule, address)
  let steps : Array[ResolutionStep] = []
  let completed_fields : Array[AddressField] = []
  let country = directory_text(address.country_code)
  let postal = address.postal_code.trim().to_owned()
  let traceable = country == rule.country_code &&
    (!postal.is_empty() || !address.locality.trim().is_empty()) &&
    (postal.is_empty() || postal_matches(rule.postal_pattern, postal)) &&
    ![
      address.country_code,
      address.postal_code,
      address.administrative_area,
      address.locality,
      address.dependent_locality,
      address.recipient,
      address.organization,
    ]
    .iter()
    .any(has_directory_control) &&
    !address.address_lines.iter().any(has_directory_control)
  if traceable {
    let country = directory_text(address.country_code)
    let by_postal = !address.postal_code.trim().is_empty()
    let mut candidates = if by_postal {
      self.directory.lookup_postal(country, address.postal_code)
    } else {
      self.directory.lookup_locality(country, address.locality)
    }
    steps.push({
      field: if by_postal {
        PostalCode
      } else {
        Locality
      },
      before: self.directory.size(),
      after: candidates.length(),
    })
    if !candidates.is_empty() {
      for field in [AdministrativeArea, Locality, DependentLocality] {
        let value = directory_text(field_value(field, address))
        if value.is_empty() {
          continue
        }
        let narrowed = candidates.filter(e => {
          match field {
            AdministrativeArea => e.area == value
            Locality => e.city == value
            _ => e.town == value || e.coverage != ExactTown
          }
        })
        steps.push({
          field,
          before: candidates.length(),
          after: narrowed.length(),
        })
        if narrowed.is_empty() {
          break
        }
        candidates = narrowed
      }
    }
  }
  if decision.status == Resolved {
    for field in [PostalCode, AdministrativeArea, Locality, DependentLocality] {
      if field_value(field, address).trim().is_empty() {
        completed_fields.push(field)
      }
    }
  }
  {
    revision: self.revision,
    source: self.directory.source,
    decision,
    steps,
    completed_fields,
  }
}

///|
pub struct AddressJob {
  id : String
  address : Address
}

///|
pub fn AddressJob::new(id : String, address : Address) -> AddressJob {
  { id, address, }
}

///|
pub(all) enum BatchError {
  InvalidLimit
  TooManyJobs
  InvalidJobId(Int32)
  DuplicateJobId(Int32)
}

///|
pub(all) enum BatchPolicy {
  KeepValid
  RequireAllResolved
}

///|
pub struct BatchRow {
  id : String
  audit : ResolutionAudit
}

///|
pub struct BatchReport {
  revision : String
  source : String
  rows : Array[BatchRow]
  resolved : Int32
  conflicted : Int32
  ambiguous : Int32
  unknown : Int32
  unverified : Int32
  invalid : Int32
  insufficient : Int32
  export_allowed : Bool
  priv labels : Map[String, Array[String]]
}

/// Returns new label arrays. An all-or-nothing batch never exports partial labels.

///|
pub fn BatchReport::labels_for(
  self : BatchReport,
  id : String,
) -> Array[String] {
  self.labels.get(id).unwrap_or([]).copy()
}

/// IDs/limits are validated for the whole batch before processing. Input order
/// and stable IDs are preserved. Every row uses the same snapshot and rule.

///|
pub fn DirectorySnapshot::resolve_batch(
  self : DirectorySnapshot,
  rule : AddressRule,
  jobs : Array[AddressJob],
  policy~ : BatchPolicy = KeepValid,
  max_jobs~ : Int32 = 10000,
) -> Result[BatchReport, BatchError] {
  if max_jobs <= 0 {
    return Err(InvalidLimit)
  }
  if jobs.length() > max_jobs {
    return Err(TooManyJobs)
  }
  let ids : Map[String, Bool] = Map([])
  for i, job in jobs {
    if job.id.trim().is_empty() || has_directory_control(job.id) {
      return Err(InvalidJobId(i + 1))
    }
    if ids.contains(job.id) {
      return Err(DuplicateJobId(i + 1))
    }
    ids[job.id] = true
  }
  let rows : Array[BatchRow] = []
  let mut resolved = 0
  let mut conflicted = 0
  let mut ambiguous = 0
  let mut unknown = 0
  let mut unverified = 0
  let mut invalid = 0
  let mut insufficient = 0
  for job in jobs {
    let audit = self.resolve(rule, job.address)
    match audit.decision.status() {
      Resolved => resolved += 1
      Conflict => conflicted += 1
      Ambiguous => ambiguous += 1
      UnknownPostal | UnknownLocality => unknown += 1
      UnverifiedTown => unverified += 1
      InvalidInput => invalid += 1
      InsufficientInput => insufficient += 1
    }
    rows.push({ id: job.id, audit, })
  }
  let export_allowed = match policy {
    KeepValid => true
    RequireAllResolved => resolved == jobs.length()
  }
  let labels : Map[String, Array[String]] = Map([])
  if export_allowed {
    for row in rows {
      if row.audit.decision.status() == Resolved {
        labels[row.id] = row.audit.decision.label_lines()
      }
    }
  }
  Ok({
    revision: self.revision,
    source: self.directory.source,
    rows,
    resolved,
    conflicted,
    ambiguous,
    unknown,
    unverified,
    invalid,
    insufficient,
    export_allowed,
    labels,
  })
}
