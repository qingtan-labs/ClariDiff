import Foundation

public struct JSONParser {
    public init() {}

    public func parse(_ source: String) throws -> JSONValue {
        guard let data = source.data(using: .utf8) else {
            throw JSONParseError(message: "Input is not valid UTF-8", line: nil, column: nil)
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return try JSONValue(any: object)
        } catch {
            throw enriched(error: error, source: source)
        }
    }

    private func enriched(error: Error, source: String) -> JSONParseError {
        let message = (error as NSError).localizedDescription
        let patterns = ["character (\\d+)", "around line (\\d+), column (\\d+)"]

        if let regex = try? NSRegularExpression(pattern: patterns[1]),
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let lineRange = Range(match.range(at: 1), in: message),
           let columnRange = Range(match.range(at: 2), in: message) {
            return JSONParseError(
                message: message,
                line: Int(message[lineRange]),
                column: Int(message[columnRange])
            )
        }

        if let regex = try? NSRegularExpression(pattern: patterns[0]),
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let range = Range(match.range(at: 1), in: message),
           let offset = Int(message[range]) {
            let prefix = String(source.prefix(offset))
            let lines = prefix.split(separator: "\n", omittingEmptySubsequences: false)
            return JSONParseError(
                message: message,
                line: max(1, lines.count),
                column: (lines.last?.count ?? 0) + 1
            )
        }
        return JSONParseError(message: message, line: nil, column: nil)
    }
}

public struct JSONParseError: LocalizedError, Equatable {
    public let message: String
    public let line: Int?
    public let column: Int?

    public init(message: String, line: Int?, column: Int?) {
        self.message = message
        self.line = line
        self.column = column
    }

    public var errorDescription: String? {
        if let line, let column {
            return "Line \(line), column \(column): \(message)"
        }
        return message
    }
}
