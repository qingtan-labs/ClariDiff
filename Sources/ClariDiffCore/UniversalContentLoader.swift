import AppKit
import Foundation
import PDFKit

public struct UniversalContentLoader {
    private let textParser = TextBlockParser()

    public init() {}

    public func load(_ url: URL) throws -> ParsedContent {
        let format = detectFormat(fileName: url.lastPathComponent, source: nil)
        switch format {
        case .pdf:
            guard let document = PDFDocument(url: url) else {
                throw ContentParseError(format: .pdf, message: "The PDF could not be opened")
            }
            let pages = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
            let text = pages.joined(separator: "\n\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ContentParseError(
                    format: .pdf,
                    message: "No text layer was found. Scanned PDFs are not supported in this release"
                )
            }
            return makeTextContent(text, fileName: url.lastPathComponent, format: .pdf)
        case .word:
            do {
                let attributed = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
                return makeTextContent(attributed.string, fileName: url.lastPathComponent, format: .word)
            } catch {
                throw ContentParseError(format: .word, message: error.localizedDescription)
            }
        case .richText:
            let data = try Data(contentsOf: url)
            do {
                let attributed = try NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
                return makeTextContent(attributed.string, fileName: url.lastPathComponent, format: .richText)
            } catch {
                throw ContentParseError(format: .richText, message: error.localizedDescription)
            }
        default:
            let data = try Data(contentsOf: url)
            guard let source = decodeText(data) else {
                throw ContentParseError(format: format, message: "The file is not valid UTF-8 or UTF-16 text")
            }
            return try parse(source, fileName: url.lastPathComponent, preferredFormat: format)
        }
    }

    public func parse(
        _ source: String,
        fileName: String = "Untitled",
        preferredFormat: ContentFormat? = nil
    ) throws -> ParsedContent {
        let format = preferredFormat ?? detectFormat(fileName: fileName, source: source)
        switch format {
        case .json:
            let value = try JSONParser().parse(source)
            return structured(source, fileName: fileName, format: .json, value: value, formatted: value.prettyPrinted())
        case .jsonLines:
            let value = try parseJSONLines(source)
            return structured(
                source,
                fileName: fileName,
                format: .jsonLines,
                value: value,
                formatted: value.prettyPrinted()
            )
        case .yaml:
            let value = try YAMLContentParser().parse(source)
            return structured(source, fileName: fileName, format: .yaml, value: value)
        case .toml:
            let value = try TOMLContentParser().parse(source)
            return structured(source, fileName: fileName, format: .toml, value: value)
        case .xml:
            let value = try XMLContentParser().parse(source)
            return structured(source, fileName: fileName, format: .xml, value: value)
        case .csv:
            let value = try CSVContentParser().parse(source)
            return structured(source, fileName: fileName, format: .csv, value: value)
        case .sourceCode:
            return ParsedContent(
                format: .sourceCode,
                kind: .code,
                fileName: fileName,
                originalText: source,
                formattedText: source,
                blocks: textParser.codeBlocks(from: source)
            )
        case .markdown:
            return makeTextContent(source, fileName: fileName, format: .markdown)
        case .html:
            return ParsedContent(
                format: .html,
                kind: .code,
                fileName: fileName,
                originalText: source,
                formattedText: source,
                blocks: textParser.codeBlocks(from: source)
            )
        case .richText, .word, .pdf:
            // Binary document formats enter through load(_:). Pasted extracted text remains comparable.
            return makeTextContent(source, fileName: fileName, format: format)
        case .plainText:
            return ParsedContent(
                format: .plainText,
                kind: .text,
                fileName: fileName,
                originalText: source,
                formattedText: source,
                blocks: textParser.textBlocks(from: source)
            )
        }
    }

    public func detectFormat(fileName: String, source: String?) -> ContentFormat {
        let extensionName = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        switch extensionName {
        case "json", "geojson": return .json
        case "jsonl", "ndjson": return .jsonLines
        case "yaml", "yml": return .yaml
        case "toml": return .toml
        case "xml", "plist", "xsd", "svg": return .xml
        case "csv": return .csv
        case "md", "markdown", "mdown": return .markdown
        case "html", "htm": return .html
        case "rtf": return .richText
        case "docx": return .word
        case "pdf": return .pdf
        case "txt", "text", "log": return .plainText
        default:
            if Self.codeExtensions.contains(extensionName) { return .sourceCode }
        }

        guard let source else { return .plainText }
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
            || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if (try? JSONParser().parse(source)) != nil { return .json }
        }
        if trimmed.hasPrefix("<"), trimmed.hasSuffix(">"), (try? XMLContentParser().parse(source)) != nil {
            return .xml
        }
        if source.range(of: #"(?m)^\s*#{1,6}\s+\S"#, options: .regularExpression) != nil
            || source.contains("```") {
            return .markdown
        }
        if looksLikeCode(source) { return .sourceCode }
        if looksLikeCSV(source) { return .csv }
        if source.range(of: #"(?m)^\s*[A-Za-z0-9_.-]+\s*=\s*.+$"#, options: .regularExpression) != nil {
            return .toml
        }
        if source.range(of: #"(?m)^\s*[A-Za-z0-9_.-]+:\s*(.+)?$"#, options: .regularExpression) != nil {
            return .yaml
        }
        return .plainText
    }

    private func structured(
        _ source: String,
        fileName: String,
        format: ContentFormat,
        value: JSONValue,
        formatted: String? = nil
    ) -> ParsedContent {
        ParsedContent(
            format: format,
            kind: .structured,
            fileName: fileName,
            originalText: source,
            formattedText: formatted ?? source,
            structuredValue: value
        )
    }

    private func parseJSONLines(_ source: String) throws -> JSONValue {
        var values: [JSONValue] = []
        for (index, line) in source.components(separatedBy: .newlines).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            do {
                values.append(try JSONParser().parse(trimmed))
            } catch {
                throw ContentParseError(
                    format: .jsonLines,
                    message: "Line \(index + 1): \(error.localizedDescription)"
                )
            }
        }
        return .array(values)
    }

    private func makeTextContent(_ source: String, fileName: String, format: ContentFormat) -> ParsedContent {
        ParsedContent(
            format: format,
            kind: format == .plainText ? .text : .document,
            fileName: fileName,
            originalText: source,
            formattedText: source,
            blocks: textParser.documentBlocks(from: source, format: format)
        )
    }

    private func decodeText(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .utf16LittleEndian)
            ?? String(data: data, encoding: .utf16BigEndian)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private func looksLikeCSV(_ source: String) -> Bool {
        let lines = source.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return false }
        let counts = lines.prefix(5).map { $0.filter { $0 == "," }.count }
        guard let expected = counts.first, expected > 0 else { return false }
        return counts.allSatisfy { $0 == expected }
    }

    private func looksLikeCode(_ source: String) -> Bool {
        let patterns = [
            #"(?m)^\s*(import|from|package|using|include)\s+"#,
            #"(?m)^\s*(class|struct|enum|protocol|interface|func|function|def|fn)\s+"#,
            #"(?m)^\s*(let|var|const|public|private|internal|static)\s+"#
        ]
        return patterns.contains { source.range(of: $0, options: .regularExpression) != nil }
            || (source.contains("{") && source.contains("}") && source.contains(";"))
    }

    private static let codeExtensions: Set<String> = [
        "swift", "m", "mm", "h", "c", "cc", "cpp", "cxx", "hpp",
        "js", "jsx", "mjs", "cjs", "ts", "tsx", "mts", "cts", "jsonc",
        "vue", "svelte", "astro", "mdx", "graphql", "gql",
        "py", "pyi", "java",
        "kt", "kts", "go", "rs", "cs", "rb", "php", "sh", "bash", "zsh",
        "fish", "sql", "css", "scss", "sass", "less", "styl", "stylus",
        "pcss", "postcss",
        "dart", "lua", "r", "scala", "ex", "exs", "erl", "hrl"
    ]
}
