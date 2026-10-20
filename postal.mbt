///|
pub(all) enum AddressField {
  Recipient
  Organization
  AddressLine
  DependentLocality
  Locality
  AdministrativeArea
  PostalCode
  Country
} derive(Eq)

///|
pub extend AddressField with Eq::{equal, not_equal}

///|
pub struct PostalPattern {
  kind : PostalPatternKind
  minimum_length : Int
  maximum_length : Int
}

/// A caller-provided postal prefix for one administrative area.

///|
pub struct AreaPostalPrefix {
  area : String
  prefix : String
}

///|
pub fn AreaPostalPrefix::new(
  area : String,
  prefix : String,
) -> AreaPostalPrefix {
  {
    area: ascii_uppercase(area.trim().to_owned()),
    prefix: compact_postal(prefix),
  }
}

///|
pub(all) enum PostalPatternKind {
  NoCheck
  Digits
  DigitsRange
  AlphanumericRange
  UsZip
  CanadaPostal
  UkPostcode
  JapanPostal
  ChinaPostal
}

///|
pub fn PostalPattern::no_check() -> PostalPattern {
  { kind: NoCheck, minimum_length: 0, maximum_length: 0, }
}

///|
pub fn PostalPattern::digits(length : Int) -> PostalPattern {
  { kind: Digits, minimum_length: length, maximum_length: length, }
}

///|
pub fn PostalPattern::digits_in_range(
  minimum : Int,
  maximum : Int,
) -> PostalPattern {
  { kind: DigitsRange, minimum_length: minimum, maximum_length: maximum, }
}

///|
pub fn PostalPattern::alphanumeric_in_range(
  minimum : Int,
  maximum : Int,
) -> PostalPattern {
  { kind: AlphanumericRange, minimum_length: minimum, maximum_length: maximum, }
}

///|
fn builtin_postal_pattern(kind : PostalPatternKind) -> PostalPattern {
  { kind, minimum_length: 0, maximum_length: 0, }
}

///|
pub struct Address {
  recipient : String
  organization : String
  address_lines : Array[String]
  dependent_locality : String
  locality : String
  administrative_area : String
  postal_code : String
  country_code : String
}

///|
pub fn Address::new(
  recipient? : String = "",
  organization? : String = "",
  address_lines? : Array[String] = [],
  dependent_locality? : String = "",
  locality? : String = "",
  administrative_area? : String = "",
  postal_code? : String = "",
  country_code? : String = "",
) -> Address {
  {
    recipient,
    organization,
    address_lines,
    dependent_locality,
    locality,
    administrative_area,
    postal_code,
    country_code,
  }
}

///|
pub struct AddressRule {
  country_code : String
  required_fields : Array[AddressField]
  postal_pattern : PostalPattern
  field_order : Array[AddressField]
  combine_region_postal : Bool
  area_postal_prefixes : Array[AreaPostalPrefix]
}

///|
pub fn AddressRule::new(
  country_code : String,
  required_fields : Array[AddressField],
  postal_pattern : PostalPattern,
  field_order : Array[AddressField],
) -> AddressRule {
  {
    country_code: ascii_uppercase(country_code.trim().to_owned()),
    required_fields,
    postal_pattern,
    field_order,
    combine_region_postal: false,
    area_postal_prefixes: [],
  }
}

/// Configures a partial relationship table. Unlisted areas are rejected.

///|
pub fn AddressRule::with_area_postal_prefixes(
  self : AddressRule,
  relationships : Array[AreaPostalPrefix],
) -> AddressRule {
  if relationships.is_empty() {
    return { ..self, area_postal_prefixes: [], }
  }
  let required_fields : Array[AddressField] = []
  for field in self.required_fields {
    required_fields.push(field)
  }
  for field in [Country, AdministrativeArea, PostalCode] {
    if !required_fields.contains(field) {
      required_fields.push(field)
    }
  }
  { ..self, required_fields, area_postal_prefixes: relationships, }
}

///|
pub(all) enum IssueCode {
  MissingRequiredField
  InvalidPostalCode
  CountryMismatch
  AdministrativeAreaPostalMismatch
  UnknownAdministrativeArea
  RequiredFieldNotRendered
}

///|
pub(all) enum RelationshipStatus {
  NotConfigured
  Skipped
  UnknownArea
  Matched
  Mismatched
}

///|
pub struct AddressIssue {
  code : IssueCode
  field : AddressField
}

///|
pub struct AddressDecision {
  issues : Array[AddressIssue]
  label_lines : Array[String]
  relationship_status : RelationshipStatus
}

///|
pub fn AddressDecision::issues(self : AddressDecision) -> Array[AddressIssue] {
  self.issues
}

///|
pub fn AddressDecision::label_lines(self : AddressDecision) -> Array[String] {
  self.label_lines
}

///|
pub fn AddressDecision::relationship_status(
  self : AddressDecision,
) -> RelationshipStatus {
  self.relationship_status
}

///|
pub fn assess(rule : AddressRule, address : Address) -> AddressDecision {
  let issues = validate(rule, address)
  let relationship_status = area_postal_status(rule, address)
  let label_lines = if issues.is_empty() {
    format_address_lines(rule, address)
  } else {
    []
  }
  { issues, label_lines, relationship_status, }
}

///|
pub fn AddressIssue::message(self : AddressIssue) -> String {
  let field = match self.field {
    Recipient => "recipient"
    Organization => "organization"
    AddressLine => "address line"
    DependentLocality => "dependent locality"
    Locality => "locality"
    AdministrativeArea => "administrative area"
    PostalCode => "postal code"
    Country => "country code"
  }
  match self.code {
    MissingRequiredField => field + " is required"
    InvalidPostalCode => "postal code has an invalid format"
    CountryMismatch => "country code does not match the selected rule"
    AdministrativeAreaPostalMismatch =>
      "administrative area and postal code do not match"
    UnknownAdministrativeArea =>
      "administrative area is not covered by the selected relationship rule"
    RequiredFieldNotRendered =>
      field + " is required but absent from label order"
  }
}

///|
pub fn builtin_rule(country_code : String) -> AddressRule? {
  match ascii_uppercase(country_code.trim().to_owned()) {
    "US" =>
      Some({
        country_code: "US",
        required_fields: [
          AddressLine,
          Locality,
          AdministrativeArea,
          PostalCode,
          Country,
        ],
        postal_pattern: builtin_postal_pattern(UsZip),
        combine_region_postal: true,
        area_postal_prefixes: [],
        field_order: [
          Recipient,
          Organization,
          AddressLine,
          Locality,
          AdministrativeArea,
          PostalCode,
          Country,
        ],
      })
    "CA" =>
      Some({
        country_code: "CA",
        required_fields: [
          AddressLine,
          Locality,
          AdministrativeArea,
          PostalCode,
          Country,
        ],
        postal_pattern: builtin_postal_pattern(CanadaPostal),
        combine_region_postal: true,
        area_postal_prefixes: [],
        field_order: [
          Recipient,
          Organization,
          AddressLine,
          Locality,
          AdministrativeArea,
          PostalCode,
          Country,
        ],
      })
    "GB" =>
      Some({
        country_code: "GB",
        required_fields: [AddressLine, Locality, PostalCode, Country],
        postal_pattern: builtin_postal_pattern(UkPostcode),
        combine_region_postal: false,
        area_postal_prefixes: [],
        field_order: [
          Recipient,
          Organization,
          AddressLine,
          DependentLocality,
          Locality,
          AdministrativeArea,
          PostalCode,
          Country,
        ],
      })
    "JP" =>
      Some({
        country_code: "JP",
        required_fields: [AddressLine, Locality, PostalCode, Country],
        postal_pattern: builtin_postal_pattern(JapanPostal),
        combine_region_postal: false,
        area_postal_prefixes: [],
        field_order: [
          PostalCode,
          AdministrativeArea,
          Locality,
          DependentLocality,
          AddressLine,
          Organization,
          Recipient,
          Country,
        ],
      })
    "CN" =>
      Some({
        country_code: "CN",
        required_fields: [
          AddressLine,
          Locality,
          AdministrativeArea,
          PostalCode,
          Country,
        ],
        postal_pattern: builtin_postal_pattern(ChinaPostal),
        combine_region_postal: false,
        area_postal_prefixes: [],
        field_order: [
          Country,
          AdministrativeArea,
          Locality,
          DependentLocality,
          AddressLine,
          Organization,
          Recipient,
          PostalCode,
        ],
      })
    "AU" =>
      Some({
        country_code: "AU",
        required_fields: [
          AddressLine,
          Locality,
          AdministrativeArea,
          PostalCode,
          Country,
        ],
        postal_pattern: PostalPattern::digits(4),
        combine_region_postal: true,
        area_postal_prefixes: [],
        field_order: [
          Recipient,
          Organization,
          AddressLine,
          Locality,
          AdministrativeArea,
          PostalCode,
          Country,
        ],
      })
    "AE" =>
      Some({
        country_code: "AE",
        required_fields: [AddressLine, Locality, AdministrativeArea, Country],
        postal_pattern: PostalPattern::no_check(),
        combine_region_postal: false,
        area_postal_prefixes: [],
        field_order: [
          Recipient,
          Organization,
          AddressLine,
          Locality,
          AdministrativeArea,
          Country,
        ],
      })
    _ => None
  }
}

///|
pub fn validate(rule : AddressRule, address : Address) -> Array[AddressIssue] {
  let issues : Array[AddressIssue] = []
  if !address.country_code.trim().is_empty() &&
    ascii_uppercase(address.country_code.trim().to_owned()) != rule.country_code {
    issues.push({ code: CountryMismatch, field: Country, })
  }
  for field in rule.required_fields {
    if !rule.field_order.contains(field) {
      issues.push({ code: RequiredFieldNotRendered, field, })
    }
    if field_is_empty(field, address) {
      issues.push({ code: MissingRequiredField, field, })
    }
  }
  let postal_valid = address.postal_code.trim().is_empty() ||
    postal_matches(rule.postal_pattern, address.postal_code)
  if !postal_valid {
    issues.push({ code: InvalidPostalCode, field: PostalCode, })
  }
  if postal_valid {
    match area_postal_status(rule, address) {
      Mismatched =>
        issues.push({
          code: AdministrativeAreaPostalMismatch,
          field: AdministrativeArea,
        })
      UnknownArea =>
        issues.push({
          code: UnknownAdministrativeArea,
          field: AdministrativeArea,
        })
      _ => ()
    }
  }
  issues
}

///|
fn area_postal_status(
  rule : AddressRule,
  address : Address,
) -> RelationshipStatus {
  if rule.area_postal_prefixes.is_empty() {
    return NotConfigured
  }
  if address.country_code.trim().is_empty() ||
    ascii_uppercase(address.country_code.trim().to_owned()) != rule.country_code ||
    address.administrative_area.trim().is_empty() ||
    address.postal_code.trim().is_empty() ||
    !postal_matches(rule.postal_pattern, address.postal_code) {
    return Skipped
  }
  let area = ascii_uppercase(address.administrative_area.trim().to_owned())
  let postal = compact_postal(address.postal_code)
  let mut area_seen = false
  for relationship in rule.area_postal_prefixes {
    if relationship.area == area {
      area_seen = true
      if !relationship.prefix.is_empty() &&
        postal.has_prefix(relationship.prefix) {
        return Matched
      }
    }
  }
  if area_seen {
    Mismatched
  } else {
    UnknownArea
  }
}

///|
pub fn format_address(rule : AddressRule, address : Address) -> String {
  format_address_lines(rule, address).join("\n")
}

///|
pub fn format_if_valid(rule : AddressRule, address : Address) -> String? {
  let decision = assess(rule, address)
  if decision.issues.is_empty() {
    Some(decision.label_lines.join("\n"))
  } else {
    None
  }
}

///|
pub fn format_address_lines(
  rule : AddressRule,
  address : Address,
) -> Array[String] {
  let lines : Array[String] = []
  for field in rule.field_order {
    match field {
      AddressLine =>
        for line in address.address_lines {
          push_nonempty(lines, line)
        }
      Locality if rule.combine_region_postal =>
        push_nonempty(lines, locality_region_postal_line(address))
      AdministrativeArea | PostalCode if rule.combine_region_postal => ()
      _ => push_nonempty(lines, field_value(field, address))
    }
  }
  lines
}

///|
fn locality_region_postal_line(address : Address) -> String {
  let suffix : Array[String] = []
  push_nonempty(suffix, address.administrative_area)
  push_nonempty(suffix, address.postal_code)
  let locality = address.locality.trim().to_owned()
  let tail = suffix.join(" ")
  if locality.is_empty() {
    tail
  } else if tail.is_empty() {
    locality
  } else {
    locality + ", " + tail
  }
}

///|
fn field_is_empty(field : AddressField, address : Address) -> Bool {
  match field {
    AddressLine => address_lines_are_empty(address.address_lines)
    Country => address.country_code.trim().is_empty()
    _ => field_value(field, address).trim().is_empty()
  }
}

///|
fn address_lines_are_empty(lines : Array[String]) -> Bool {
  for line in lines {
    if !line.trim().is_empty() {
      return false
    }
  }
  true
}

///|
fn field_value(field : AddressField, address : Address) -> String {
  match field {
    Recipient => address.recipient
    Organization => address.organization
    DependentLocality => address.dependent_locality
    Locality => address.locality
    AdministrativeArea => address.administrative_area
    PostalCode => address.postal_code
    Country => address.country_code
    AddressLine => ""
  }
}

///|
fn push_nonempty(lines : Array[String], value : String) -> Unit {
  let trimmed = value.trim()
  if !trimmed.is_empty() {
    lines.push(trimmed.to_owned())
  }
}

///|
fn postal_matches(pattern : PostalPattern, input : String) -> Bool {
  let code = input.trim().to_owned()
  match pattern.kind {
    NoCheck => true
    Digits => code.length() == pattern.minimum_length && all_ascii_digits(code)
    DigitsRange =>
      code.length() >= pattern.minimum_length &&
      code.length() <= pattern.maximum_length &&
      all_ascii_digits(code)
    AlphanumericRange =>
      code.length() >= pattern.minimum_length &&
      code.length() <= pattern.maximum_length &&
      all_ascii_alphanumeric(code)
    UsZip => us_zip_matches(input)
    CanadaPostal => canada_postal_matches(input)
    UkPostcode => uk_postcode_matches(input)
    JapanPostal => japan_postal_matches(input)
    ChinaPostal =>
      input.trim().length() == 6 && all_ascii_digits(input.trim().to_owned())
  }
}

///|
fn us_zip_matches(input : String) -> Bool {
  let chars = input.trim().iter().to_array()
  if chars.length() == 5 {
    return all_ascii_digits(input.trim().to_owned())
  }
  if chars.length() != 10 || chars[5] != '-' {
    return false
  }
  for index in 0..<10 {
    if index != 5 && (chars[index] < '0' || chars[index] > '9') {
      return false
    }
  }
  true
}

///|
fn japan_postal_matches(input : String) -> Bool {
  let chars = input.trim().iter().to_array()
  if chars.length() == 7 {
    return all_ascii_digits(input.trim().to_owned())
  }
  if chars.length() != 8 || chars[3] != '-' {
    return false
  }
  for index in 0..<8 {
    if index != 3 && (chars[index] < '0' || chars[index] > '9') {
      return false
    }
  }
  true
}

///|
fn compact_postal(input : String) -> String {
  let result = StringBuilder()
  for character in input.trim().iter() {
    if character != ' ' && character != '-' {
      result.write_char(character.to_ascii_uppercase())
    }
  }
  result.to_string()
}

///|
fn ascii_uppercase(input : String) -> String {
  let result = StringBuilder()
  for character in input.iter() {
    result.write_char(character.to_ascii_uppercase())
  }
  result.to_string()
}

///|
fn all_ascii_digits(input : String) -> Bool {
  if input.is_empty() {
    return false
  }
  for character in input.iter() {
    if character < '0' || character > '9' {
      return false
    }
  }
  true
}

///|
fn all_ascii_alphanumeric(input : String) -> Bool {
  if input.is_empty() {
    return false
  }
  for character in input.iter() {
    if (character < '0' || character > '9') && !is_ascii_letter(character) {
      return false
    }
  }
  true
}

///|
fn is_ascii_letter(character : Char) -> Bool {
  (character >= 'A' && character <= 'Z') ||
  (character >= 'a' && character <= 'z')
}

///|
fn is_ascii_digit(character : Char) -> Bool {
  character >= '0' && character <= '9'
}

///|
fn canada_postal_matches(input : String) -> Bool {
  let trimmed = input.trim()
  let raw = trimmed.iter().to_array()
  if raw.length() == 7 && raw[3] != ' ' {
    return false
  }
  if raw.length() != 6 && raw.length() != 7 {
    return false
  }
  let chars = compact_postal(trimmed.to_owned()).iter().to_array()
  if chars.length() != 6 {
    return false
  }
  for index in 0..<6 {
    let character = chars[index]
    if index % 2 == 0 {
      if !is_ascii_letter(character) || "DFIOQU".contains(character.to_string()) {
        return false
      }
      if index == 0 && "WZ".contains(character.to_string()) {
        return false
      }
    } else if character < '0' || character > '9' {
      return false
    }
  }
  true
}

///|
fn uk_postcode_matches(input : String) -> Bool {
  let trimmed = input.trim()
  let raw = trimmed.iter().to_array()
  let compact = compact_postal(trimmed.to_owned())
  let compact_length = compact.length()
  let mut spaces = 0
  let mut space_position = -1
  for index in 0..<raw.length() {
    if raw[index] == ' ' {
      spaces += 1
      space_position = index
    } else if raw[index] == '-' {
      return false
    }
  }
  if spaces > 1 || (spaces == 1 && space_position != compact_length - 3) {
    return false
  }
  let chars = compact.iter().to_array()
  if chars.length() < 5 || chars.length() > 7 {
    return false
  }
  if compact == "GIR0AA" {
    return true
  }
  let outward_length = chars.length() - 3
  let area_length = if is_ascii_letter(chars[1]) { 2 } else { 1 }
  let district_length = outward_length - area_length
  if !is_ascii_letter(chars[0]) ||
    district_length < 1 ||
    district_length > 2 ||
    !is_ascii_digit(chars[area_length]) {
    return false
  }
  if district_length == 2 &&
    !is_ascii_digit(chars[area_length + 1]) &&
    !is_ascii_letter(chars[area_length + 1]) {
    return false
  }
  is_ascii_digit(chars[outward_length]) &&
  is_ascii_letter(chars[outward_length + 1]) &&
  is_ascii_letter(chars[outward_length + 2])
}
