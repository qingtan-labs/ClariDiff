import Foundation

public struct SemanticDiffEngine {
    public let options: DiffOptions

    private let isoFormatter: ISO8601DateFormatter
    private let fractionalISOFormatter: ISO8601DateFormatter

    public init(options: DiffOptions = .init()) {
        self.options = options
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        isoFormatter = formatter

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fractionalISOFormatter = fractional
    }

    public func compare(_ left: JSONValue, _ right: JSONValue) throws -> DiffNode {
        try compareNode(left, right, path: "", name: "$")
    }

    private func compareNode(
        _ left: JSONValue,
        _ right: JSONValue,
        path: String,
        name: String? = nil
    ) throws -> DiffNode {
        if isIgnored(path) {
            return DiffNode(
                path: path,
                name: name,
                status: .unchanged,
                leftValue: left,
                rightValue: right,
                isIgnored: true
            )
        }

        switch (left, right) {
        case let (.object(leftObject), .object(rightObject)):
            return try compareObjects(leftObject, rightObject, path: path, name: name)
        case let (.array(leftArray), .array(rightArray)):
            return try compareArrays(leftArray, rightArray, path: path, name: name)
        default:
            if areEquivalent(left, right) {
                return DiffNode(
                    path: path,
                    name: name,
                    status: .unchanged,
                    leftValue: left,
                    rightValue: right
                )
            }
            return DiffNode(
                path: path,
                name: name,
                status: sameJSONType(left, right) ? .modified : .typeChanged,
                leftValue: left,
                rightValue: right
            )
        }
    }

    private func compareObjects(
        _ left: [String: JSONValue],
        _ right: [String: JSONValue],
        path: String,
        name: String?
    ) throws -> DiffNode {
        let keys = Set(left.keys).union(right.keys).sorted()
        let children = try keys.map { key -> DiffNode in
            let childPath = JSONPointer.appending(key, to: path)
            if isIgnored(childPath) {
                return DiffNode(
                    path: childPath,
                    name: key,
                    status: .unchanged,
                    leftValue: left[key],
                    rightValue: right[key],
                    isIgnored: true
                )
            }
            switch (left[key], right[key]) {
            case let (.some(leftValue), .some(rightValue)):
                return try compareNode(leftValue, rightValue, path: childPath, name: key)
            case let (.some(leftValue), .none):
                return DiffNode(
                    path: childPath,
                    name: key,
                    status: .removed,
                    leftValue: leftValue,
                    rightValue: nil
                )
            case let (.none, .some(rightValue)):
                return DiffNode(
                    path: childPath,
                    name: key,
                    status: .added,
                    leftValue: nil,
                    rightValue: rightValue
                )
            case (.none, .none):
                preconditionFailure("Union key must exist on at least one side")
            }
        }
        return DiffNode(
            path: path,
            name: name,
            status: children.allSatisfy { $0.status == .unchanged } ? .unchanged : .modified,
            leftValue: .object(left),
            rightValue: .object(right),
            children: children
        )
    }

    private func compareArrays(
        _ left: [JSONValue],
        _ right: [JSONValue],
        path: String,
        name: String?
    ) throws -> DiffNode {
        let children: [DiffNode]
        switch arrayMode(for: path) {
        case .positional:
            children = try comparePositionally(left, right, path: path)
        case .unordered:
            children = try compareUnordered(left, right, path: path)
        case let .keyed(key):
            guard let keyedChildren = try compareKeyed(left, right, path: path, key: key) else {
                throw SemanticDiffError.invalidArrayKey(path: path, key: key)
            }
            children = keyedChildren
        }
        return DiffNode(
            path: path,
            name: name,
            status: children.allSatisfy { $0.status == .unchanged } ? .unchanged : .modified,
            leftValue: .array(left),
            rightValue: .array(right),
            children: children
        )
    }

    private func comparePositionally(
        _ left: [JSONValue],
        _ right: [JSONValue],
        path: String
    ) throws -> [DiffNode] {
        try (0..<max(left.count, right.count)).map { index in
            let childPath = JSONPointer.appending(String(index), to: path)
            if isIgnored(childPath) {
                return DiffNode(
                    path: childPath,
                    name: "[\(index)]",
                    status: .unchanged,
                    leftValue: left.indices.contains(index) ? left[index] : nil,
                    rightValue: right.indices.contains(index) ? right[index] : nil,
                    isIgnored: true
                )
            }
            switch (left.indices.contains(index), right.indices.contains(index)) {
            case (true, true):
                return try compareNode(left[index], right[index], path: childPath, name: "[\(index)]")
            case (true, false):
                return DiffNode(
                    path: childPath,
                    name: "[\(index)]",
                    status: .removed,
                    leftValue: left[index],
                    rightValue: nil
                )
            case (false, true):
                return DiffNode(
                    path: childPath,
                    name: "[\(index)]",
                    status: .added,
                    leftValue: nil,
                    rightValue: right[index]
                )
            case (false, false):
                preconditionFailure("Index must exist on at least one side")
            }
        }
    }

    private func compareKeyed(
        _ left: [JSONValue],
        _ right: [JSONValue],
        path: String,
        key: String
    ) throws -> [DiffNode]? {
        guard let leftIndex = keyedIndex(left, key: key),
              let rightIndex = keyedIndex(right, key: key) else {
            return nil
        }

        let identities = Set(leftIndex.keys).union(rightIndex.keys).sorted()
        return try identities.map { identity in
            let leftEntry = leftIndex[identity]
            let rightEntry = rightIndex[identity]
            guard let referenceEntry = leftEntry ?? rightEntry else {
                preconditionFailure("Identity must exist on at least one side")
            }
            let index = referenceEntry.offset
            let childPath = JSONPointer.appending(String(index), to: path)
            let label = "[\(key)=\(referenceEntry.keyDisplay)]"

            if isIgnored(childPath) {
                return DiffNode(
                    path: childPath,
                    name: label,
                    status: .unchanged,
                    leftValue: leftEntry?.value,
                    rightValue: rightEntry?.value,
                    isIgnored: true
                )
            }

            switch (leftEntry, rightEntry) {
            case let (.some(leftEntry), .some(rightEntry)):
                return try compareNode(
                    leftEntry.value,
                    rightEntry.value,
                    path: childPath,
                    name: label
                )
            case let (.some(leftEntry), .none):
                return DiffNode(
                    path: childPath,
                    name: label,
                    status: .removed,
                    leftValue: leftEntry.value,
                    rightValue: nil
                )
            case let (.none, .some(rightEntry)):
                return DiffNode(
                    path: childPath,
                    name: label,
                    status: .added,
                    leftValue: nil,
                    rightValue: rightEntry.value
                )
            case (.none, .none):
                preconditionFailure("Identity must exist on at least one side")
            }
        }
    }

    private typealias KeyedEntry = (offset: Int, value: JSONValue, keyDisplay: String)

    private func keyedIndex(_ values: [JSONValue], key: String) -> [String: KeyedEntry]? {
        var result: [String: KeyedEntry] = [:]
        for (offset, value) in values.enumerated() {
            guard let keyValue = value.value(forDottedKey: key) else { return nil }
            let identity = keyValue.canonicalString()
            guard result[identity] == nil else { return nil }
            result[identity] = (offset, value, keyValue.scalarDescription)
        }
        return result
    }

    private func compareUnordered(
        _ left: [JSONValue],
        _ right: [JSONValue],
        path: String
    ) throws -> [DiffNode] {
        var remainingRight = Set(right.indices)
        var children: [DiffNode] = []

        for (leftIndex, leftValue) in left.enumerated() {
            let childPath = JSONPointer.appending(String(leftIndex), to: path)
            let match = try remainingRight.sorted().first { rightIndex in
                try compareNode(leftValue, right[rightIndex], path: childPath).status == .unchanged
            }
            if let match {
                remainingRight.remove(match)
                children.append(DiffNode(
                    path: childPath,
                    name: "[\(leftIndex)]",
                    status: .unchanged,
                    leftValue: leftValue,
                    rightValue: right[match]
                ))
            } else {
                children.append(DiffNode(
                    path: childPath,
                    name: "[\(leftIndex)]",
                    status: .removed,
                    leftValue: leftValue,
                    rightValue: nil
                ))
            }
        }

        for rightIndex in remainingRight.sorted() {
            children.append(DiffNode(
                path: JSONPointer.appending(String(rightIndex), to: path),
                name: "[\(rightIndex)]",
                status: .added,
                leftValue: nil,
                rightValue: right[rightIndex]
            ))
        }
        return children
    }

    private func arrayMode(for path: String) -> ArrayComparisonMode {
        if let exact = options.arrayRules[path] { return exact }
        if let matched = options.arrayRules.first(where: {
            JSONPointer.matches(path: path, pattern: $0.key)
        }) {
            return matched.value
        }
        return options.defaultArrayMode
    }

    private func areEquivalent(_ left: JSONValue, _ right: JSONValue) -> Bool {
        switch (left, right) {
        case (.null, .null):
            return true
        case let (.bool(lhs), .bool(rhs)):
            return lhs == rhs
        case let (.number(lhs), .number(rhs)):
            return numbersEquivalent(lhs, rhs)
        case let (.string(lhs), .string(rhs)):
            return stringsEquivalent(lhs, rhs)
        case let (.string(lhs), .number(rhs)) where options.strings.coerceNumericStrings:
            guard let number = Decimal(
                string: lhs.trimmingCharacters(in: .whitespacesAndNewlines),
                locale: Locale(identifier: "en_US_POSIX")
            ) else { return false }
            return numbersEquivalent(number, rhs)
        case let (.number(lhs), .string(rhs)) where options.strings.coerceNumericStrings:
            guard let number = Decimal(
                string: rhs.trimmingCharacters(in: .whitespacesAndNewlines),
                locale: Locale(identifier: "en_US_POSIX")
            ) else { return false }
            return numbersEquivalent(lhs, number)
        default:
            return false
        }
    }

    private func numbersEquivalent(_ left: Decimal, _ right: Decimal) -> Bool {
        if left == right { return true }
        let difference = decimalMagnitude(left - right)
        let absoluteTolerance = Decimal(options.numberTolerance.absolute)
        let relativeScale = Decimal(options.numberTolerance.relativePercent) / 100
        let relativeTolerance = max(decimalMagnitude(left), decimalMagnitude(right)) * relativeScale
        return difference <= max(absoluteTolerance, relativeTolerance)
    }

    private func stringsEquivalent(_ left: String, _ right: String) -> Bool {
        if options.strings.ignoreUUIDValues, isUUID(left), isUUID(right) { return true }
        if options.strings.ignoreTimestampValues,
           parseISODate(left) != nil,
           parseISODate(right) != nil { return true }
        if options.strings.normalizeISODates,
           let leftDate = parseISODate(left),
           let rightDate = parseISODate(right) {
            return leftDate == rightDate
        }

        var lhs = left
        var rhs = right
        if options.strings.normalizeLineEndings {
            lhs = lhs.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            rhs = rhs.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        }
        if options.strings.trimWhitespace {
            lhs = lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            rhs = rhs.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if options.strings.ignoreCase {
            let stableLocale = Locale(identifier: "en_US_POSIX")
            lhs = lhs.folding(options: [.caseInsensitive], locale: stableLocale)
            rhs = rhs.folding(options: [.caseInsensitive], locale: stableLocale)
        }
        return lhs == rhs
    }

    private func isIgnored(_ path: String) -> Bool {
        !path.isEmpty && options.ignorePaths.contains {
            JSONPointer.matches(path: path, pattern: $0)
        }
    }

    private func decimalMagnitude(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }

    private func isUUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    private func parseISODate(_ value: String) -> Date? {
        fractionalISOFormatter.date(from: value) ?? isoFormatter.date(from: value)
    }

    private func sameJSONType(_ left: JSONValue, _ right: JSONValue) -> Bool {
        left.typeName == right.typeName
    }
}

public enum SemanticDiffError: LocalizedError, Equatable {
    case invalidArrayKey(path: String, key: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidArrayKey(path, key):
            let displayPath = path.isEmpty ? "/" : path
            return "Array rule at \(displayPath) cannot match by '\(key)': every item must have a unique key value."
        }
    }
}
