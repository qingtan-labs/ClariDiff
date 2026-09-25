import Foundation

public enum ContentFormat: String, CaseIterable, Codable {
    case json = "JSON"
    case jsonLines = "JSONL"
    case yaml = "YAML"
    case toml = "TOML"
    case xml = "XML"
    case csv = "CSV"
    case sourceCode = "Code"
    case markdown = "Markdown"
    case html = "HTML"
    case richText = "RTF"
    case word = "DOCX"
    case pdf = "PDF"
    case plainText = "Text"

    public var isStructuredData: Bool {
        switch self {
        case .json, .jsonLines, .yaml, .toml, .xml, .csv:
            return true
        default:
            return false
        }
    }

    public var isDocument: Bool {
        switch self {
        case .markdown, .richText, .word, .pdf, .plainText:
            return true
        default:
            return false
        }
    }
}

public enum ComparisonKind: String, Codable {
    case structured
    case code
    case document
    case text
}

public struct ContentBlock: Equatable {
    public let label: String
    public let text: String
    public let canonicalText: String
    public let sourceLine: Int?

    public init(label: String, text: String, canonicalText: String, sourceLine: Int? = nil) {
        self.label = label
        self.text = text
        self.canonicalText = canonicalText
        self.sourceLine = sourceLine
    }
}

public struct ParsedContent {
    public let format: ContentFormat
    public let kind: ComparisonKind
    public let fileName: String
    public let originalText: String
    public let formattedText: String
    public let structuredValue: JSONValue?
    public let blocks: [ContentBlock]

    public init(
        format: ContentFormat,
        kind: ComparisonKind,
        fileName: String,
        originalText: String,
        formattedText: String,
        structuredValue: JSONValue? = nil,
        blocks: [ContentBlock] = []
    ) {
        self.format = format
        self.kind = kind
        self.fileName = fileName
        self.originalText = originalText
        self.formattedText = formattedText
        self.structuredValue = structuredValue
        self.blocks = blocks
    }
}

public struct ContentParseError: LocalizedError, Equatable {
    public let format: ContentFormat?
    public let message: String

    public init(format: ContentFormat? = nil, message: String) {
        self.format = format
        self.message = message
    }

    public var errorDescription: String? {
        if let format {
            return "\(format.rawValue): \(message)"
        }
        return message
    }
}
