import CoreFoundation
import Foundation

public enum JSONValue: Equatable {
    case null
    case bool(Bool)
    case number(Decimal)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(any: Any) throws {
        switch any {
        case is NSNull:
            self = .null
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                guard let decimal = Decimal(
                    string: number.stringValue,
                    locale: Locale(identifier: "en_US_POSIX")
                ) else {
                    throw JSONValueError.invalidNumber(number.stringValue)
                }
                self = .number(decimal)
            }
        case let string as String:
            self = .string(string)
        case let array as [Any]:
            self = .array(try array.map(JSONValue.init(any:)))
        case let object as [String: Any]:
            self = .object(try object.mapValues(JSONValue.init(any:)))
        default:
            throw JSONValueError.unsupportedType(String(describing: type(of: any)))
        }
    }

    public var foundationValue: Any {
        switch self {
        case .null:
            return NSNull()
        case let .bool(value):
            return value
        case let .number(value):
            return NSDecimalNumber(decimal: value)
        case let .string(value):
            return value
        case let .array(values):
            return values.map(\.foundationValue)
        case let .object(values):
            return values.mapValues(\.foundationValue)
        }
    }

    public var typeName: String {
        switch self {
        case .null: return "null"
        case .bool: return "boolean"
        case .number: return "number"
        case .string: return "string"
        case .array: return "array"
        case .object: return "object"
        }
    }

    public var scalarDescription: String {
        switch self {
        case .null:
            return "null"
        case let .bool(value):
            return value ? "true" : "false"
        case let .number(value):
            return NSDecimalNumber(decimal: value).stringValue
        case let .string(value):
            return value
        case let .array(values):
            return "[\(values.count) items]"
        case let .object(values):
            return "{\(values.count) fields}"
        }
    }

    public func prettyPrinted() -> String {
        guard let data = try? JSONSerialization.data(
                withJSONObject: foundationValue,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
              ),
              let string = String(data: data, encoding: .utf8) else {
            return scalarDescription
        }
        return string
    }

    public func canonicalString() -> String {
        switch self {
        case .null:
            return "null"
        case let .bool(value):
            return value ? "true" : "false"
        case let .number(value):
            return "n:\(NSDecimalNumber(decimal: value).stringValue)"
        case let .string(value):
            return "s:\(value)"
        case let .array(values):
            return "[\(values.map { $0.canonicalString() }.joined(separator: ","))]"
        case let .object(values):
            let fields = values.keys.sorted().map { key in
                key + ":" + values[key, default: .null].canonicalString()
            }
            return "{" + fields.joined(separator: ",") + "}"
        }
    }

    public func value(forDottedKey key: String) -> JSONValue? {
        var current = self
        for component in key.split(separator: ".").map(String.init) {
            guard case let .object(object) = current,
                  let next = object[component] else {
                return nil
            }
            current = next
        }
        return current
    }
}

public enum JSONValueError: LocalizedError {
    case unsupportedType(String)
    case invalidNumber(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedType(type):
            return "Unsupported JSON value type: \(type)"
        case let .invalidNumber(value):
            return "Invalid JSON number: \(value)"
        }
    }
}
