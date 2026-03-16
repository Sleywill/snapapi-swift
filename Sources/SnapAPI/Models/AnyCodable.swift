import Foundation

// MARK: - AnyCodable

/// A type-erased wrapper that can encode/decode any JSON-compatible value.
///
/// Use this when you need to pass arbitrary JSON objects, such as a JSON Schema,
/// to the API without knowing the structure at compile time.
///
/// ```swift
/// let schema: AnyCodable = [
///     "type": "object",
///     "properties": [
///         "name": ["type": "string"],
///         "age":  ["type": "integer"]
///     ]
/// ]
/// ```
@dynamicMemberLookup
public struct AnyCodable: Codable, Sendable, Equatable {

    // MARK: - Storage

    public let value: AnyJSON

    // MARK: - Init

    public init(_ value: AnyJSON) {
        self.value = value
    }

    // MARK: - Convenience initialisers

    public init(_ bool: Bool)   { value = .bool(bool) }
    public init(_ int: Int)     { value = .int(int) }
    public init(_ double: Double) { value = .double(double) }
    public init(_ string: String) { value = .string(string) }
    public init(_ array: [AnyCodable]) { value = .array(array.map(\.value)) }
    public init(_ dict: [String: AnyCodable]) {
        value = .object(dict.mapValues(\.value))
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        value = try AnyJSON(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }

    // MARK: - Dynamic member lookup (object subscript)

    public subscript(dynamicMember key: String) -> AnyCodable? {
        guard case .object(let d) = value, let v = d[key] else { return nil }
        return AnyCodable(v)
    }
}

// MARK: - Literal conformances

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self.init(value) }
}
extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self.init(value) }
}
extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self.init(value) }
}
extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self.init(value) }
}
extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: AnyCodable...) { self.init(elements) }
}
extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, AnyCodable)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}
extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { value = .null }
}

// MARK: - AnyJSON (the actual storage enum)

/// Underlying JSON value storage used by ``AnyCodable``.
public indirect enum AnyJSON: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyJSON])
    case object([String: AnyJSON])

    // MARK: Decodable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil()               { self = .null; return }
        if let b = try? container.decode(Bool.self)   { self = .bool(b);   return }
        if let i = try? container.decode(Int.self)    { self = .int(i);    return }
        if let d = try? container.decode(Double.self) { self = .double(d); return }
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let a = try? container.decode([AnyJSON].self) { self = .array(a); return }
        if let o = try? container.decode([String: AnyJSON].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported JSON value type"
        )
    }

    // MARK: Encodable

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:          try container.encodeNil()
        case .bool(let b):   try container.encode(b)
        case .int(let i):    try container.encode(i)
        case .double(let d): try container.encode(d)
        case .string(let s): try container.encode(s)
        case .array(let a):  try container.encode(a)
        case .object(let o): try container.encode(o)
        }
    }
}
