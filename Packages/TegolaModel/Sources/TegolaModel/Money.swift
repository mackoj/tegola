/// An amount of money: integer minor units and an ISO 4217 currency, never a float and never without its currency
/// (PLAN §3.2, page 52). Amounts in different currencies are never added together.
public struct Money: Hashable, Sendable, Codable, CustomStringConvertible {
  /// In the currency's minor unit (cents for EUR).
  public let minorUnits: Int
  public let currency: Currency

  public init(minorUnits: Int, currency: Currency) {
    self.minorUnits = minorUnits
    self.currency = currency
  }

  public var description: String { "\(minorUnits) \(currency.code)" }

  /// The sum of `amounts` per currency, ordered by currency code. Mixing currencies gives several totals, never one.
  public static func totals(_ amounts: some Sequence<Money>) -> [Money] {
    var sums: [Currency: Int] = [:]
    for amount in amounts { sums[amount.currency, default: 0] += amount.minorUnits }
    return sums.map { Money(minorUnits: $0.value, currency: $0.key) }.sorted { $0.currency.code < $1.currency.code }
  }
}

/// An ISO 4217 code, validated as three uppercase letters.
public struct Currency: Hashable, Sendable, Codable {
  public let code: String

  public init?(_ code: String) {
    guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isUppercase }) else { return nil }
    self.code = code
  }

  public init(from decoder: any Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    guard let currency = Currency(raw) else {
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "not ISO 4217: \(raw)"))
    }
    self = currency
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(code)
  }
}
