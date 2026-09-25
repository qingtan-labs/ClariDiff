import Foundation

public struct RuleConfiguration: Equatable {
    public var version: Int
    public var options: DiffOptions

    public init(version: Int = 1, options: DiffOptions = .init()) {
        self.version = version
        self.options = options
    }
}

public struct RuleConfigurationParser {
    public init() {}

    public func parse(_ source: String) throws -> RuleConfiguration {
        var version = 1
        var ignorePaths: [String] = []
        var arrayBuilders: [String: ArrayRuleBuilder] = [:]
        var numberTolerance = NumberTolerance()
        var strings = StringNormalization()
        var section = ""
        var currentArrayPath: String?

        for (lineNumber, rawLine) in source.components(separatedBy: .newlines).enumerated() {
            let content = stripComment(rawLine)
            guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let indentation = content.prefix { $0 == " " }.count
            let trimmed = content.trimmingCharacters(in: .whitespaces)

            if indentation == 0 {
                currentArrayPath = nil
                if trimmed.hasSuffix(":") {
                    section = String(trimmed.dropLast())
                    continue
                }
                let pair = try keyValue(trimmed, line: lineNumber + 1)
                if pair.key == "version" {
                    guard let parsed = Int(pair.value) else {
                        throw RuleConfigurationError(line: lineNumber + 1, message: "version must be an integer")
                    }
                    version = parsed
                }
                continue
            }

            switch section {
            case "ignore":
                guard trimmed.hasPrefix("-") else {
                    throw RuleConfigurationError(line: lineNumber + 1, message: "ignore entries must start with '-'")
                }
                let value = unquote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                if !value.isEmpty { ignorePaths.append(value) }
            case "arrays":
                if indentation <= 2, trimmed.hasSuffix(":") {
                    let path = unquote(String(trimmed.dropLast()))
                    currentArrayPath = path
                    arrayBuilders[path] = ArrayRuleBuilder()
                } else if let path = currentArrayPath {
                    let pair = try keyValue(trimmed, line: lineNumber + 1)
                    var builder = arrayBuilders[path] ?? ArrayRuleBuilder()
                    if pair.key == "matchBy" { builder.matchBy = unquote(pair.value) }
                    if pair.key == "order" { builder.order = unquote(pair.value) }
                    arrayBuilders[path] = builder
                }
            case "numbers":
                let pair = try keyValue(trimmed, line: lineNumber + 1)
                guard let number = Double(unquote(pair.value)) else {
                    throw RuleConfigurationError(line: lineNumber + 1, message: "\(pair.key) must be a number")
                }
                if pair.key == "defaultTolerance" || pair.key == "absoluteTolerance" {
                    numberTolerance.absolute = max(0, number)
                } else if pair.key == "relativeTolerancePercent" {
                    numberTolerance.relativePercent = max(0, number)
                }
            case "strings":
                let pair = try keyValue(trimmed, line: lineNumber + 1)
                guard let value = parseBool(pair.value) else {
                    throw RuleConfigurationError(line: lineNumber + 1, message: "\(pair.key) must be true or false")
                }
                switch pair.key {
                case "trimWhitespace": strings.trimWhitespace = value
                case "ignoreCase": strings.ignoreCase = value
                case "normalizeLineEndings": strings.normalizeLineEndings = value
                case "normalizeISODates": strings.normalizeISODates = value
                case "coerceNumericStrings": strings.coerceNumericStrings = value
                case "ignoreUUIDValues": strings.ignoreUUIDValues = value
                case "ignoreTimestampValues": strings.ignoreTimestampValues = value
                default: break
                }
            default:
                continue
            }
        }

        guard version == 1 else {
            throw RuleConfigurationError(line: 1, message: "Unsupported configuration version \(version)")
        }

        let arrayRules = arrayBuilders.reduce(into: [String: ArrayComparisonMode]()) { result, entry in
            let (path, builder) = entry
            if let key = builder.matchBy, !key.isEmpty {
                result[JSONPointer.normalizeRule(path)] = .keyed(key)
            } else if builder.order == "ignore" {
                result[JSONPointer.normalizeRule(path)] = .unordered
            } else {
                result[JSONPointer.normalizeRule(path)] = .positional
            }
        }

        return RuleConfiguration(
            version: version,
            options: DiffOptions(
                ignorePaths: ignorePaths.map(JSONPointer.normalizeRule),
                arrayRules: arrayRules,
                numberTolerance: numberTolerance,
                strings: strings
            )
        )
    }

    private struct ArrayRuleBuilder {
        var matchBy: String?
        var order: String?
    }

    private func stripComment(_ line: String) -> String {
        var quoted = false
        for index in line.indices {
            if line[index] == "\"" { quoted.toggle() }
            if line[index] == "#", !quoted { return String(line[..<index]) }
        }
        return line
    }

    private func keyValue(_ line: String, line lineNumber: Int) throws -> (key: String, value: String) {
        guard let separator = line.firstIndex(of: ":") else {
            throw RuleConfigurationError(line: lineNumber, message: "Expected key: value")
        }
        return (
            String(line[..<separator]).trimmingCharacters(in: .whitespaces),
            String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        )
    }

    private func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        if (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private func parseBool(_ value: String) -> Bool? {
        switch unquote(value).lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil
        }
    }
}

public struct RuleConfigurationError: LocalizedError, Equatable {
    public let line: Int
    public let message: String

    public init(line: Int, message: String) {
        self.line = line
        self.message = message
    }

    public var errorDescription: String? { "Line \(line): \(message)" }
}
