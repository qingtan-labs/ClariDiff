import Foundation

public enum ReportFormat: String {
    case text
    case markdown
}

public struct ReportExporter {
    public init() {}

    public func export(_ root: DiffNode, format: ReportFormat) -> String {
        switch format {
        case .text: return text(root)
        case .markdown: return markdown(root)
        }
    }

    public func markdown(_ root: DiffNode) -> String {
        let summary = root.summary
        var output = """
        # ClariDiff Report

        **\(summary.total) meaningful changes** — \(summary.added) added, \(summary.removed) removed, \(summary.modified) modified, \(summary.typeChanged) type changed

        """
        guard summary.total > 0 else {
            return output + "No meaningful differences found.\n"
        }
        output += "| Path | Change | Before | After |\n"
        output += "|---|---|---|---|\n"
        for node in root.leafChanges {
            output += "| `\(escape(node.path.isEmpty ? "/" : node.path))` "
            output += "| \(label(node.status)) "
            output += "| \(inline(node.leftValue)) "
            output += "| \(inline(node.rightValue)) |\n"
        }
        return output
    }

    public func text(_ root: DiffNode) -> String {
        let changes = root.leafChanges
        guard !changes.isEmpty else { return "No meaningful differences.\n" }
        return changes.map { node in
            let path = node.path.isEmpty ? "/" : node.path
            return "\(symbol(node.status)) \(path): \(plain(node.leftValue)) -> \(plain(node.rightValue))"
        }.joined(separator: "\n") + "\n"
    }

    private func label(_ status: DiffStatus) -> String {
        switch status {
        case .added: return "Added"
        case .removed: return "Removed"
        case .modified: return "Modified"
        case .typeChanged: return "Type changed"
        case .moved: return "Moved"
        case .unchanged: return "Unchanged"
        }
    }

    private func symbol(_ status: DiffStatus) -> String {
        switch status {
        case .added: return "+"
        case .removed: return "-"
        case .modified: return "~"
        case .typeChanged: return "!"
        case .moved: return ">"
        case .unchanged: return " "
        }
    }

    private func inline(_ value: JSONValue?) -> String {
        guard let value else { return "—" }
        let rendered: String
        switch value {
        case .string:
            rendered = value.scalarDescription
        default:
            rendered = value.prettyPrinted().replacingOccurrences(of: "\n", with: " ")
        }
        return "`\(escape(String(rendered.prefix(160))))`"
    }

    private func plain(_ value: JSONValue?) -> String {
        guard let value else { return "<missing>" }
        return value.scalarDescription.replacingOccurrences(of: "\n", with: "\\n")
    }

    private func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "`", with: "\\`")
    }
}
