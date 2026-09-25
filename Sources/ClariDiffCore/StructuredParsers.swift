import Foundation
import Yams

public struct YAMLContentParser {
    public init() {}

    public func parse(_ source: String) throws -> JSONValue {
        do {
            let loaded = try Yams.load(yaml: source) ?? NSNull()
            return try JSONValue(any: normalize(loaded))
        } catch {
            throw ContentParseError(format: .yaml, message: error.localizedDescription)
        }
    }

    private func normalize(_ value: Any) -> Any {
        if let dictionary = value as? [AnyHashable: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dictionary {
                result[String(describing: key)] = normalize(value)
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map(normalize)
        }
        if value is Date {
            return String(describing: value)
        }
        return value
    }
}

public struct TOMLContentParser {
    public init() {}

    public func parse(_ source: String) throws -> JSONValue {
        var root = JSONValue.object([:])
        var section: [String] = []
        let lines = source.components(separatedBy: .newlines)

        for (offset, rawLine) in lines.enumerated() {
            let line = stripComment(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("[["), line.hasSuffix("]]"), line.count > 4 {
                section = splitDottedKey(String(line.dropFirst(2).dropLast(2)))
                guard !section.isEmpty else { throw error(offset, "empty array table name") }
                appendArrayTable(at: ArraySlice(section), in: &root)
                continue
            }
            if line.hasPrefix("["), line.hasSuffix("]"), line.count > 2 {
                section = splitDottedKey(String(line.dropFirst().dropLast()))
                guard !section.isEmpty else { throw error(offset, "empty table name") }
                ensureObject(at: ArraySlice(section), in: &root)
                continue
            }

            guard let separator = firstEquals(in: line) else {
                throw error(offset, "expected key = value")
            }
            let keySource = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let valueSource = String(line[line.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            let keyPath = splitDottedKey(keySource)
            guard !keyPath.isEmpty else { throw error(offset, "empty key") }
            let value = try parseValue(valueSource, line: offset)
            assign(value, at: ArraySlice(section + keyPath), in: &root)
        }
        return root
    }

    private func parseValue(_ source: String, line: Int) throws -> JSONValue {
        guard !source.isEmpty else { throw error(line, "missing value") }
        if source.hasPrefix("\"") && source.hasSuffix("\"") && source.count >= 2 {
            let data = Data(source.utf8)
            if let decoded = try? JSONSerialization.jsonObject(with: data) as? String {
                return .string(decoded)
            }
            return .string(String(source.dropFirst().dropLast()))
        }
        if source.hasPrefix("'") && source.hasSuffix("'") && source.count >= 2 {
            return .string(String(source.dropFirst().dropLast()))
        }
        if source == "true" { return .bool(true) }
        if source == "false" { return .bool(false) }
        if source.hasPrefix("["), source.hasSuffix("]") {
            let body = String(source.dropFirst().dropLast())
            let items = splitTopLevel(body, separator: ",")
            return .array(try items.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { try parseValue($0.trimmingCharacters(in: .whitespaces), line: line) })
        }
        if source.hasPrefix("{"), source.hasSuffix("}") {
            let body = String(source.dropFirst().dropLast())
            var object: [String: JSONValue] = [:]
            for item in splitTopLevel(body, separator: ",") {
                guard let separator = firstEquals(in: item) else {
                    throw error(line, "invalid inline table")
                }
                let key = unquote(String(item[..<separator]).trimmingCharacters(in: .whitespaces))
                let valueSource = String(item[item.index(after: separator)...])
                    .trimmingCharacters(in: .whitespaces)
                object[key] = try parseValue(valueSource, line: line)
            }
            return .object(object)
        }

        let normalized = source.replacingOccurrences(of: "_", with: "")
        if let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) {
            return .number(decimal)
        }
        // TOML date/time values are kept as canonical strings so timezone normalization rules can apply.
        return .string(source)
    }

    private func assign(_ value: JSONValue, at path: ArraySlice<String>, in container: inout JSONValue) {
        guard let key = path.first else { return }
        switch container {
        case var .object(object):
            if path.count == 1 {
                object[key] = value
            } else {
                var child = object[key] ?? .object([:])
                assign(value, at: path.dropFirst(), in: &child)
                object[key] = child
            }
            container = .object(object)
        case var .array(array):
            if array.isEmpty { array.append(.object([:])) }
            var current = array.removeLast()
            assign(value, at: path, in: &current)
            array.append(current)
            container = .array(array)
        default:
            container = .object([:])
            assign(value, at: path, in: &container)
        }
    }

    private func ensureObject(at path: ArraySlice<String>, in container: inout JSONValue) {
        guard let key = path.first else {
            if case .object = container { return }
            container = .object([:])
            return
        }
        switch container {
        case var .object(object):
            var child = object[key] ?? .object([:])
            ensureObject(at: path.dropFirst(), in: &child)
            object[key] = child
            container = .object(object)
        case var .array(array):
            if array.isEmpty { array.append(.object([:])) }
            var current = array.removeLast()
            ensureObject(at: path, in: &current)
            array.append(current)
            container = .array(array)
        default:
            container = .object([:])
            ensureObject(at: path, in: &container)
        }
    }

    private func appendArrayTable(at path: ArraySlice<String>, in container: inout JSONValue) {
        guard let key = path.first else {
            var values: [JSONValue]
            if case let .array(existing) = container {
                values = existing
            } else {
                values = []
            }
            values.append(.object([:]))
            container = .array(values)
            return
        }
        switch container {
        case var .object(object):
            let fallback: JSONValue = path.count == 1 ? .array([]) : .object([:])
            var child = object[key] ?? fallback
            appendArrayTable(at: path.dropFirst(), in: &child)
            object[key] = child
            container = .object(object)
        case var .array(array):
            if array.isEmpty { array.append(.object([:])) }
            var current = array.removeLast()
            appendArrayTable(at: path, in: &current)
            array.append(current)
            container = .array(array)
        default:
            container = .object([:])
            appendArrayTable(at: path, in: &container)
        }
    }

    private func splitDottedKey(_ source: String) -> [String] {
        splitTopLevel(source, separator: ".")
            .map { unquote($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
    }

    private func stripComment(_ source: String) -> String {
        var quote: Character?
        var escaped = false
        for index in source.indices {
            let character = source[index]
            if escaped { escaped = false; continue }
            if character == "\\", quote == "\"" { escaped = true; continue }
            if character == "\"" || character == "'" {
                quote = quote == nil ? character : (quote == character ? nil : quote)
            } else if character == "#", quote == nil {
                return String(source[..<index])
            }
        }
        return source
    }

    private func firstEquals(in source: String) -> String.Index? {
        var quote: Character?
        var depth = 0
        for index in source.indices {
            let character = source[index]
            if character == "\"" || character == "'" {
                quote = quote == nil ? character : (quote == character ? nil : quote)
            } else if quote == nil {
                if character == "[" || character == "{" { depth += 1 }
                if character == "]" || character == "}" { depth -= 1 }
                if character == "=", depth == 0 { return index }
            }
        }
        return nil
    }

    private func splitTopLevel(_ source: String, separator: Character) -> [String] {
        var parts: [String] = []
        var start = source.startIndex
        var quote: Character?
        var escaped = false
        var depth = 0
        for index in source.indices {
            let character = source[index]
            if escaped { escaped = false; continue }
            if character == "\\", quote == "\"" { escaped = true; continue }
            if character == "\"" || character == "'" {
                quote = quote == nil ? character : (quote == character ? nil : quote)
            } else if quote == nil {
                if character == "[" || character == "{" { depth += 1 }
                if character == "]" || character == "}" { depth -= 1 }
                if character == separator, depth == 0 {
                    parts.append(String(source[start..<index]))
                    start = source.index(after: index)
                }
            }
        }
        parts.append(String(source[start...]))
        return parts
    }

    private func unquote(_ source: String) -> String {
        if source.count >= 2,
           (source.hasPrefix("\"") && source.hasSuffix("\"")
            || source.hasPrefix("'") && source.hasSuffix("'")) {
            return String(source.dropFirst().dropLast())
        }
        return source
    }

    private func error(_ zeroBasedLine: Int, _ message: String) -> ContentParseError {
        ContentParseError(format: .toml, message: "Line \(zeroBasedLine + 1): \(message)")
    }
}

public struct CSVContentParser {
    public init() {}

    public func parse(_ source: String) throws -> JSONValue {
        let rows = try tokenize(source)
        guard let header = rows.first, !header.isEmpty else { return .array([]) }
        let uniqueHeader = Set(header).count == header.count && header.allSatisfy { !$0.isEmpty }
        guard uniqueHeader else {
            return .array(rows.map { .array($0.map(inferScalar)) })
        }
        let objects = rows.dropFirst().map { row -> JSONValue in
            var object: [String: JSONValue] = [:]
            for (index, name) in header.enumerated() {
                object[name] = index < row.count ? inferScalar(row[index]) : .null
            }
            if row.count > header.count {
                object["_extra"] = .array(row.dropFirst(header.count).map(inferScalar))
            }
            return .object(object)
        }
        return .array(objects)
    }

    private func tokenize(_ source: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]
            if quoted {
                if character == "\"" {
                    let next = source.index(after: index)
                    if next < source.endIndex, source[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    guard field.isEmpty else {
                        throw ContentParseError(format: .csv, message: "Unexpected quote in an unquoted field")
                    }
                    quoted = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                case "\r":
                    break
                default:
                    field.append(character)
                }
            }
            index = source.index(after: index)
        }
        guard !quoted else { throw ContentParseError(format: .csv, message: "Unclosed quoted field") }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }

    private func inferScalar(_ source: String) -> JSONValue {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "true" { return .bool(true) }
        if trimmed.lowercased() == "false" { return .bool(false) }
        if trimmed.lowercased() == "null" { return .null }
        if let decimal = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")) {
            return .number(decimal)
        }
        return .string(source)
    }
}

public final class XMLContentParser: NSObject, XMLParserDelegate {
    private final class Node {
        let name: String
        let attributes: [String: String]
        var text = ""
        var children: [Node] = []

        init(name: String, attributes: [String: String]) {
            self.name = name
            self.attributes = attributes
        }
    }

    private var stack: [Node] = []
    private var root: Node?
    private var parserError: Error?

    public override init() {}

    public func parse(_ source: String) throws -> JSONValue {
        root = nil
        stack = []
        parserError = nil
        guard let data = source.data(using: .utf8) else {
            throw ContentParseError(format: .xml, message: "Input is not valid UTF-8")
        }
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), let root else {
            throw ContentParseError(
                format: .xml,
                message: parserError?.localizedDescription ?? parser.parserError?.localizedDescription ?? "Invalid XML"
            )
        }
        return .object([root.name: value(for: root)])
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let node = Node(name: qName ?? elementName, attributes: attributeDict)
        if let parent = stack.last { parent.children.append(node) }
        stack.append(node)
        if root == nil { root = node }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        _ = stack.popLast()
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parserError = parseError
    }

    private func value(for node: Node) -> JSONValue {
        let trimmedText = node.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if node.children.isEmpty, node.attributes.isEmpty {
            return scalar(trimmedText)
        }

        var object: [String: JSONValue] = [:]
        if !node.attributes.isEmpty {
            object["@attributes"] = .object(node.attributes.mapValues { .string($0) })
        }
        if !trimmedText.isEmpty { object["#text"] = scalar(trimmedText) }

        let groups = Dictionary(grouping: node.children, by: \.name)
        for name in groups.keys.sorted() {
            let values = groups[name, default: []].map(value)
            object[name] = values.count == 1 ? values[0] : .array(values)
        }
        return .object(object)
    }

    private func scalar(_ source: String) -> JSONValue {
        if source == "true" { return .bool(true) }
        if source == "false" { return .bool(false) }
        if let decimal = Decimal(string: source, locale: Locale(identifier: "en_US_POSIX")) {
            return .number(decimal)
        }
        return .string(source)
    }
}
