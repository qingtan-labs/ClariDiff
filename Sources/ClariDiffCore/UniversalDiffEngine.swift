import Foundation

public struct UniversalDiffEngine {
    public let options: DiffOptions

    public init(options: DiffOptions = .init()) {
        self.options = options
    }

    public func compare(_ left: ParsedContent, _ right: ParsedContent) throws -> DiffNode {
        if left.kind == .structured,
           right.kind == .structured,
           let leftValue = left.structuredValue,
           let rightValue = right.structuredValue {
            return try SemanticDiffEngine(options: options).compare(leftValue, rightValue)
        }

        let leftBlocks = blocks(for: left)
        let rightBlocks = blocks(for: right)
        return compareBlocks(leftBlocks, rightBlocks, leftName: left.fileName, rightName: right.fileName)
    }

    private func blocks(for content: ParsedContent) -> [ContentBlock] {
        if !content.blocks.isEmpty { return content.blocks }
        return TextBlockParser().textBlocks(from: content.formattedText)
    }

    private func compareBlocks(
        _ left: [ContentBlock],
        _ right: [ContentBlock],
        leftName: String,
        rightName: String
    ) -> DiffNode {
        let edits: [BlockEdit]
        if left.count * right.count <= 4_000_000 {
            edits = lcsEdits(left, right)
        } else {
            edits = positionalEdits(left, right)
        }
        let children = nodes(from: edits)
        let status: DiffStatus = children.allSatisfy { $0.status == .unchanged } ? .unchanged : .modified
        return DiffNode(
            path: "",
            name: "\(leftName) ↔ \(rightName)",
            status: status,
            leftValue: .string("\(left.count) blocks"),
            rightValue: .string("\(right.count) blocks"),
            children: children
        )
    }

    private func lcsEdits(_ left: [ContentBlock], _ right: [ContentBlock]) -> [BlockEdit] {
        let leftKeys = left.map(normalizedKey)
        let rightKeys = right.map(normalizedKey)
        var lengths = Array(
            repeating: Array(repeating: 0, count: right.count + 1),
            count: left.count + 1
        )

        if !left.isEmpty, !right.isEmpty {
            for i in stride(from: left.count - 1, through: 0, by: -1) {
                for j in stride(from: right.count - 1, through: 0, by: -1) {
                    if leftKeys[i] == rightKeys[j] {
                        lengths[i][j] = lengths[i + 1][j + 1] + 1
                    } else {
                        lengths[i][j] = max(lengths[i + 1][j], lengths[i][j + 1])
                    }
                }
            }
        }

        var edits: [BlockEdit] = []
        var i = 0
        var j = 0
        while i < left.count, j < right.count {
            if leftKeys[i] == rightKeys[j] {
                edits.append(.same(left[i], right[j]))
                i += 1
                j += 1
            } else if lengths[i + 1][j] >= lengths[i][j + 1] {
                edits.append(.removed(left[i]))
                i += 1
            } else {
                edits.append(.added(right[j]))
                j += 1
            }
        }
        while i < left.count { edits.append(.removed(left[i])); i += 1 }
        while j < right.count { edits.append(.added(right[j])); j += 1 }
        return edits
    }

    private func positionalEdits(_ left: [ContentBlock], _ right: [ContentBlock]) -> [BlockEdit] {
        (0..<max(left.count, right.count)).map { index in
            switch (left.indices.contains(index), right.indices.contains(index)) {
            case (true, true):
                return normalizedKey(left[index]) == normalizedKey(right[index])
                    ? .same(left[index], right[index])
                    : .modified(left[index], right[index])
            case (true, false): return .removed(left[index])
            case (false, true): return .added(right[index])
            case (false, false): preconditionFailure("Index must exist on at least one side")
            }
        }
    }

    private func nodes(from edits: [BlockEdit]) -> [DiffNode] {
        var nodes: [DiffNode] = []
        var position = 0
        var index = 0

        while index < edits.count {
            if case let .same(left, right) = edits[index] {
                nodes.append(node(pathIndex: position, status: .unchanged, left: left, right: right))
                position += 1
                index += 1
                continue
            }
            if case let .modified(left, right) = edits[index] {
                nodes.append(node(pathIndex: position, status: .modified, left: left, right: right))
                position += 1
                index += 1
                continue
            }

            var removed: [ContentBlock] = []
            var added: [ContentBlock] = []
            while index < edits.count {
                switch edits[index] {
                case let .removed(block): removed.append(block)
                case let .added(block): added.append(block)
                case .same, .modified: break
                }
                if case .same = edits[index] { break }
                if case .modified = edits[index] { break }
                index += 1
            }

            let pairs = min(removed.count, added.count)
            for pair in 0..<pairs {
                nodes.append(node(
                    pathIndex: position,
                    status: .modified,
                    left: removed[pair],
                    right: added[pair]
                ))
                position += 1
            }
            for block in removed.dropFirst(pairs) {
                nodes.append(node(pathIndex: position, status: .removed, left: block, right: nil))
                position += 1
            }
            for block in added.dropFirst(pairs) {
                nodes.append(node(pathIndex: position, status: .added, left: nil, right: block))
                position += 1
            }
        }
        return nodes
    }

    private func node(
        pathIndex: Int,
        status: DiffStatus,
        left: ContentBlock?,
        right: ContentBlock?
    ) -> DiffNode {
        let reference = right ?? left
        return DiffNode(
            path: "/blocks/\(pathIndex)",
            name: reference?.label ?? "Block \(pathIndex + 1)",
            status: status,
            leftValue: left.map { .string($0.text) },
            rightValue: right.map { .string($0.text) }
        )
    }

    private func normalizedKey(_ block: ContentBlock) -> String {
        var value = block.canonicalText
        if options.strings.normalizeLineEndings {
            value = value.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }
        if options.strings.trimWhitespace {
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if options.strings.ignoreCase {
            value = value.lowercased(with: Locale(identifier: "en_US_POSIX"))
        }
        return value
    }
}

private enum BlockEdit {
    case same(ContentBlock, ContentBlock)
    case modified(ContentBlock, ContentBlock)
    case removed(ContentBlock)
    case added(ContentBlock)
}
