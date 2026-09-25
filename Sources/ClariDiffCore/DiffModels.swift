import Foundation

public enum DiffStatus: String, CaseIterable, Codable {
    case added
    case removed
    case modified
    case typeChanged = "type_changed"
    case moved
    case unchanged
}

public enum ArrayComparisonMode: Equatable {
    case positional
    case unordered
    case keyed(String)

    public var description: String {
        switch self {
        case .positional: return "position"
        case .unordered: return "ignore"
        case let .keyed(key): return "matchBy:\(key)"
        }
    }
}

public struct NumberTolerance: Equatable {
    public var absolute: Double
    public var relativePercent: Double

    public init(absolute: Double = 0, relativePercent: Double = 0) {
        self.absolute = max(0, absolute)
        self.relativePercent = max(0, relativePercent)
    }
}

public struct StringNormalization: Equatable {
    public var trimWhitespace: Bool
    public var ignoreCase: Bool
    public var normalizeLineEndings: Bool
    public var normalizeISODates: Bool
    public var coerceNumericStrings: Bool
    public var ignoreUUIDValues: Bool
    public var ignoreTimestampValues: Bool

    public init(
        trimWhitespace: Bool = false,
        ignoreCase: Bool = false,
        normalizeLineEndings: Bool = true,
        normalizeISODates: Bool = false,
        coerceNumericStrings: Bool = false,
        ignoreUUIDValues: Bool = false,
        ignoreTimestampValues: Bool = false
    ) {
        self.trimWhitespace = trimWhitespace
        self.ignoreCase = ignoreCase
        self.normalizeLineEndings = normalizeLineEndings
        self.normalizeISODates = normalizeISODates
        self.coerceNumericStrings = coerceNumericStrings
        self.ignoreUUIDValues = ignoreUUIDValues
        self.ignoreTimestampValues = ignoreTimestampValues
    }
}

public struct DiffOptions: Equatable {
    public var ignorePaths: [String]
    public var arrayRules: [String: ArrayComparisonMode]
    public var defaultArrayMode: ArrayComparisonMode
    public var numberTolerance: NumberTolerance
    public var strings: StringNormalization

    public init(
        ignorePaths: [String] = [],
        arrayRules: [String: ArrayComparisonMode] = [:],
        defaultArrayMode: ArrayComparisonMode = .positional,
        numberTolerance: NumberTolerance = .init(),
        strings: StringNormalization = .init()
    ) {
        self.ignorePaths = ignorePaths
        self.arrayRules = arrayRules
        self.defaultArrayMode = defaultArrayMode
        self.numberTolerance = numberTolerance
        self.strings = strings
    }
}

public struct DiffNode: Identifiable, Equatable {
    public let id: String
    public let path: String
    public let name: String
    public let status: DiffStatus
    public let leftValue: JSONValue?
    public let rightValue: JSONValue?
    public let children: [DiffNode]
    public let isIgnored: Bool

    public init(
        path: String,
        name: String? = nil,
        status: DiffStatus,
        leftValue: JSONValue?,
        rightValue: JSONValue?,
        children: [DiffNode] = [],
        isIgnored: Bool = false
    ) {
        self.path = path
        self.name = name ?? (path.isEmpty ? "$" : JSONPointer.lastComponent(of: path))
        self.status = status
        self.leftValue = leftValue
        self.rightValue = rightValue
        self.children = children
        self.isIgnored = isIgnored
        self.id = "\(path)|\(self.name)|\(status.rawValue)"
    }

    public var hasChanges: Bool {
        status != .unchanged
    }

    public var leafChanges: [DiffNode] {
        if children.isEmpty {
            return status == .unchanged ? [] : [self]
        }
        return children.flatMap(\.leafChanges)
    }

    public var summary: DiffSummary {
        leafChanges.reduce(into: DiffSummary()) { summary, node in
            summary.add(node.status)
        }
    }

    public func filtering(statuses: Set<DiffStatus>, search: String = "") -> DiffNode? {
        let filteredChildren = children.compactMap { $0.filtering(statuses: statuses, search: search) }
        let statusMatches = statuses.isEmpty || statuses.contains(status)
        let searchMatches = search.isEmpty || path.localizedCaseInsensitiveContains(search)
            || name.localizedCaseInsensitiveContains(search)
        if children.isEmpty {
            return statusMatches && searchMatches ? self : nil
        }
        guard !filteredChildren.isEmpty || (statusMatches && searchMatches) else { return nil }
        return DiffNode(
            path: path,
            name: name,
            status: status,
            leftValue: leftValue,
            rightValue: rightValue,
            children: filteredChildren,
            isIgnored: isIgnored
        )
    }
}

public struct DiffSummary: Equatable {
    public var added = 0
    public var removed = 0
    public var modified = 0
    public var typeChanged = 0
    public var moved = 0

    public init() {}

    public var total: Int { added + removed + modified + typeChanged + moved }

    mutating func add(_ status: DiffStatus) {
        switch status {
        case .added: added += 1
        case .removed: removed += 1
        case .modified: modified += 1
        case .typeChanged: typeChanged += 1
        case .moved: moved += 1
        case .unchanged: break
        }
    }
}
