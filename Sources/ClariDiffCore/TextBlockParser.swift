import Foundation

public struct TextBlockParser {
    public init() {}

    public func codeBlocks(from source: String) -> [ContentBlock] {
        source.normalizedLineEndings
            .components(separatedBy: "\n")
            .enumerated()
            .compactMap { index, rawLine in
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                return ContentBlock(
                    label: codeLabel(for: trimmed, line: index + 1),
                    text: rawLine,
                    canonicalText: canonicalCodeLine(trimmed),
                    sourceLine: index + 1
                )
            }
    }

    public func documentBlocks(from source: String, format: ContentFormat) -> [ContentBlock] {
        if format == .markdown {
            return markdownBlocks(from: source)
        }
        return paragraphBlocks(from: source)
    }

    public func textBlocks(from source: String) -> [ContentBlock] {
        let lines = source.normalizedLineEndings.components(separatedBy: "\n")
        return lines.enumerated().compactMap { index, line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ContentBlock(
                label: "Line \(index + 1)",
                text: line,
                canonicalText: canonicalProse(line),
                sourceLine: index + 1
            )
        }
    }

    private func markdownBlocks(from source: String) -> [ContentBlock] {
        let lines = source.normalizedLineEndings.components(separatedBy: "\n")
        var blocks: [ContentBlock] = []
        var paragraph: [String] = []
        var paragraphStart = 1
        var inFence = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            let text = paragraph.joined(separator: "\n")
            blocks.append(ContentBlock(
                label: "Paragraph \(blocks.count + 1)",
                text: text,
                canonicalText: canonicalProse(text),
                sourceLine: paragraphStart
            ))
            paragraph.removeAll(keepingCapacity: true)
        }

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if !inFence { flushParagraph(); paragraphStart = index + 1 }
                paragraph.append(line)
                inFence.toggle()
                if !inFence { flushParagraph() }
                continue
            }
            if inFence {
                paragraph.append(line)
                continue
            }
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }
            if isStandaloneMarkdownBlock(trimmed) {
                flushParagraph()
                blocks.append(ContentBlock(
                    label: markdownLabel(trimmed, fallback: blocks.count + 1),
                    text: line,
                    canonicalText: canonicalProse(trimmed),
                    sourceLine: index + 1
                ))
                continue
            }
            if paragraph.isEmpty { paragraphStart = index + 1 }
            paragraph.append(line)
        }
        flushParagraph()
        return blocks
    }

    private func paragraphBlocks(from source: String) -> [ContentBlock] {
        let normalized = source.normalizedLineEndings
        let rawParagraphs = normalized.components(separatedBy: "\n\n")
        var blocks: [ContentBlock] = []
        var searchStart = normalized.startIndex

        for raw in rawParagraphs {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let line = normalized[..<searchStart].reduce(into: 1) { count, character in
                if character == "\n" { count += 1 }
            }
            blocks.append(ContentBlock(
                label: paragraphLabel(text, fallback: blocks.count + 1),
                text: text,
                canonicalText: canonicalProse(text),
                sourceLine: line
            ))
            if let range = normalized.range(of: raw, range: searchStart..<normalized.endIndex) {
                searchStart = range.upperBound
            }
        }

        // Single-line-oriented documents are more useful when compared line by line.
        if blocks.count <= 1 {
            let lineBlocks = textBlocks(from: normalized)
            if lineBlocks.count > 1 { return lineBlocks }
        }
        return blocks
    }

    private func isStandaloneMarkdownBlock(_ line: String) -> Bool {
        line.hasPrefix("#")
            || line.hasPrefix("- ")
            || line.hasPrefix("* ")
            || line.hasPrefix("> ")
            || line.hasPrefix("|")
            || line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
    }

    private func markdownLabel(_ line: String, fallback: Int) -> String {
        if line.hasPrefix("#") {
            let heading = line.drop(while: { $0 == "#" || $0 == " " })
            return heading.isEmpty ? "Heading \(fallback)" : String(heading.prefix(54))
        }
        if line.hasPrefix("|") { return "Table row \(fallback)" }
        return "List item \(fallback)"
    }

    private func paragraphLabel(_ text: String, fallback: Int) -> String {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.count <= 54 { return trimmed }
        return "Paragraph \(fallback)"
    }

    private func codeLabel(for line: String, line number: Int) -> String {
        let markers = ["func ", "function ", "def ", "class ", "struct ", "enum ", "protocol ",
                       "interface ", "type ", "extension ", "fn ", "package ", "module "]
        if markers.contains(where: { line.hasPrefix($0) }) {
            return String(line.prefix(54))
        }
        return "Line \(number)"
    }

    private func canonicalCodeLine(_ line: String) -> String {
        var result = ""
        var quote: Character?
        var escaped = false
        var pendingSpace = false

        for character in line {
            if escaped {
                result.append(character)
                escaped = false
                continue
            }
            if character == "\\", quote != nil {
                result.append(character)
                escaped = true
                continue
            }
            if character == "\"" || character == "'" || character == "`" {
                if pendingSpace, !result.isEmpty { result.append(" ") }
                pendingSpace = false
                quote = quote == nil ? character : (quote == character ? nil : quote)
                result.append(character)
                continue
            }
            if quote == nil, character.isWhitespace {
                pendingSpace = true
            } else {
                if pendingSpace, !result.isEmpty, quote != nil { result.append(" ") }
                pendingSpace = false
                result.append(character)
            }
        }
        return result
    }

    private func canonicalProse(_ source: String) -> String {
        source
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private extension String {
    var normalizedLineEndings: String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
