// OrdoCore — JSON value model + dynamic coding keys. Powers the forward-compat
// guarantee (ARCHITECTURE §2.1 / §5.2): unknown JSON fields on a task or the store
// root survive a decode→encode round-trip untouched, so a future V2 can annotate.

import Foundation

/// A fully general JSON value used to capture and re-emit unknown fields. Keeps
/// the int/float distinction so a round-trip won't turn `5` into `5.0`. Decode
/// order: null, bool, int, double, string, array, object.
public enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unrepresentable JSON value"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

/// A `CodingKey` that accepts any string, letting a decoder enumerate every key
/// actually present in a JSON object (so unknown keys can be captured).
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
    init(_ string: String) { self.stringValue = string }
}

extension KeyedDecodingContainer where Key == AnyCodingKey {
    /// Decodes every key that is not in `known` into a `[String: JSONValue]` map.
    func decodeExtra(excluding known: Set<String>) throws -> [String: JSONValue] {
        var extra: [String: JSONValue] = [:]
        for key in allKeys where !known.contains(key.stringValue) {
            extra[key.stringValue] = try decode(JSONValue.self, forKey: key)
        }
        return extra
    }
}

extension KeyedEncodingContainer where Key == AnyCodingKey {
    /// Re-emits captured unknown fields. Known keys are expected to already be
    /// written; callers must ensure `extra` never shadows a known key.
    mutating func encodeExtra(_ extra: [String: JSONValue]) throws {
        for (k, v) in extra {
            try encode(v, forKey: AnyCodingKey(k))
        }
    }
}
