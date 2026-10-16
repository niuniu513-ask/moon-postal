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
}

///|
pub struct PostalPattern {
  kind : PostalPatternKind
  minimum_length : Int
  maximum_length : Int
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
  }
}

///|
pub(all) enum IssueCode {
  MissingRequiredField
  InvalidPostalCode
  CountryMismatch
}

///|
pub struct AddressIssue {
  code : IssueCode
  field : AddressField
}

///|
pub fn builtin_rule(country_code : String) -> AddressRule? {
  match ascii_uppercase(country_code) {
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
    if field_is_empty(field, address) {
      issues.push({ code: MissingRequiredField, field, })
    }
  }
  if !address.postal_code.trim().is_empty() &&
    !postal_matches(rule.postal_pattern, address.postal_code) {
    issues.push({ code: InvalidPostalCode, field: PostalCode, })
  }
  issues
}

///|
pub fn format_address(rule : AddressRule, address : Address) -> String {
  let lines : Array[String] = []
  for field in rule.field_order {
    match field {
      AddressLine =>
        for line in address.address_lines {
          push_nonempty(lines, line)
        }
      _ => push_nonempty(lines, field_value(field, address))
    }
  }
  lines.join("\n")
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
  let last_two = chars.length() - 2
  if !is_ascii_letter(chars[last_two]) || !is_ascii_letter(chars[last_two + 1]) {
    return false
  }
  let mut has_digit = false
  for index in 0..<chars.length() {
    let character = chars[index]
    if character >= '0' && character <= '9' {
      has_digit = true
    } else if !is_ascii_letter(character) {
      return false
    }
  }
  has_digit && chars[last_two - 1] >= '0' && chars[last_two - 1] <= '9'
}
